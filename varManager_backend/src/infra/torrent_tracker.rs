use dashmap::DashMap;
use std::sync::Arc;

#[derive(Clone)]
pub struct TorrentTracker {
    active: Arc<DashMap<String, TorrentDownloadInfo>>,
}

#[derive(Clone, Debug)]
pub struct TorrentDownloadInfo {
    pub torrent_name: String,
    pub var_names: Vec<String>,
    pub started_at: std::time::Instant,
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

    pub fn register(&self, torrent_name: String, var_names: Vec<String>) -> bool {
        if self.is_active(&torrent_name) {
            return false; // Already downloading
        }
        self.active.insert(
            torrent_name.clone(),
            TorrentDownloadInfo {
                torrent_name,
                var_names,
                started_at: std::time::Instant::now(),
            },
        );
        true
    }

    pub fn unregister(&self, torrent_name: &str) {
        self.active.remove(torrent_name);
    }

    pub fn get_active(&self) -> Vec<TorrentDownloadInfo> {
        self.active
            .iter()
            .map(|entry| entry.value().clone())
            .collect()
    }
}
