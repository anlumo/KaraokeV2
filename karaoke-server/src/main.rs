use std::{
    collections::HashMap,
    ffi::OsStr,
    net::{IpAddr, Ipv6Addr, SocketAddr},
    os::unix::ffi::OsStrExt,
    path::PathBuf,
    sync::Arc,
};

use axum::{
    body::Body,
    extract::{Path, Query, State},
    http::{
        header::{CONTENT_LENGTH, CONTENT_TYPE},
        HeaderMap, StatusCode,
    },
    routing::{get, post},
    Json, Router,
};
use clap::Parser;
use env_logger::Env;
use now_playing::Playlist;
use rand::Rng;
use rusqlite::{Connection, OpenFlags};
use serde::Deserialize;
use tokio::{fs::File, io::AsyncSeekExt};
use tower_http::trace::{DefaultMakeSpan, TraceLayer};

use crate::{
    songs::{SearchIndex, Song},
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
}

struct AppState {
    song_covers: HashMap<i64, PathBuf>,
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
                    cover_path: cover_path.map(|path| PathBuf::from(OsStr::from_bytes(&path))),
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
    let playlist = Playlist::load(args.playlist, song_db.iter().map(|song| song.row_id)).await?;
    let song_covers = song_db
        .into_iter()
        .filter_map(|song| song.cover_path.map(|cover_path| (song.row_id, cover_path)))
        .collect();

    let state = Arc::new(AppState {
        song_covers,
        song_count,
        index,
        playlist,
        password: args.password,
    });

    let app = Router::new()
        .route("/", get(root))
        .route("/song", get(get_song))
        .route("/cover/:id", get(get_cover))
        .route("/search", post(search))
        .route("/all_songs", get(get_all_songs))
        .route("/random_songs", get(get_random_songs))
        .route("/song_count", get(get_song_count))
        .route("/ws", get(ws_handler))
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

async fn root() -> &'static str {
    "Hello World"
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

async fn get_cover(
    State(state): State<Arc<AppState>>,
    Path(song_id): Path<i64>,
) -> Result<(HeaderMap, Body), StatusCode> {
    let Some(cover_path) = state.song_covers.get(&song_id) else {
        return Err(StatusCode::NOT_FOUND);
    };

    let guess = mime_guess::from_path(cover_path).first_or(mime_guess::mime::IMAGE_JPEG);
    let mut file = File::open(cover_path).await.map_err(|err| {
        log::error!("get_cover for path {cover_path:?}: {err:?}");
        StatusCode::NOT_FOUND
    })?;
    let file_length = file.seek(std::io::SeekFrom::End(0)).await.map_err(|err| {
        log::error!("get_cover for path {cover_path:?}: {err:?}");
        StatusCode::INTERNAL_SERVER_ERROR
    })?;
    file.seek(std::io::SeekFrom::Start(0))
        .await
        .map_err(|err| {
            log::error!("get_cover for path {cover_path:?}: {err:?}");
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    let body = Body::from_stream(tokio_util::io::ReaderStream::new(file));

    let mut headers = HeaderMap::new();
    headers.insert(CONTENT_TYPE, guess.as_ref().parse().unwrap());
    headers.insert(CONTENT_LENGTH, file_length.to_string().parse().unwrap());

    Ok((headers, body))
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
