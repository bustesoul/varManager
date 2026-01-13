use dashmap::DashMap;
use std::sync::Arc;

#[derive(Clone)]
pub struct TorrentTracker {
    active: Arc<DashMap<String, ()>>,
}

impl TorrentTracker {
    pub fn new() -> Self {
        Self {
            active: Arc::new(DashMap::new()),
        }
    }

    pub fn is_active(&self, torrent_name: &str) -> bool {
        self.active.contains_key(torrent_name)
    }

    pub fn register(&self, torrent_name: String, _var_names: Vec<String>) -> bool {
        if self.is_active(&torrent_name) {
            return false; // Already downloading
        }
        self.active.insert(torrent_name, ());
        true
    }

    pub fn unregister(&self, torrent_name: &str) {
        self.active.remove(torrent_name);
    }
}
