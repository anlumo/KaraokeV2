use std::{
    collections::HashSet,
    net::{IpAddr, Ipv6Addr, SocketAddr},
    path::PathBuf,
    sync::Arc,
};

use axum::{
    body::Body,
    extract::{Query, State},
    http::StatusCode,
    routing::{get, post},
    Json, Router,
};
use clap::Parser;
use csv::{StringRecord, Writer};
use now_playing::Playlist;
use rusqlite::{Connection, OpenFlags};
use serde::Deserialize;
use time::{format_description::well_known::Rfc3339, OffsetDateTime};
use tokio::{
    fs::{File, OpenOptions},
    io::AsyncWriteExt,
    sync::Mutex,
};
use tower_http::{
    services::ServeDir,
    trace::{DefaultMakeSpan, TraceLayer},
};

use crate::{
    config::parse_config,
    songs::{urlencode_path, SearchIndex, Song},
    websocket::ws_handler,
};

mod config;
mod now_playing;
mod songs;
mod websocket;

#[derive(Parser, Debug)]
struct Args {
    /// The address and port to listen on (defaults to [::1]:8080).
    #[clap(short, long)]
    address: Option<SocketAddr>,
    /// The path to the config file in toml format.
    #[clap(short, long)]
    config: PathBuf,
}

pub struct AppState {
    song_count: usize,
    index: SearchIndex,
    playlist: Playlist,
    password: String,
    languages: HashSet<String>,
    suggest_log: Mutex<File>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    let config = parse_config(args.config).await?;
    log4rs::init_raw_config(config.logging)?;

    let address = args.address.unwrap_or_else(|| {
        config.server.listen.unwrap_or(SocketAddr::new(
            IpAddr::V6(Ipv6Addr::new(0, 0, 0, 0, 0, 0, 0, 1)),
            8080,
        ))
    });

    log::info!("Loading song database...");
    let song_db: Vec<Song>;
    let languages: HashSet<String>;
    {
        let mut conn =
            Connection::open_with_flags(config.paths.database, OpenFlags::SQLITE_OPEN_READ_ONLY)?;
        let tx = conn.transaction()?;

        let mut stmt = tx.prepare(
            "SELECT rowid, title, artist, language, year, duration, lyrics, player_count, cover_path, audio_path FROM song ORDER BY title COLLATE NOCASE",
        )?;
        let mut lang_stmt =
            tx.prepare("SELECT DISTINCT language FROM song WHERE LANGUAGE IS NOT NULL")?;
        song_db = stmt
            .query_map((), |row| {
                let row_id = row.get("rowid")?;
                let cover_path = row.get::<_, Option<Vec<u8>>>("cover_path")?;
                let audio_path = row.get::<_, Option<Vec<u8>>>("audio_path")?;
                Ok(Song {
                    row_id,
                    title: row.get("title")?,
                    artist: row.get("artist")?,
                    language: row.get("language")?,
                    year: row.get("year")?,
                    duration: row.get("duration")?,
                    lyrics: row.get("lyrics")?,
                    duet: row.get::<_, i32>("player_count")? > 1,
                    cover_path: cover_path.map(urlencode_path),
                    audio_path: urlencode_path(audio_path.unwrap()),
                })
            })?
            .filter_map(|result| match result {
                Ok(song) => Some(song),
                Err(err) => {
                    log::error!("Failed loading song: {err:?}");
                    None
                }
            })
            .collect();
        languages = lang_stmt
            .query_map((), |row| row.get::<_, String>(0))?
            .collect::<Result<_, _>>()?;
    };

    let index = SearchIndex::new(song_db.iter())?;
    let song_count = song_db.len();
    let playlist = Playlist::load(
        config.paths.playlist,
        song_db.iter().map(|song| song.row_id),
        config.paths.song_log.as_deref(),
        &config.paths.bug_log,
    )
    .await?;

    let state = Arc::new(AppState {
        song_count,
        index,
        playlist,
        password: config.server.password,
        languages,
        suggest_log: Mutex::new(
            OpenOptions::new()
                .append(true)
                .create(true)
                .open(config.paths.suggestion_log)
                .await?,
        ),
    });

    let app = Router::new()
        .route("/api/song", get(get_song))
        .route("/api/search", post(search))
        .route("/api/all_songs", get(get_all_songs))
        .route("/api/random_songs", get(get_random_songs))
        .route("/api/song_count", get(get_song_count))
        .route("/api/languages", get(get_languages))
        .route("/api/suggest", post(suggest))
        .route("/ws", get(ws_handler))
        .nest_service("/media", ServeDir::new(config.paths.media))
        .nest_service("/", ServeDir::new(config.paths.web_app))
        .with_state(state)
        .layer(
            TraceLayer::new_for_http()
                .make_span_with(DefaultMakeSpan::default().include_headers(true)),
        )
        .into_make_service_with_connect_info::<SocketAddr>();
    log::info!("Listening on {address:?}");
    let listener = tokio::net::TcpListener::bind(address).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

#[derive(Debug, Deserialize)]
struct SongIds {
    id: String,
}

async fn get_song(
    State(state): State<Arc<AppState>>,
    Query(SongIds { id }): Query<SongIds>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let ids = id
        .split(',')
        .map(|id| id.parse::<i64>().map(|id| format!("rowid:{id}")))
        .collect::<Result<Vec<_>, _>>()
        .map_err(|err| {
            log::error!("Received bad request for song ids {id:?}: {err:?}");
            StatusCode::BAD_REQUEST
        })?;

    let result = state.index.search(&ids.join(" OR ")).map_err(|err| {
        log::error!("Search for songs {ids:?} failed: {err:?}");
        StatusCode::INTERNAL_SERVER_ERROR
    })?;
    if let Some(song) = result.into_iter().next() {
        Ok(Json(song))
    } else {
        Err(StatusCode::NOT_FOUND)
    }
}

async fn search(
    State(state): State<Arc<AppState>>,
    search_str: String,
) -> Result<Json<Vec<serde_json::Value>>, (StatusCode, Body)> {
    log::debug!("Searching for {search_str:?}");
    let result = state.index.search(&search_str).map_err(|err| {
        log::error!("Search for {search_str:?} failed: {err:?}");
        (StatusCode::BAD_REQUEST, Body::from(format!("{err}")))
    })?;
    Ok(Json(result))
}

#[derive(Debug, Deserialize)]
pub struct Pagination {
    offset: u32,
    per_page: u32,
    query: Option<String>,
}

async fn get_all_songs(
    State(state): State<Arc<AppState>>,
    Query(pagination): Query<Pagination>,
) -> Result<Json<Vec<serde_json::Value>>, StatusCode> {
    let result = state.index.paginated(pagination).map_err(|err| {
        log::error!("Fetching paginated failed: {err:?}");
        StatusCode::INTERNAL_SERVER_ERROR
    })?;
    Ok(Json(result))
}

async fn get_song_count(State(state): State<Arc<AppState>>) -> String {
    state.song_count.to_string()
}

#[derive(Debug, Deserialize)]
struct SongCount {
    count: u32,
    query: Option<String>,
}

async fn get_random_songs(
    State(state): State<Arc<AppState>>,
    Query(SongCount { count, query }): Query<SongCount>,
) -> Result<Json<Vec<serde_json::Value>>, StatusCode> {
    let result = state
        .index
        .random_picks(count as _, query.as_deref())
        .map_err(|err| {
            log::error!("Fetching all failed: {err:?}");
            StatusCode::INTERNAL_SERVER_ERROR
        })?;
    Ok(Json(result))
}

async fn get_languages(State(state): State<Arc<AppState>>) -> Json<Vec<String>> {
    let mut languages: Vec<_> = state.languages.iter().cloned().collect();
    languages.sort();
    Json(languages)
}

#[derive(Debug, Deserialize)]
struct Suggest {
    name: String,
    artist: String,
    title: String,
}

async fn suggest(
    State(state): State<Arc<AppState>>,
    Json(Suggest {
        name,
        artist,
        title,
    }): Json<Suggest>,
) {
    let mut suggest_log = state.suggest_log.lock().await;
    let timestamp = OffsetDateTime::now_utc().format(&Rfc3339).unwrap();
    let record = StringRecord::from(vec![&timestamp, &name, &artist, &title]);
    let mut writer = Writer::from_writer(Vec::new());
    writer.write_record(&record).unwrap();

    if let Err(err) = suggest_log.write_all(&writer.into_inner().unwrap()).await {
        log::error!("Failed writing song log: {err:?}");
    }
}
