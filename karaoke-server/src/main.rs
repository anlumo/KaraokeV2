use std::{
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
use env_logger::Env;
use now_playing::Playlist;
use rand::Rng;
use rusqlite::{Connection, OpenFlags};
use serde::Deserialize;
use tower_http::{
    services::ServeDir,
    trace::{DefaultMakeSpan, TraceLayer},
};

use crate::{
    songs::{urlencode_path, SearchIndex, Song},
    websocket::ws_handler,
};

mod now_playing;
mod songs;
mod websocket;

#[derive(Parser, Debug)]
struct Args {
    /// The path to the sqlite database with the song information.
    #[clap(long)]
    db: PathBuf,
    /// The path to the persisted playlist file. Will be created if it doesn't exist.
    #[clap(long)]
    playlist: PathBuf,
    /// The admin password for managing the playlist.
    #[clap(long)]
    password: String,
    /// The address and port to listen on (defaults to [::1]:8080).
    #[clap(short, long)]
    address: Option<SocketAddr>,
    /// Verbose logging to stderr (read https://crates.io/crates/env_logger for more detailed configuration).
    #[clap(short, long)]
    verbose: bool,
    /// Path to the directory structure for the covers.
    #[clap(short, long)]
    cover_path: PathBuf,
    /// Path to the web app (directory containing index.html).
    #[clap(short, long)]
    web_app: PathBuf,
    /// Path to the file that should contain the history of what was played.
    #[clap(short, long)]
    song_log: Option<PathBuf>,
}

struct AppState {
    song_count: usize,
    index: SearchIndex,
    playlist: Playlist,
    password: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();

    if args.verbose {
        env_logger::Builder::from_env(Env::default().default_filter_or("debug")).init();
    } else {
        env_logger::init();
    }

    let address = args.address.unwrap_or(SocketAddr::new(
        IpAddr::V6(Ipv6Addr::new(0, 0, 0, 0, 0, 0, 0, 1)),
        8080,
    ));

    log::info!("Loading song database...");
    let song_db: Vec<Song>;
    {
        let mut conn = Connection::open_with_flags(args.db, OpenFlags::SQLITE_OPEN_READ_ONLY)?;
        let tx = conn.transaction()?;

        let mut stmt = tx.prepare(
            "SELECT rowid, title, artist, language, year, duration, lyrics, cover_path FROM song ORDER BY title COLLATE NOCASE",
        )?;
        song_db = stmt
            .query_map((), |row| {
                let row_id = row.get("rowid")?;
                let cover_path = row.get::<_, Option<Vec<u8>>>("cover_path")?;
                Ok(Song {
                    row_id,
                    title: row.get("title")?,
                    artist: row.get("artist")?,
                    language: row.get("language")?,
                    year: row.get("year")?,
                    duration: row.get("duration")?,
                    lyrics: row.get("lyrics")?,
                    cover_path: cover_path.map(urlencode_path),
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
    }

    let index = SearchIndex::new(song_db.iter())?;
    let song_count = song_db.len();
    let playlist = Playlist::load(
        args.playlist,
        song_db.iter().map(|song| song.row_id),
        args.song_log.as_deref(),
    )
    .await?;

    let state = Arc::new(AppState {
        song_count,
        index,
        playlist,
        password: args.password,
    });

    let app = Router::new()
        .route("/api/song", get(get_song))
        .route("/api/search", post(search))
        .route("/api/all_songs", get(get_all_songs))
        .route("/api/random_songs", get(get_random_songs))
        .route("/api/song_count", get(get_song_count))
        .route("/ws", get(ws_handler))
        .nest_service("/cover", ServeDir::new(args.cover_path))
        .nest_service("/", ServeDir::new(args.web_app))
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
        (StatusCode::BAD_REQUEST, Body::from(format!("{err:?}")))
    })?;
    Ok(Json(result))
}

#[derive(Debug, Deserialize)]
struct Pagination {
    offset: u32,
    per_page: u32,
}

async fn get_all_songs(
    State(state): State<Arc<AppState>>,
    Query(pagination): Query<Pagination>,
) -> Result<Json<Vec<serde_json::Value>>, StatusCode> {
    let result = state.index.all(pagination).map_err(|err| {
        log::error!("Fetching all failed: {err:?}");
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
}

async fn get_random_songs(
    State(state): State<Arc<AppState>>,
    Query(SongCount { count }): Query<SongCount>,
) -> Result<Json<Vec<serde_json::Value>>, StatusCode> {
    let total = state.song_count as u32;
    let mut rng = rand::thread_rng();

    let result = state
        .index
        .single_from_offsets((0..count).map(|_| rng.gen_range(0..total)))
        .map_err(|err| {
            log::error!("Fetching all failed: {err:?}");
            StatusCode::INTERNAL_SERVER_ERROR
        })?;
    Ok(Json(result))
}
