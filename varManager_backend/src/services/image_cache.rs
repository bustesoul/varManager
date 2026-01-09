use crate::app::{exe_dir, ImageCacheConfig};
use bytes::Bytes;
use dashmap::DashMap;
use moka::future::Cache;
use reqwest::header;
use sqlx::{Row, SqlitePool};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use thiserror::Error;
use tokio::sync::{Notify, Semaphore};

const MAX_DOWNLOAD_BYTES: u64 = 128 * 1024 * 1024;

#[derive(Error, Debug)]
pub enum ImageCacheError {
    #[error("not found: {0}")]
    NotFound(String),
    #[error("network error: {0}")]
    Network(String),
    #[error("http status {status} for {url}")]
    HttpStatus { status: u16, url: String },
    #[error("disk full while {context}: {source}")]
    DiskFull {
        context: &'static str,
        #[source]
        source: std::io::Error,
    },
    #[error("io error while {context}: {source}")]
    Io {
        context: &'static str,
        #[source]
        source: std::io::Error,
    },
    #[error("db error: {0}")]
    Db(String),
    #[error("invalid request: {0}")]
    Invalid(String),
}

impl From<sqlx::Error> for ImageCacheError {
    fn from(err: sqlx::Error) -> Self {
        ImageCacheError::Db(err.to_string())
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ImageSource {
    Hub { url: String },
    LocalFile { root: String, path: String },
}

#[derive(Clone, Debug)]
pub struct ResolvedImageSource {
    pub source: ImageSource,
    pub full_path: Option<PathBuf>,
}

impl ImageSource {
    pub fn cache_key(&self) -> String {
        match self {
            ImageSource::Hub { url } => format!("hub:{}", sha256_hex(url)),
            ImageSource::LocalFile { root, path } => format!("local:{}:{}", root, path),
        }
    }
}

impl ResolvedImageSource {
    pub fn cache_key(&self) -> String {
        self.source.cache_key()
    }
}

#[derive(Clone)]
struct CachedImage {
    bytes: Bytes,
    content_type: String,
}

#[derive(Default)]
struct CacheMetrics {
    l1_hits: AtomicU64,
    l1_misses: AtomicU64,
    l2_hits: AtomicU64,
    l2_misses: AtomicU64,
    downloads_success: AtomicU64,
    downloads_failed: AtomicU64,
    evictions: AtomicU64,
}

#[derive(Serialize)]
pub struct CacheStats {
    pub memory: MemoryCacheStats,
    pub disk: DiskCacheStats,
}

#[derive(Serialize)]
pub struct MemoryCacheStats {
    pub entries: u64,
    pub size_bytes: u64,
    pub max_size_bytes: u64,
    pub hits: u64,
    pub misses: u64,
}

#[derive(Serialize)]
pub struct DiskCacheStats {
    pub entries: u64,
    pub size_bytes: u64,
    pub max_size_bytes: u64,
    pub path: String,
    pub hits: u64,
    pub misses: u64,
    pub evictions: u64,
    pub downloads_success: u64,
    pub downloads_failed: u64,
}

pub struct ImageCacheService {
    memory_cache: Cache<String, CachedImage>,
    disk_cache: Arc<DiskCache>,
    http_client: reqwest::Client,
    download_semaphore: Arc<Semaphore>,
    pending_downloads: Arc<DashMap<String, Arc<Notify>>>,
    metrics: Arc<CacheMetrics>,
    config: ImageCacheConfig,
    memory_max_bytes: u64,
}

impl ImageCacheService {
    pub async fn new(
        config: ImageCacheConfig,
        db_pool: SqlitePool,
    ) -> Result<Self, ImageCacheError> {
        let memory_max_bytes =
            config.memory_cache_size_mb as u64 * 1024_u64 * 1024_u64;
        let disk_max_bytes = config.disk_cache_size_mb as u64 * 1024_u64 * 1024_u64;
        let ttl = Duration::from_secs(config.cache_ttl_hours as u64 * 3600);

        let memory_cache = Cache::builder()
            .max_capacity(memory_max_bytes)
            .time_to_live(Duration::from_secs(600))
            .weigher(|_key, value: &CachedImage| {
                let size = value.bytes.len();
                size.min(u32::MAX as usize) as u32
            })
            .build();

        let metrics = Arc::new(CacheMetrics::default());
        let disk_cache = DiskCache::new(
            exe_dir().join("ImageCache"),
            disk_max_bytes,
            ttl,
            metrics.clone(),
            db_pool,
        )
        .await?;

        let http_client = reqwest::Client::builder()
            .timeout(Duration::from_secs(30))
            .build()
            .map_err(|err| ImageCacheError::Network(err.to_string()))?;

        Ok(Self {
            memory_cache,
            disk_cache: Arc::new(disk_cache),
            http_client,
            download_semaphore: Arc::new(Semaphore::new(5)),
            pending_downloads: Arc::new(DashMap::new()),
            metrics,
            config,
            memory_max_bytes,
        })
    }

    pub fn start_maintenance(self: Arc<Self>) {
        if !self.config.enabled {
            return;
        }
        let disk_cache = Arc::clone(&self.disk_cache);
        tokio::spawn(async move {
            let mut ticker = tokio::time::interval(Duration::from_secs(3600));
            loop {
                ticker.tick().await;
                if let Err(err) = disk_cache.cleanup_expired().await {
                    tracing::warn!(error = %err, "image cache cleanup failed");
                }
            }
        });
    }

    pub async fn get_or_fetch(
        &self,
        source: ResolvedImageSource,
    ) -> Result<(Bytes, String), ImageCacheError> {
        let key = source.cache_key();
        if self.config.enabled {
            if let Some(cached) = self.memory_cache.get(&key).await {
                self.metrics.l1_hits.fetch_add(1, Ordering::Relaxed);
                return Ok((cached.bytes, cached.content_type));
            }
            self.metrics.l1_misses.fetch_add(1, Ordering::Relaxed);

            match self.disk_cache.get(&key).await {
                Ok(Some((bytes, content_type))) => {
                    self.metrics.l2_hits.fetch_add(1, Ordering::Relaxed);
                    self.insert_memory(&key, bytes.clone(), content_type.clone())
                        .await;
                    return Ok((bytes, content_type));
                }
                Ok(None) => {
                    self.metrics.l2_misses.fetch_add(1, Ordering::Relaxed);
                }
                Err(err) => {
                    self.metrics.l2_misses.fetch_add(1, Ordering::Relaxed);
                    tracing::warn!(error = %err, "disk cache read failed");
                }
            }
        }

        loop {
            let mut is_owner = false;
            let notify = match self.pending_downloads.entry(key.clone()) {
                dashmap::mapref::entry::Entry::Occupied(entry) => entry.get().clone(),
                dashmap::mapref::entry::Entry::Vacant(entry) => {
                    let notify = Arc::new(Notify::new());
                    entry.insert(notify.clone());
                    is_owner = true;
                    notify
                }
            };

            if !is_owner {
                notify.notified().await;
                if self.config.enabled {
                    if let Some(cached) = self.memory_cache.get(&key).await {
                        self.metrics.l1_hits.fetch_add(1, Ordering::Relaxed);
                        return Ok((cached.bytes, cached.content_type));
                    }
                    if let Ok(Some((bytes, content_type))) = self.disk_cache.get(&key).await {
                        self.metrics.l2_hits.fetch_add(1, Ordering::Relaxed);
                        self.insert_memory(&key, bytes.clone(), content_type.clone())
                            .await;
                        return Ok((bytes, content_type));
                    }
                }
                continue;
            }

            let result = self.fetch_source(&source).await;
            if let Ok((bytes, content_type)) = &result {
                self.metrics.downloads_success.fetch_add(1, Ordering::Relaxed);
                if self.config.enabled {
                    self.insert_memory(&key, bytes.clone(), content_type.clone())
                        .await;
                    if let Err(err) = self
                        .disk_cache
                        .put(
                            key.clone(),
                            bytes.clone(),
                            content_type.clone(),
                            source.source.clone(),
                        )
                        .await
                    {
                        tracing::warn!(error = %err, "failed to write image cache entry");
                    }
                }
            } else {
                self.metrics
                    .downloads_failed
                    .fetch_add(1, Ordering::Relaxed);
            }
            self.finish_pending(&key);
            return result;
        }
    }

    pub async fn stats(&self) -> Result<CacheStats, ImageCacheError> {
        let memory_entries = self.memory_cache.entry_count();
        let memory_size = self.memory_cache.weighted_size();
        let disk_stats = self.disk_cache.stats().await?;
        Ok(CacheStats {
            memory: MemoryCacheStats {
                entries: memory_entries,
                size_bytes: memory_size,
                max_size_bytes: self.memory_max_bytes,
                hits: self.metrics.l1_hits.load(Ordering::Relaxed),
                misses: self.metrics.l1_misses.load(Ordering::Relaxed),
            },
            disk: DiskCacheStats {
                entries: disk_stats.entries,
                size_bytes: disk_stats.size_bytes,
                max_size_bytes: disk_stats.max_size_bytes,
                path: disk_stats.path,
                hits: self.metrics.l2_hits.load(Ordering::Relaxed),
                misses: self.metrics.l2_misses.load(Ordering::Relaxed),
                evictions: self.metrics.evictions.load(Ordering::Relaxed),
                downloads_success: self.metrics.downloads_success.load(Ordering::Relaxed),
                downloads_failed: self.metrics.downloads_failed.load(Ordering::Relaxed),
            },
        })
    }

    pub async fn clear(&self) -> Result<(), ImageCacheError> {
        self.memory_cache.invalidate_all();
        self.disk_cache.clear().await
    }

    pub async fn delete_entry(&self, key: &str) -> Result<bool, ImageCacheError> {
        self.memory_cache.invalidate(key).await;
        self.disk_cache.remove(key).await
    }

    async fn insert_memory(&self, key: &str, bytes: Bytes, content_type: String) {
        let cached = CachedImage { bytes, content_type };
        self.memory_cache.insert(key.to_string(), cached).await;
    }

    fn finish_pending(&self, key: &str) {
        if let Some((_, notify)) = self.pending_downloads.remove(key) {
            notify.notify_waiters();
        }
    }

    async fn fetch_source(
        &self,
        source: &ResolvedImageSource,
    ) -> Result<(Bytes, String), ImageCacheError> {
        let _permit = self
            .download_semaphore
            .acquire()
            .await
            .map_err(|_| ImageCacheError::Invalid("download semaphore closed".to_string()))?;
        match &source.source {
            ImageSource::Hub { url } => self.download_hub_image(url).await,
            ImageSource::LocalFile { .. } => {
                let full_path = source
                    .full_path
                    .as_ref()
                    .ok_or_else(|| ImageCacheError::Invalid("local file path missing".to_string()))?;
                read_local_image(full_path).await
            }
        }
    }

    async fn download_hub_image(&self, url: &str) -> Result<(Bytes, String), ImageCacheError> {
        let mut last_err = None;
        for attempt in 0..3 {
            let response = self
                .http_client
                .get(url)
                .headers(hub_headers())
                .send()
                .await;
            match response {
                Ok(mut resp) => {
                    if resp.status().is_success() {
                        if let Some(len) = resp.content_length() {
                            if len > MAX_DOWNLOAD_BYTES {
                                return Err(ImageCacheError::Invalid(format!(
                                    "image exceeds max size {} bytes",
                                    MAX_DOWNLOAD_BYTES
                                )));
                            }
                        }
                        let content_type = resp
                            .headers()
                            .get(header::CONTENT_TYPE)
                            .and_then(|v| v.to_str().ok())
                            .map(|v| v.split(';').next().unwrap_or(v).trim().to_string())
                            .filter(|v| !v.is_empty())
                            .unwrap_or_else(|| content_type_from_url(url).to_string());
                        let mut data = Vec::new();
                        let mut total: u64 = 0;
                        while let Some(chunk) = resp
                            .chunk()
                            .await
                            .map_err(|err| ImageCacheError::Network(err.to_string()))?
                        {
                            total = total.saturating_add(chunk.len() as u64);
                            if total > MAX_DOWNLOAD_BYTES {
                                return Err(ImageCacheError::Invalid(format!(
                                    "image exceeds max size {} bytes",
                                    MAX_DOWNLOAD_BYTES
                                )));
                            }
                            data.extend_from_slice(&chunk);
                        }
                        return Ok((Bytes::from(data), content_type));
                    }
                    if resp.status() == reqwest::StatusCode::NOT_FOUND {
                        return Err(ImageCacheError::NotFound(url.to_string()));
                    }
                    last_err = Some(ImageCacheError::HttpStatus {
                        status: resp.status().as_u16(),
                        url: url.to_string(),
                    });
                }
                Err(err) => {
                    last_err = Some(ImageCacheError::Network(err.to_string()));
                }
            }
            if attempt < 2 {
                let delay_ms = 500_u64.saturating_mul(1_u64 << attempt);
                tracing::warn!(
                    attempt = attempt + 1,
                    delay_ms,
                    "hub image download failed, retrying"
                );
                tokio::time::sleep(Duration::from_millis(delay_ms)).await;
            }
        }
        Err(last_err.unwrap_or_else(|| {
            ImageCacheError::Network("hub image download failed".to_string())
        }))
    }
}

struct DiskCache {
    base_dir: PathBuf,
    images_dir: PathBuf,
    max_size_bytes: u64,
    ttl: Duration,
    metrics: Arc<CacheMetrics>,
    db_pool: SqlitePool,
}

#[derive(Debug)]
struct DiskEntry {
    key: String,
    file_name: String,
    size_bytes: u64,
    content_type: String,
    last_accessed: u64,
}

struct DiskCacheStatsSnapshot {
    entries: u64,
    size_bytes: u64,
    max_size_bytes: u64,
    path: String,
}

impl DiskCache {
    async fn new(
        base_dir: PathBuf,
        max_size_bytes: u64,
        ttl: Duration,
        metrics: Arc<CacheMetrics>,
        db_pool: SqlitePool,
    ) -> Result<Self, ImageCacheError> {
        let images_dir = base_dir.join("images");
        tokio::fs::create_dir_all(&images_dir)
            .await
            .map_err(|err| map_io_error("create image cache directory", err))?;
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS image_cache_entries (
                cache_key TEXT PRIMARY KEY,
                file_name TEXT NOT NULL,
                source_type TEXT,
                source_url TEXT,
                source_root TEXT,
                source_path TEXT,
                size_bytes INTEGER NOT NULL,
                content_type TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                last_accessed INTEGER NOT NULL,
                access_count INTEGER NOT NULL DEFAULT 1
            );
            CREATE INDEX IF NOT EXISTS idx_last_accessed ON image_cache_entries(last_accessed);
            "#
        )
            .execute(&db_pool)
            .await
            .map_err(ImageCacheError::from)?;

        let cache = Self {
            base_dir,
            images_dir,
            max_size_bytes,
            ttl,
            metrics,
            db_pool,
        };
        cache.cleanup_orphaned().await?;
        Ok(cache)
    }

    async fn get(&self, key: &str) -> Result<Option<(Bytes, String)>, ImageCacheError> {
        let entry = self.load_entry(key).await?;
        let entry = match entry {
            Some(entry) => entry,
            None => return Ok(None),
        };
        let now = now_ts();
        if self.ttl.as_secs() > 0
            && now.saturating_sub(entry.last_accessed) > self.ttl.as_secs()
        {
            self.remove_entry(&entry.key, &entry.file_name).await?;
            return Ok(None);
        }

        let file_path = self.images_dir.join(&entry.file_name);
        let bytes = match tokio::fs::read(&file_path).await {
            Ok(bytes) => bytes,
            Err(err) => {
                self.remove_entry_best_effort(&entry.key, &entry.file_name)
                    .await;
                if err.kind() != std::io::ErrorKind::NotFound {
                    tracing::warn!(error = %err, "failed to read cached image");
                }
                return Ok(None);
            }
        };

        if bytes.len() as u64 != entry.size_bytes {
            self.remove_entry_best_effort(&entry.key, &entry.file_name)
                .await;
            tracing::warn!(
                key = %entry.key,
                expected = entry.size_bytes,
                actual = bytes.len(),
                "cached image size mismatch, removed entry"
            );
            return Ok(None);
        }

        self.touch_entry(&entry.key, now).await?;
        Ok(Some((Bytes::from(bytes), entry.content_type)))
    }

    async fn put(
        &self,
        key: String,
        bytes: Bytes,
        content_type: String,
        source: ImageSource,
    ) -> Result<(), ImageCacheError> {
        if bytes.is_empty() {
            return Err(ImageCacheError::Invalid("empty image payload".to_string()));
        }
        let size_bytes = bytes.len() as u64;
        if size_bytes > self.max_size_bytes {
            return Err(ImageCacheError::Invalid(
                "image exceeds disk cache capacity".to_string(),
            ));
        }

        let existing = self.lookup_entry_meta(&key).await?;
        let effective_needed = size_bytes.saturating_sub(
            existing
                .as_ref()
                .map(|entry| entry.size_bytes)
                .unwrap_or(0),
        );
        self.ensure_disk_space(effective_needed).await?;

        let extension = extension_from_content_type(&content_type)
            .or_else(|| extension_from_source(&source))
            .unwrap_or_else(|| "bin".to_string());
        let file_name = format!("{}.{}", sha256_hex(&key), extension);
        let file_path = self.images_dir.join(&file_name);
        tokio::fs::write(&file_path, bytes)
            .await
            .map_err(|err| map_io_error("write cache file", err))?;

        let now = now_ts();
        let (source_type, source_url, source_root, source_path) = source_fields(&source);
        let result = self
            .insert_entry(
            &key,
            &file_name,
            &content_type,
            size_bytes,
            now,
            source_type,
            source_url,
            source_root,
            source_path,
        )
        .await;
        if let Err(err) = result {
            self.remove_file_best_effort(&file_name).await;
            return Err(err);
        }

        if let Some(old) = existing {
            if old.file_name != file_name {
                self.remove_file_best_effort(&old.file_name).await;
            }
        }
        Ok(())
    }

    async fn remove(&self, key: &str) -> Result<bool, ImageCacheError> {
        let entry = self.load_entry_meta(key).await?;
        let entry = match entry {
            Some(entry) => entry,
            None => return Ok(false),
        };
        self.delete_entry(key).await?;
        self.remove_file(&entry.file_name).await?;
        Ok(true)
    }

    async fn clear(&self) -> Result<(), ImageCacheError> {
        let entries = self.load_all_entry_files().await?;
        sqlx::query("DELETE FROM image_cache_entries")
            .execute(&self.db_pool)
            .await
            .map_err(ImageCacheError::from)?;
        for file_name in entries {
            self.remove_file(&file_name).await?;
        }
        Ok(())
    }

    async fn stats(&self) -> Result<DiskCacheStatsSnapshot, ImageCacheError> {
        let row = sqlx::query(
            "SELECT COUNT(1), COALESCE(SUM(size_bytes), 0) FROM image_cache_entries",
        )
        .fetch_one(&self.db_pool)
        .await
        .map_err(ImageCacheError::from)?;
        let entries: i64 = row.try_get(0).map_err(ImageCacheError::from)?;
        let size_bytes: i64 = row.try_get(1).map_err(ImageCacheError::from)?;
        Ok(DiskCacheStatsSnapshot {
            entries: entries as u64,
            size_bytes: size_bytes as u64,
            max_size_bytes: self.max_size_bytes,
            path: self.base_dir.to_string_lossy().to_string(),
        })
    }

    async fn cleanup_expired(&self) -> Result<(), ImageCacheError> {
        if self.ttl.as_secs() == 0 {
            return Ok(());
        }
        let cutoff = now_ts().saturating_sub(self.ttl.as_secs());
        let entries = self.load_entries_before(cutoff).await?;
        if entries.is_empty() {
            return Ok(());
        }
        for entry in entries {
            self.remove_entry(&entry.key, &entry.file_name).await?;
        }
        Ok(())
    }

    async fn cleanup_orphaned(&self) -> Result<(), ImageCacheError> {
        let now = now_ts();
        let ttl_secs = self.ttl.as_secs();
        let entries = self.load_all_entries().await?;
        for entry in entries {
            let expired = ttl_secs > 0 && now.saturating_sub(entry.last_accessed) > ttl_secs;
            let missing = !self.images_dir.join(&entry.file_name).exists();
            if expired || missing {
                self.remove_entry(&entry.key, &entry.file_name).await?;
            }
        }
        Ok(())
    }

    async fn ensure_disk_space(&self, needed: u64) -> Result<(), ImageCacheError> {
        if needed == 0 {
            return Ok(());
        }
        self.cleanup_expired().await?;

        let row = sqlx::query(
            "SELECT COALESCE(SUM(size_bytes), 0) FROM image_cache_entries",
        )
        .fetch_one(&self.db_pool)
        .await
        .map_err(ImageCacheError::from)?;
        let total_size: i64 = row.try_get(0).map_err(ImageCacheError::from)?;
        let total_size = total_size as u64;

        if total_size.saturating_add(needed) <= self.max_size_bytes {
            return Ok(());
        }

        let rows = sqlx::query(
            "SELECT cache_key, file_name, size_bytes FROM image_cache_entries \
             ORDER BY last_accessed ASC",
        )
        .fetch_all(&self.db_pool)
        .await
        .map_err(ImageCacheError::from)?;

        let mut remaining = total_size;
        let mut to_remove = Vec::new();
        for row in rows {
            let key: String = row.try_get(0).map_err(ImageCacheError::from)?;
            let file_name: String = row.try_get(1).map_err(ImageCacheError::from)?;
            let size: i64 = row.try_get(2).map_err(ImageCacheError::from)?;
            remaining = remaining.saturating_sub(size.max(0) as u64);
            to_remove.push((key, file_name));
            if remaining.saturating_add(needed) <= self.max_size_bytes {
                break;
            }
        }

        for (key, _) in &to_remove {
            sqlx::query("DELETE FROM image_cache_entries WHERE cache_key = ?1")
                .bind(key)
                .execute(&self.db_pool)
                .await
                .map_err(ImageCacheError::from)?;
            self.metrics.evictions.fetch_add(1, Ordering::Relaxed);
        }

        for (_, file_name) in &to_remove {
            self.remove_file_best_effort(file_name).await;
        }

        Ok(())
    }

    async fn load_entry(&self, key: &str) -> Result<Option<DiskEntry>, ImageCacheError> {
        let row = sqlx::query(
            "SELECT cache_key, file_name, size_bytes, content_type, last_accessed \
             FROM image_cache_entries WHERE cache_key = ?1",
        )
        .bind(key)
        .fetch_optional(&self.db_pool)
        .await
        .map_err(ImageCacheError::from)?;
        let row = match row {
            Some(row) => row,
            None => return Ok(None),
        };
        Ok(Some(DiskEntry {
            key: row.try_get::<String, _>(0).map_err(ImageCacheError::from)?,
            file_name: row.try_get::<String, _>(1).map_err(ImageCacheError::from)?,
            size_bytes: row.try_get::<i64, _>(2).map_err(ImageCacheError::from)? as u64,
            content_type: row.try_get::<String, _>(3).map_err(ImageCacheError::from)?,
            last_accessed: row.try_get::<i64, _>(4).map_err(ImageCacheError::from)? as u64,
        }))
    }

    async fn load_entry_meta(&self, key: &str) -> Result<Option<DiskEntry>, ImageCacheError> {
        self.load_entry(key).await
    }

    async fn lookup_entry_meta(&self, key: &str) -> Result<Option<DiskEntry>, ImageCacheError> {
        self.load_entry_meta(key).await
    }

    async fn load_all_entries(&self) -> Result<Vec<DiskEntry>, ImageCacheError> {
        let rows = sqlx::query(
            "SELECT cache_key, file_name, size_bytes, content_type, last_accessed \
             FROM image_cache_entries",
        )
        .fetch_all(&self.db_pool)
        .await
        .map_err(ImageCacheError::from)?;
        let mut entries = Vec::new();
        for row in rows {
            entries.push(DiskEntry {
                key: row.try_get::<String, _>(0).map_err(ImageCacheError::from)?,
                file_name: row.try_get::<String, _>(1).map_err(ImageCacheError::from)?,
                size_bytes: row.try_get::<i64, _>(2).map_err(ImageCacheError::from)? as u64,
                content_type: row.try_get::<String, _>(3).map_err(ImageCacheError::from)?,
                last_accessed: row.try_get::<i64, _>(4).map_err(ImageCacheError::from)? as u64,
            });
        }
        Ok(entries)
    }

    async fn load_all_entry_files(&self) -> Result<Vec<String>, ImageCacheError> {
        let rows = sqlx::query("SELECT file_name FROM image_cache_entries")
            .fetch_all(&self.db_pool)
            .await
            .map_err(ImageCacheError::from)?;
        let mut files = Vec::new();
        for row in rows {
            files.push(row.try_get::<String, _>(0).map_err(ImageCacheError::from)?);
        }
        Ok(files)
    }

    async fn load_entries_before(&self, cutoff: u64) -> Result<Vec<DiskEntry>, ImageCacheError> {
        let rows = sqlx::query(
            "SELECT cache_key, file_name, size_bytes, content_type, last_accessed \
             FROM image_cache_entries WHERE last_accessed < ?1",
        )
        .bind(cutoff as i64)
        .fetch_all(&self.db_pool)
        .await
        .map_err(ImageCacheError::from)?;
        let mut entries = Vec::new();
        for row in rows {
            entries.push(DiskEntry {
                key: row.try_get::<String, _>(0).map_err(ImageCacheError::from)?,
                file_name: row.try_get::<String, _>(1).map_err(ImageCacheError::from)?,
                size_bytes: row.try_get::<i64, _>(2).map_err(ImageCacheError::from)? as u64,
                content_type: row.try_get::<String, _>(3).map_err(ImageCacheError::from)?,
                last_accessed: row.try_get::<i64, _>(4).map_err(ImageCacheError::from)? as u64,
            });
        }
        Ok(entries)
    }

    #[allow(clippy::too_many_arguments)]
    async fn insert_entry(
        &self,
        key: &str,
        file_name: &str,
        content_type: &str,
        size_bytes: u64,
        now: u64,
        source_type: String,
        source_url: Option<String>,
        source_root: Option<String>,
        source_path: Option<String>,
    ) -> Result<(), ImageCacheError> {
        sqlx::query(
            "INSERT OR REPLACE INTO image_cache_entries \
             (cache_key, file_name, source_type, source_url, source_root, source_path, \
             size_bytes, content_type, created_at, last_accessed, access_count) \
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)",
        )
        .bind(key)
        .bind(file_name)
        .bind(source_type)
        .bind(source_url)
        .bind(source_root)
        .bind(source_path)
        .bind(size_bytes as i64)
        .bind(content_type)
        .bind(now as i64)
        .bind(now as i64)
        .bind(1_i64)
        .execute(&self.db_pool)
        .await
        .map_err(ImageCacheError::from)?;
        Ok(())
    }

    async fn delete_entry(&self, key: &str) -> Result<(), ImageCacheError> {
        sqlx::query("DELETE FROM image_cache_entries WHERE cache_key = ?1")
            .bind(key)
            .execute(&self.db_pool)
            .await
            .map_err(ImageCacheError::from)?;
        Ok(())
    }

    async fn touch_entry(&self, key: &str, now: u64) -> Result<(), ImageCacheError> {
        sqlx::query(
            "UPDATE image_cache_entries \
             SET last_accessed = ?1, access_count = access_count + 1 \
             WHERE cache_key = ?2",
        )
        .bind(now as i64)
        .bind(key)
        .execute(&self.db_pool)
        .await
        .map_err(ImageCacheError::from)?;
        Ok(())
    }

    async fn remove_entry(&self, key: &str, file_name: &str) -> Result<(), ImageCacheError> {
        self.delete_entry(key).await?;
        self.remove_file(file_name).await
    }

    async fn remove_entry_best_effort(&self, key: &str, file_name: &str) {
        if let Err(err) = self.delete_entry(key).await {
            tracing::warn!(error = %err, "failed to delete cache entry metadata");
        }
        self.remove_file_best_effort(file_name).await;
    }

    async fn remove_file(&self, file_name: &str) -> Result<(), ImageCacheError> {
        let path = self.images_dir.join(file_name);
        match tokio::fs::remove_file(&path).await {
            Ok(_) => Ok(()),
            Err(err) if err.kind() == std::io::ErrorKind::NotFound => Ok(()),
            Err(err) => Err(map_io_error("remove cache file", err)),
        }
    }

    async fn remove_file_best_effort(&self, file_name: &str) {
        let path = self.images_dir.join(file_name);
        if let Err(err) = tokio::fs::remove_file(&path).await {
            if err.kind() != std::io::ErrorKind::NotFound {
                tracing::warn!(error = %err, "failed to remove cache file");
            }
        }
    }
}

async fn read_local_image(path: &Path) -> Result<(Bytes, String), ImageCacheError> {
    let bytes = tokio::fs::read(path).await.map_err(|err| {
        if err.kind() == std::io::ErrorKind::NotFound {
            ImageCacheError::NotFound(path.display().to_string())
        } else {
            map_io_error("read local image", err)
        }
    })?;
    let content_type = content_type_from_extension(path.extension().and_then(|s| s.to_str()));
    Ok((Bytes::from(bytes), content_type.to_string()))
}

fn sha256_hex(input: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(input.as_bytes());
    let hash = hasher.finalize();
    hex::encode(hash)
}

fn now_ts() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_else(|_| Duration::from_secs(0))
        .as_secs()
}

fn content_type_from_extension(ext: Option<&str>) -> &'static str {
    match ext.map(|s| s.to_lowercase()) {
        Some(ext) if ext == "png" => "image/png",
        Some(ext) if ext == "jpg" || ext == "jpeg" => "image/jpeg",
        Some(ext) if ext == "gif" => "image/gif",
        Some(ext) if ext == "webp" => "image/webp",
        Some(ext) if ext == "avif" => "image/avif",
        _ => "application/octet-stream",
    }
}

fn content_type_from_url(url: &str) -> &'static str {
    let ext = extension_from_url(url);
    content_type_from_extension(ext.as_deref())
}

fn extension_from_content_type(content_type: &str) -> Option<String> {
    let normalized = content_type.split(';').next()?.trim().to_lowercase();
    let ext = match normalized.as_str() {
        "image/png" => "png",
        "image/jpeg" => "jpg",
        "image/gif" => "gif",
        "image/webp" => "webp",
        "image/avif" => "avif",
        _ => return None,
    };
    Some(ext.to_string())
}

fn extension_from_source(source: &ImageSource) -> Option<String> {
    match source {
        ImageSource::Hub { url } => extension_from_url(url),
        ImageSource::LocalFile { path, .. } => Path::new(path)
            .extension()
            .and_then(|s| s.to_str())
            .map(|s| s.to_lowercase()),
    }
}

fn extension_from_url(url: &str) -> Option<String> {
    url::Url::parse(url)
        .ok()
        .and_then(|parsed| {
            Path::new(parsed.path())
                .extension()
                .and_then(|s| s.to_str())
                .map(|s| s.to_lowercase())
        })
}

fn source_fields(
    source: &ImageSource,
) -> (String, Option<String>, Option<String>, Option<String>) {
    match source {
        ImageSource::Hub { url } => (
            "hub".to_string(),
            Some(url.to_string()),
            None,
            None,
        ),
        ImageSource::LocalFile { root, path } => (
            "local".to_string(),
            None,
            Some(root.to_string()),
            Some(path.to_string()),
        ),
    }
}

fn is_disk_full_error(err: &std::io::Error) -> bool {
    err.raw_os_error() == Some(112)
}

fn map_io_error(context: &'static str, err: std::io::Error) -> ImageCacheError {
    if is_disk_full_error(&err) {
        ImageCacheError::DiskFull { context, source: err }
    } else {
        ImageCacheError::Io { context, source: err }
    }
}

fn hub_headers() -> header::HeaderMap {
    let mut headers = header::HeaderMap::new();
    headers.insert(
        header::ACCEPT,
        "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
            .parse()
            .unwrap(),
    );
    headers.insert(
        header::ACCEPT_ENCODING,
        "gzip, deflate, br, zstd".parse().unwrap(),
    );
    headers.insert(
        header::ACCEPT_LANGUAGE,
        "en-US,en;q=0.9".parse().unwrap(),
    );
    headers.insert(header::COOKIE, "vamhubconsent=yes".parse().unwrap());
    headers.insert(header::DNT, "1".parse().unwrap());
    headers.insert(
        header::HeaderName::from_static("sec-ch-ua"),
        "\"Not)A;Brand\";v=\"99\", \"Microsoft Edge\";v=\"127\", \"Chromium\";v=\"127\""
            .parse()
            .unwrap(),
    );
    headers.insert(
        header::HeaderName::from_static("sec-ch-ua-mobile"),
        "?0".parse().unwrap(),
    );
    headers.insert(
        header::HeaderName::from_static("sec-ch-ua-platform"),
        "\"Windows\"".parse().unwrap(),
    );
    headers.insert(
        header::HeaderName::from_static("sec-fetch-dest"),
        "document".parse().unwrap(),
    );
    headers.insert(
        header::HeaderName::from_static("sec-fetch-mode"),
        "navigate".parse().unwrap(),
    );
    headers.insert(
        header::HeaderName::from_static("sec-fetch-site"),
        "none".parse().unwrap(),
    );
    headers.insert(
        header::HeaderName::from_static("sec-fetch-user"),
        "?1".parse().unwrap(),
    );
    headers.insert(header::UPGRADE_INSECURE_REQUESTS, "1".parse().unwrap());
    headers.insert(
        header::USER_AGENT,
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36 Edg/127.0.0.0"
            .parse()
            .unwrap(),
    );
    headers
}
