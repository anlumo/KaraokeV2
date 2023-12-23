use std::{
    ffi::OsStr,
    net::{IpAddr, Ipv6Addr, SocketAddr},
    os::unix::ffi::OsStrExt,
    path::PathBuf,
    sync::Arc,
};

use axum::{
    body::Body,
    extract::{Path, State},
    http::{
        header::{CONTENT_LENGTH, CONTENT_TYPE},
        HeaderMap, StatusCode,
    },
    routing::get,
    Router,
};
use clap::Parser;
use env_logger::Env;
use r2d2::Pool;
use r2d2_sqlite::{rusqlite::OpenFlags, SqliteConnectionManager};
use tokio::{fs::File, io::AsyncSeekExt};
use tower_http::trace::{DefaultMakeSpan, TraceLayer};

use crate::websocket::ws_handler;

mod websocket;

#[derive(Parser, Debug)]
struct Args {
    /// The path to the sqlite database with the song information.
    #[clap(short, long)]
    db: PathBuf,
    /// The address and port to listen on (defaults to [::1]:8080).
    #[clap(short, long)]
    address: Option<SocketAddr>,
    /// Verbose logging to stderr (read https://crates.io/crates/env_logger for more detailed configuration).
    #[clap(short, long)]
    verbose: bool,
}

struct AppState {
    db_pool: Pool<SqliteConnectionManager>,
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

    let db_manager =
        SqliteConnectionManager::file(args.db).with_flags(OpenFlags::SQLITE_OPEN_READ_ONLY);
    let db_pool = Pool::new(db_manager)?;

    let state = Arc::new(AppState { db_pool });

    let app = Router::new()
        .route("/", get(root))
        .route("/cover/:id", get(get_cover))
        .route("/ws", get(ws_handler))
        .with_state(state)
        .layer(
            TraceLayer::new_for_http()
                .make_span_with(DefaultMakeSpan::default().include_headers(true)),
        );
    log::info!("Listening on {address:?}");
    let listener = tokio::net::TcpListener::bind(address).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

async fn root() -> &'static str {
    "Hello World"
}

async fn get_cover(
    State(state): State<Arc<AppState>>,
    Path(song_id): Path<u32>,
) -> Result<(HeaderMap, Body), StatusCode> {
    let conn = state.db_pool.get().map_err(|err| {
        log::error!("get_cover: {err:?}");
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    let cover_path = conn
        .query_row(
            "SELECT cover_path FROM song WHERE rowid=?1",
            (song_id,),
            |f| f.get::<_, Vec<u8>>(0),
        )
        .map_err(|err| {
            log::error!("get_cover: {err:?}");
            StatusCode::INTERNAL_SERVER_ERROR
        })?;
    let cover_path = OsStr::from_bytes(&cover_path);

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
