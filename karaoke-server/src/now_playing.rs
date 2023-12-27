use std::{
    collections::{HashMap, HashSet, VecDeque},
    path::{Path, PathBuf},
};

use csv::{StringRecord, Writer};
use serde::{Deserialize, Serialize};
use tantivy::time::OffsetDateTime;
use time::{format_description::well_known::Rfc3339, Duration};
use tokio::{
    fs::{File, OpenOptions},
    io::{AsyncReadExt, AsyncWriteExt},
    sync::{mpsc::UnboundedSender, Mutex, RwLock},
};
use uuid::Uuid;

use crate::songs::SearchIndex;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaylistEntry {
    id: Uuid,
    song: i64,
    singer: String,
    #[serde(with = "time::serde::rfc3339")]
    predicted_end: OffsetDateTime,
}

#[derive(Debug, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
struct InnerPlaylist {
    now_playing: Option<PlaylistEntry>,
    list: VecDeque<PlaylistEntry>,
    #[serde(skip, default)]
    listeners: HashMap<Uuid, UnboundedSender<String>>,
    intermission_duration: Duration,
    intermission_count: usize,
}

#[derive(Debug)]
pub struct Playlist {
    valid_songs: HashSet<i64>,
    song_queue: RwLock<InnerPlaylist>,
    persist_path: PathBuf,
    song_log: Option<Mutex<File>>,
}

impl Playlist {
    pub async fn load(
        path: impl AsRef<Path>,
        valid_songs: impl IntoIterator<Item = i64>,
        song_log: Option<impl AsRef<Path>>,
    ) -> anyhow::Result<Self> {
        let song_log = if let Some(song_log) = song_log {
            Some(Mutex::new(
                OpenOptions::new()
                    .append(true)
                    .create(true)
                    .open(song_log)
                    .await?,
            ))
        } else {
            None
        };

        match File::open(&path).await {
            Ok(mut f) => {
                let mut data = Vec::new();
                f.read_to_end(&mut data).await?;
                let valid_songs: HashSet<_> = valid_songs.into_iter().collect();
                let mut song_queue: InnerPlaylist = serde_json::from_slice(&data)?;

                // Don't keep songs in the list that no longer exist.
                song_queue
                    .list
                    .retain(|entry| valid_songs.contains(&entry.song));
                if let Some(now_playing) = &song_queue.now_playing {
                    if !valid_songs.contains(&now_playing.song) {
                        song_queue.now_playing = None;
                    }
                }

                Ok(Self {
                    valid_songs,
                    song_queue: RwLock::new(song_queue),
                    persist_path: path.as_ref().to_owned(),
                    song_log,
                })
            }
            Err(err) if err.kind() == std::io::ErrorKind::NotFound => Ok(Self {
                valid_songs: valid_songs.into_iter().collect(),
                song_queue: Default::default(),
                persist_path: path.as_ref().to_owned(),
                song_log,
            }),
            Err(err) => Err(err.into()),
        }
    }

    pub async fn subscribe(&self, listener: UnboundedSender<String>) -> anyhow::Result<Uuid> {
        let mut queue = self.song_queue.write().await;
        listener.send(serde_json::to_string(&*queue).unwrap())?;
        let id = Uuid::new_v4();
        queue.listeners.insert(id, listener);
        Ok(id)
    }

    pub async fn unsubscribe(&self, id: Uuid) {
        let mut queue = self.song_queue.write().await;
        queue.listeners.remove(&id);
    }

    pub async fn add(
        &self,
        song: i64,
        singer: String,
        index: &SearchIndex,
    ) -> anyhow::Result<Option<Uuid>> {
        if !self.valid_songs.contains(&song) {
            return Ok(None);
        }
        let songs = index.search_song(&format!("rowid:{song}"), 1)?;
        if songs.is_empty() {
            log::error!("Can't find song that we should have!");
            Err(anyhow::anyhow!("Can't find song"))
        } else {
            let mut queue = self.song_queue.write().await;
            let predicted_end = if queue.list.is_empty() {
                OffsetDateTime::now_utc()
            } else {
                queue.list[queue.list.len() - 1].predicted_end
                    + Duration::seconds_f64(songs[0].duration)
            };
            let id = Uuid::new_v4();
            queue.list.push_back(PlaylistEntry {
                id,
                singer,
                song,
                predicted_end,
            });
            Self::did_change(&mut queue, &self.persist_path, index).await?;
            Ok(Some(id))
        }
    }

    pub async fn play(&self, id: Uuid, index: &SearchIndex) -> anyhow::Result<bool> {
        let mut queue = self.song_queue.write().await;
        if let Some(entry) = queue
            .list
            .iter()
            .enumerate()
            .find_map(|(idx, entry)| (entry.id == id).then_some(idx))
        {
            let new_playing = queue.list.remove(entry);
            let old_playing = if let Some(new_playing) = new_playing {
                queue.now_playing.replace(new_playing)
            } else {
                queue.now_playing.take()
            };

            // Update intermission record
            if let Some(old_playing) = old_playing {
                let duration = OffsetDateTime::now_utc() - old_playing.predicted_end;
                // Ignore breaks that are 5 minutes or longer, since those aren't representative.
                // Note that this might include breaks between whole parties, so it could be months as well.
                if duration < Duration::minutes(5) {
                    queue.intermission_count += 1;
                    queue.intermission_duration += duration;
                }
            }

            // Update playlist and notify listeners
            Self::did_change(&mut queue, &self.persist_path, index).await?;

            // Write song log
            if let (Some(now_playing), Some(song_log)) = (&queue.now_playing, &self.song_log) {
                let timestamp = OffsetDateTime::now_utc().format(&Rfc3339).unwrap();
                match index.search_song(&format!("rowid:{}", now_playing.song), 1) {
                    Err(err) => {
                        log::error!("Fetching song for song log failed: {err:?}");
                    }
                    Ok(songs) => {
                        if songs.is_empty() {
                            log::error!("Can't write song log: song not found!");
                        } else {
                            let mut song_log = song_log.lock().await;
                            let record = StringRecord::from(vec![
                                &timestamp,
                                &songs[0].artist,
                                &songs[0].title,
                            ]);
                            let mut writer = Writer::from_writer(Vec::new());
                            writer.write_record(&record).unwrap();

                            if let Err(err) =
                                song_log.write_all(&writer.into_inner().unwrap()).await
                            {
                                log::error!("Failed writing song log: {err:?}");
                            }
                        }
                    }
                }
            }
            Ok(true)
        } else {
            Ok(false)
        }
    }

    pub async fn remove(&self, id: Uuid, index: &SearchIndex) -> anyhow::Result<bool> {
        let mut queue = self.song_queue.write().await;
        if let Some(entry) = queue
            .list
            .iter()
            .enumerate()
            .find_map(|(idx, entry)| (entry.id == id).then_some(idx))
        {
            queue.list.remove(entry);
            Self::did_change(&mut queue, &self.persist_path, index).await?;
            Ok(true)
        } else {
            Ok(false)
        }
    }

    pub async fn swap(&self, id1: Uuid, id2: Uuid, index: &SearchIndex) -> anyhow::Result<bool> {
        if id1 == id2 {
            return Ok(false);
        }
        let mut queue = self.song_queue.write().await;
        if let Some(entry1) = queue
            .list
            .iter()
            .enumerate()
            .find_map(|(idx, entry)| (entry.id == id1).then_some(idx))
        {
            if let Some(entry2) = queue
                .list
                .iter()
                .enumerate()
                .find_map(|(idx, entry)| (entry.id == id2).then_some(idx))
            {
                queue.list.swap(entry1, entry2);
                Self::did_change(&mut queue, &self.persist_path, index).await?;
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub async fn move_after(
        &self,
        id: Uuid,
        after: Uuid,
        index: &SearchIndex,
    ) -> anyhow::Result<bool> {
        if id == after {
            return Ok(false);
        }
        let mut queue = self.song_queue.write().await;
        if let Some(entry) = queue
            .list
            .iter()
            .enumerate()
            .find_map(|(idx, entry)| (entry.id == id).then_some(idx))
        {
            if let Some(after_entry) = queue
                .list
                .iter()
                .enumerate()
                .find_map(|(idx, entry)| (entry.id == after).then_some(idx))
            {
                if entry < after_entry {
                    let entry = queue.list.remove(entry).unwrap();
                    queue.list.insert(after_entry, entry);
                } else {
                    let entry = queue.list.remove(entry).unwrap();
                    queue.list.insert(after_entry + 1, entry);
                }
                Self::did_change(&mut queue, &self.persist_path, index).await?;
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub async fn move_top(&self, id: Uuid, index: &SearchIndex) -> anyhow::Result<bool> {
        let mut queue = self.song_queue.write().await;
        if let Some(entry) = queue
            .list
            .iter()
            .enumerate()
            .find_map(|(idx, entry)| (entry.id == id).then_some(idx))
        {
            let entry = queue.list.remove(entry).unwrap();
            queue.list.push_front(entry);
            Self::did_change(&mut queue, &self.persist_path, index).await?;
            Ok(true)
        } else {
            Ok(false)
        }
    }

    async fn did_change(
        inner: &mut InnerPlaylist,
        path: &PathBuf,
        index: &SearchIndex,
    ) -> anyhow::Result<()> {
        // update play time estimates
        let songs = index.search_song(
            &inner
                .list
                .iter()
                .map(|entry| format!("rowid:{}", entry.song))
                .collect::<Vec<_>>()
                .join(" OR "),
            inner.list.len(),
        )?;
        let mut timestamp = None;
        let average_intermission = inner
            .intermission_duration
            .checked_div(inner.intermission_count as _)
            .unwrap_or_default();
        for playlist_item in &mut inner.list {
            if let Some(song) = songs.iter().find(|&song| song.row_id == playlist_item.song) {
                if let Some(last_timestamp) = timestamp {
                    timestamp = Some(
                        last_timestamp
                            + average_intermission
                            + Duration::seconds_f64(song.duration),
                    );
                } else {
                    timestamp = Some(playlist_item.predicted_end);
                }
            }
        }

        let json = serde_json::to_string(inner)?;
        for listener in inner.listeners.values() {
            listener.send(json.clone())?;
        }
        let mut file = File::create(path).await?;
        file.write_all(json.as_bytes()).await?;

        Ok(())
    }
}
