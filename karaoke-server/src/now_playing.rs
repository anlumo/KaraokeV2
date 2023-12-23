use std::collections::VecDeque;

use tokio::sync::RwLock;
use uuid::Uuid;

#[derive(Debug, Clone)]
pub struct PlaylistEntry {
    id: Uuid,
    song: i64,
    singer: String,
}

#[derive(Debug, Default)]
pub struct Playlist {
    song_queue: RwLock<(Option<PlaylistEntry>, VecDeque<PlaylistEntry>)>,
}

impl Playlist {
    pub async fn add(&self, song: i64, singer: String) -> Uuid {
        let mut queue = self.song_queue.write().await;
        let id = Uuid::new_v4();
        queue.1.push_back(PlaylistEntry { id, singer, song });
        id
    }

    pub async fn get_list(&self) -> Vec<PlaylistEntry> {
        let queue = self.song_queue.read().await;
        queue.1.iter().cloned().collect()
    }

    pub async fn now_playing(&self) -> Option<PlaylistEntry> {
        let queue = self.song_queue.read().await;
        queue.0.clone()
    }

    pub async fn play(&self, id: Uuid) -> bool {
        let mut queue = self.song_queue.write().await;
        if let Some(entry) = queue
            .1
            .iter()
            .enumerate()
            .find_map(|(idx, entry)| (entry.id == id).then_some(idx))
        {
            queue.0 = queue.1.remove(entry);
            true
        } else {
            false
        }
    }

    pub async fn remove(&self, id: Uuid) -> bool {
        let mut queue = self.song_queue.write().await;
        if let Some(entry) = queue
            .1
            .iter()
            .enumerate()
            .find_map(|(idx, entry)| (entry.id == id).then_some(idx))
        {
            queue.1.remove(entry);
            true
        } else {
            false
        }
    }

    pub async fn swap(&self, id1: Uuid, id2: Uuid) -> bool {
        if id1 == id2 {
            return false;
        }
        let mut queue = self.song_queue.write().await;
        if let Some(entry1) = queue
            .1
            .iter()
            .enumerate()
            .find_map(|(idx, entry)| (entry.id == id1).then_some(idx))
        {
            if let Some(entry2) = queue
                .1
                .iter()
                .enumerate()
                .find_map(|(idx, entry)| (entry.id == id2).then_some(idx))
            {
                queue.1.swap(entry1, entry2);
                return true;
            }
        }
        false
    }

    pub async fn move_after(&self, id: Uuid, after: Uuid) -> bool {
        if id != after {
            return false;
        }
        let mut queue = self.song_queue.write().await;
        if let Some(entry) = queue
            .1
            .iter()
            .enumerate()
            .find_map(|(idx, entry)| (entry.id == id).then_some(idx))
        {
            if let Some(after_entry) = queue
                .1
                .iter()
                .enumerate()
                .find_map(|(idx, entry)| (entry.id == after).then_some(idx))
            {
                if entry < after_entry {
                    let entry = queue.1.remove(entry).unwrap();
                    queue.1.insert(after_entry + 1, entry);
                } else {
                    let entry = queue.1.remove(entry).unwrap();
                    queue.1.insert(after_entry, entry);
                }
                return true;
            }
        }
        false
    }

    pub async fn move_top(&self, id: Uuid) -> bool {
        let mut queue = self.song_queue.write().await;
        if let Some(entry) = queue
            .1
            .iter()
            .enumerate()
            .find_map(|(idx, entry)| (entry.id == id).then_some(idx))
        {
            let entry = queue.1.remove(entry).unwrap();
            queue.1.push_front(entry);
            true
        } else {
            false
        }
    }
}
