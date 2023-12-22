use std::{
    fs::read_dir,
    os::unix::ffi::OsStrExt,
    path::{Path, PathBuf},
};

use clap::Parser;
use rusqlite::{Connection, OpenFlags, Statement};
use ultrastar_txt::{loader, Source};

#[derive(Parser, Debug)]
struct Args {
    path: PathBuf,

    /// The path to the sqlite database to write the output to. Will be created if it doesn't exist.
    #[clap(short, long)]
    db: PathBuf,
}

fn parse_txt(path: impl AsRef<Path>, insert_stmt: &mut Statement<'_>) -> anyhow::Result<()> {
    let full_path = path.as_ref().canonicalize()?;
    let song = loader::parse_txt_song(&path).map_err(|err| anyhow::anyhow!("{err:?}"))?;

    let Source::Local(audio_path) = song.header.audio_path else {
        return Err(anyhow::anyhow!(
            "{:?} does not have a local audio track.",
            path.as_ref()
        ));
    };

    let context = ffmpeg_next::format::input(&audio_path)?;
    let Some(stream) = context.streams().best(ffmpeg_next::media::Type::Audio) else {
        return Err(anyhow::anyhow!(
            "{:?} does not contain an audio track.",
            path.as_ref()
        ));
    };

    insert_stmt.execute((
        full_path.as_os_str().as_bytes(),
        &song.header.title,
        &song.header.artist,
        song.header.language.as_deref(),
        song.header.year,
        stream.duration() as f64 * f64::from(stream.time_base()),
        song.lines
            .into_iter()
            .map(|line| {
                line.notes
                    .into_iter()
                    .filter_map(|note| match note {
                        ultrastar_txt::Note::Regular { text, .. } => Some(text),
                        ultrastar_txt::Note::Golden { text, .. } => Some(text),
                        ultrastar_txt::Note::Freestyle { text, .. } => Some(text),
                        ultrastar_txt::Note::PlayerChange { .. } => None,
                    })
                    .collect::<String>()
            })
            .collect::<Vec<_>>()
            .join("\n"),
    ))?;

    Ok(())
}

fn walk_dir(path: impl AsRef<Path>, insert_stmt: &mut Statement<'_>) -> anyhow::Result<()> {
    for path in read_dir(path)? {
        let path = path?;
        if path.file_type()?.is_dir() {
            // song directory
            walk_dir(path.path(), insert_stmt)?;
        } else if path.file_type()?.is_file() {
            let file_path = path.path();
            if let Some(b"txt") = file_path.extension().map(|ext| ext.as_bytes()) {
                if let Err(err) = parse_txt(&file_path, insert_stmt) {
                    eprintln!("{err}");
                }
            }
        }
    }

    Ok(())
}

fn main() -> anyhow::Result<()> {
    let args = Args::parse();

    ffmpeg_next::init()?;
    ffmpeg_next::log::set_level(ffmpeg_next::log::Level::Fatal);

    let mut conn = Connection::open_with_flags(
        args.db,
        OpenFlags::SQLITE_OPEN_CREATE | OpenFlags::SQLITE_OPEN_READ_WRITE,
    )
    .unwrap();
    conn.execute(
        r#"CREATE TABLE IF NOT EXISTS song (
        path BLOB UNIQUE NOT NULL,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        language TEXT,
        year INTEGER,
        duration REAL NOT NULL,
        lyrics TEXT
    )"#,
        (),
    )?;

    let tx = conn.transaction()?;
    {
        let mut insert_stmt = tx.prepare("INSERT OR REPLACE INTO song (path, title, artist, language, year, duration, lyrics) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)")?;
        walk_dir(args.path, &mut insert_stmt)?;
    }
    tx.commit()?;

    Ok(())
}
