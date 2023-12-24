#![allow(unused)]

use std::{
    collections::VecDeque,
    path::{Path, PathBuf},
};

use serde::{Deserialize, Serialize};
use tokio::{
    fs::File,
    io::{AsyncReadExt, AsyncWriteExt},
    sync::RwLock,
};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaylistEntry {
    id: Uuid,
    song: i64,
    singer: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
struct InnerPlaylist {
    now_playing: Option<PlaylistEntry>,
    list: VecDeque<PlaylistEntry>,
}

#[derive(Debug)]
pub struct Playlist {
    song_queue: RwLock<InnerPlaylist>,
    persist_path: PathBuf,
}

impl Playlist {
    pub async fn load(path: impl AsRef<Path>) -> anyhow::Result<Self> {
        match File::open(&path).await {
            Ok(mut f) => {
                let mut data = Vec::new();
                f.read_to_end(&mut data).await?;
                Ok(Self {
                    song_queue: RwLock::new(serde_json::from_slice(&data)?),
                    persist_path: path.as_ref().to_owned(),
                })
            }
            Err(err) if err.kind() == std::io::ErrorKind::NotFound => Ok(Self {
                song_queue: Default::default(),
                persist_path: path.as_ref().to_owned(),
            }),
            Err(err) => Err(err.into()),
        }
    }

    pub async fn add(&self, song: i64, singer: String) -> anyhow::Result<Uuid> {
        let mut queue = self.song_queue.write().await;
        let id = Uuid::new_v4();
        queue.list.push_back(PlaylistEntry { id, singer, song });
        Self::persist(&queue, &self.persist_path).await?;
        Ok(id)
    }

    pub async fn get_list(&self) -> Vec<PlaylistEntry> {
        let queue = self.song_queue.read().await;
        queue.list.iter().cloned().collect()
    }

    pub async fn now_playing(&self) -> Option<PlaylistEntry> {
        let queue = self.song_queue.read().await;
        queue.now_playing.clone()
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
            Self::persist(&queue, &self.persist_path).await?;
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
            Self::persist(&queue, &self.persist_path).await?;
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
                Self::persist(&queue, &self.persist_path).await?;
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
                Self::persist(&queue, &self.persist_path).await?;
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
            Self::persist(&queue, &self.persist_path).await?;
            Ok(true)
        } else {
            Ok(false)
        }
    }

    async fn persist(inner: &InnerPlaylist, path: &PathBuf) -> anyhow::Result<()> {
        let mut file = File::create(path).await?;
        file.write_all(&serde_json::to_vec(inner)?).await?;

        Ok(())
    }
}
