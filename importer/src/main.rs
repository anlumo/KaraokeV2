use std::{
    collections::HashSet,
    ffi::OsStr,
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

fn parse_txt(
    path: impl AsRef<Path>,
    insert_stmt: &mut Statement<'_>,
    inserted_set: &mut HashSet<PathBuf>,
) -> anyhow::Result<()> {
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

    let cover_path = song.header.cover_path.map(|cover_path| match cover_path {
        Source::Local(cover_path) => cover_path.as_os_str().as_bytes().to_owned(),
        _ => panic!("Song {} has remote cover", song.header.title),
    });

    let changes = insert_stmt.execute((
        full_path.as_os_str().as_bytes(),
        song.header.title.trim(),
        song.header.artist.trim(),
        song.header.language.map(|lang| lang.trim().to_owned()),
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
                    .trim()
                    .to_owned()
            })
            .collect::<Vec<_>>()
            .join("\n"),
        cover_path,
    ))?;

    if changes == 1 {
        inserted_set.insert(full_path);
    } else {
        eprintln!("{full_path:?}: Failed inserting into database");
    }

    Ok(())
}

fn walk_dir(
    path: impl AsRef<Path>,
    insert_stmt: &mut Statement<'_>,
    inserted_set: &mut HashSet<PathBuf>,
) -> anyhow::Result<()> {
    for path in read_dir(path)? {
        let path = path?;
        if path.file_type()?.is_dir() {
            // song directory
            walk_dir(path.path(), insert_stmt, inserted_set)?;
        } else if path.file_type()?.is_file() {
            let file_path = path.path();
            if let Some(b"txt") = file_path.extension().map(|ext| ext.as_bytes()) {
                if let Err(err) = parse_txt(&file_path, insert_stmt, inserted_set) {
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
        lyrics TEXT,
        cover_path BLOB
    )"#,
        (),
    )?;

    let tx = conn.transaction()?;
    {
        let existing_songs: HashSet<_> = tx
            .prepare("SELECT path FROM song")?
            .query_map((), |row| {
                row.get::<_, Vec<u8>>(0)
                    .map(|bytes| PathBuf::from(OsStr::from_bytes(&bytes)))
            })?
            .collect::<Result<_, _>>()?;
        let mut new_songs = HashSet::new();

        let mut insert_stmt = tx.prepare(
            r#"INSERT INTO song (path, title, artist, language, year, duration, lyrics, cover_path) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
            ON CONFLICT (path) DO UPDATE SET title=?2, artist=?3, language=?4, year=?5, duration=?6, lyrics=?7, cover_path=?8"#)?;
        walk_dir(args.path, &mut insert_stmt, &mut new_songs)?;

        let added = new_songs.difference(&existing_songs).count();
        let removed: Vec<_> = existing_songs.difference(&new_songs).collect();

        let removed_count = if removed.is_empty() {
            0
        } else {
            println!("Trying to remove {} songs...", removed.len());
            let mut remove_stmt = tx.prepare("DELETE FROM song WHERE path=?1")?;
            removed
                .into_iter()
                .map(|path| remove_stmt.execute((path.as_os_str().as_bytes(),)))
                .collect::<Result<Vec<_>, _>>()?
                .into_iter()
                .sum()
        };

        println!("{added} new songs, {removed_count} removed");
        println!(
            "Database now contains {} songs.",
            existing_songs.len() - removed_count + added
        );
    }
    tx.commit()?;

    Ok(())
}
