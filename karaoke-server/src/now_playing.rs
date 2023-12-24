use std::{
    collections::{HashMap, HashSet, VecDeque},
    path::{Path, PathBuf},
};

use serde::{Deserialize, Serialize};
use tokio::{
    fs::File,
    io::{AsyncReadExt, AsyncWriteExt},
    sync::{mpsc::UnboundedSender, RwLock},
};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaylistEntry {
    id: Uuid,
    song: i64,
    singer: String,
}

#[derive(Debug, Serialize, Deserialize, Default)]
struct InnerPlaylist {
    now_playing: Option<PlaylistEntry>,
    list: VecDeque<PlaylistEntry>,
    #[serde(skip, default)]
    listeners: HashMap<Uuid, UnboundedSender<String>>,
}

#[derive(Debug)]
pub struct Playlist {
    valid_songs: HashSet<i64>,
    song_queue: RwLock<InnerPlaylist>,
    persist_path: PathBuf,
}

impl Playlist {
    pub async fn load(
        path: impl AsRef<Path>,
        valid_songs: impl IntoIterator<Item = i64>,
    ) -> anyhow::Result<Self> {
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
                })
            }
            Err(err) if err.kind() == std::io::ErrorKind::NotFound => Ok(Self {
                valid_songs: valid_songs.into_iter().collect(),
                song_queue: Default::default(),
                persist_path: path.as_ref().to_owned(),
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

    pub async fn add(&self, song: i64, singer: String) -> anyhow::Result<Option<Uuid>> {
        if !self.valid_songs.contains(&song) {
            return Ok(None);
        }
        let mut queue = self.song_queue.write().await;
        let id = Uuid::new_v4();
        queue.list.push_back(PlaylistEntry { id, singer, song });
        Self::did_change(&mut queue, &self.persist_path).await?;
        Ok(Some(id))
    }

    pub async fn play(&self, id: Uuid) -> anyhow::Result<bool> {
        let mut queue = self.song_queue.write().await;
        if let Some(entry) = queue
            .list
            .iter()
            .enumerate()
            .find_map(|(idx, entry)| (entry.id == id).then_some(idx))
        {
            queue.now_playing = queue.list.remove(entry);
            Self::did_change(&mut queue, &self.persist_path).await?;
            Ok(true)
        } else {
            Ok(false)
        }
    }

    pub async fn remove(&self, id: Uuid) -> anyhow::Result<bool> {
        let mut queue = self.song_queue.write().await;
        if let Some(entry) = queue
            .list
            .iter()
            .enumerate()
            .find_map(|(idx, entry)| (entry.id == id).then_some(idx))
        {
            queue.list.remove(entry);
            Self::did_change(&mut queue, &self.persist_path).await?;
            Ok(true)
        } else {
            Ok(false)
        }
    }

    pub async fn swap(&self, id1: Uuid, id2: Uuid) -> anyhow::Result<bool> {
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
                Self::did_change(&mut queue, &self.persist_path).await?;
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub async fn move_after(&self, id: Uuid, after: Uuid) -> anyhow::Result<bool> {
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
                    queue.list.insert(after_entry + 1, entry);
                } else {
                    let entry = queue.list.remove(entry).unwrap();
                    queue.list.insert(after_entry, entry);
                }
                Self::did_change(&mut queue, &self.persist_path).await?;
                return Ok(true);
            }
        }
        Ok(false)
    }

    pub async fn move_top(&self, id: Uuid) -> anyhow::Result<bool> {
        let mut queue = self.song_queue.write().await;
        if let Some(entry) = queue
            .list
            .iter()
            .enumerate()
            .find_map(|(idx, entry)| (entry.id == id).then_some(idx))
        {
            let entry = queue.list.remove(entry).unwrap();
            queue.list.push_front(entry);
            Self::did_change(&mut queue, &self.persist_path).await?;
            Ok(true)
        } else {
            Ok(false)
        }
    }

    async fn did_change(inner: &mut InnerPlaylist, path: &PathBuf) -> anyhow::Result<()> {
        let json = serde_json::to_string(inner)?;
        for listener in inner.listeners.values() {
            listener.send(json.clone())?;
        }
        let mut file = File::create(path).await?;
        file.write_all(json.as_bytes()).await?;

        Ok(())
    }
}
