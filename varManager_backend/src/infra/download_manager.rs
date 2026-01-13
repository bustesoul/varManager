use crate::app::Config;
use crate::infra::downloader::{
    ensure_dir, finalize_download, is_retryable_error, resolve_download_save_path_config,
    resolve_file_info, resolve_final_url_with_retry,
};
use dashmap::DashMap;
use headers::{HeaderMap, HeaderName, HeaderValue};
use http_downloader::{
    speed_limiter::DownloadSpeedLimiterExtension, speed_tracker::DownloadSpeedTrackerExtension,
    status_tracker::DownloadStatusTrackerExtension, DownloadingEndCause, HttpDownloaderBuilder,
};
use reqwest::Client;
use serde::Serialize;
use sqlx::{Row, SqlitePool};
use std::num::{NonZeroU8, NonZeroUsize};
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};
use tokio::sync::{watch, Semaphore};
use tokio::time::{interval, timeout, Duration, Instant};
use url::Url;

struct DownloadRuntimeConfig {
    concurrency: usize,
    connection_count: NonZeroU8,
    chunk_size: NonZeroUsize,
    http_timeout: Duration,
    per_file_timeout: Duration,
    max_get_retries: u8,
    max_download_retries: u8,
    progress_tick: Duration,
    progress_db_flush: Duration,
}

#[derive(Clone, Copy, Debug)]
pub enum DownloadAction {
    Pause,
    Resume,
    Remove,
    Delete,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct DownloadItemView {
    pub id: i64,
    pub url: String,
    pub name: Option<String>,
    pub status: String,
    pub downloaded_bytes: u64,
    pub total_bytes: Option<u64>,
    pub speed_bytes: u64,
    pub error: Option<String>,
    pub save_path: Option<String>,
    pub temp_path: Option<String>,
    pub created_at: i64,
    pub updated_at: i64,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct DownloadSummary {
    pub total: usize,
    pub queued: usize,
    pub downloading: usize,
    pub paused: usize,
    pub failed: usize,
    pub completed: usize,
    pub downloaded_bytes: u64,
    pub total_bytes: u64,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "snake_case")]
pub struct DownloadListResponse {
    pub items: Vec<DownloadItemView>,
    pub summary: DownloadSummary,
}

#[derive(Clone, Debug)]
pub struct DownloadEnqueueItem {
    pub url: String,
    pub name: Option<String>,
    pub size: Option<u64>,
}

#[derive(Clone)]
pub struct DownloadManager {
    db_pool: SqlitePool,
    config: Arc<RwLock<Config>>,
    client: Arc<Client>,
    semaphore: Arc<Semaphore>,
    active: Arc<DashMap<i64, DownloadHandle>>,
}

#[derive(Clone)]
struct DownloadHandle {
    cancel: watch::Sender<bool>,
}

impl DownloadManager {
    pub fn new(db_pool: SqlitePool, config: Arc<RwLock<Config>>) -> Self {
        let runtime = read_runtime_config(&config);
        let client = Arc::new(
            Client::builder()
                .redirect(reqwest::redirect::Policy::none())
                .timeout(runtime.http_timeout)
                .build()
                .expect("download client build failed"),
        );
        Self {
            db_pool,
            config,
            client,
            semaphore: Arc::new(Semaphore::new(runtime.concurrency)),
            active: Arc::new(DashMap::new()),
        }
    }

    pub async fn pause_incomplete(&self) -> Result<(), String> {
        let now = now_ts();
        sqlx::query(
            r#"
            UPDATE downloads
            SET status = 'paused', speed_bytes = 0, updated_at = ?1
            WHERE status IN ('queued', 'downloading')
            "#,
        )
        .bind(now)
        .execute(&self.db_pool)
        .await
        .map_err(|err| err.to_string())?;
        Ok(())
    }

    #[allow(dead_code)]
    pub async fn enqueue_urls(&self, urls: Vec<String>) -> Result<usize, String> {
        let items = urls
            .into_iter()
            .filter_map(|raw| {
                let trimmed = raw.trim().to_string();
                if trimmed.is_empty() {
                    return None;
                }
                if !trimmed.starts_with("http://") && !trimmed.starts_with("https://") {
                    return None;
                }
                Some(DownloadEnqueueItem {
                    url: trimmed,
                    name: None,
                    size: None,
                })
            })
            .collect::<Vec<_>>();
        self.enqueue_items(items).await
    }

    pub async fn enqueue_items(&self, items: Vec<DownloadEnqueueItem>) -> Result<usize, String> {
        if items.is_empty() {
            return Ok(0);
        }
        let mut added = 0usize;
        for item in items {
            if self.is_duplicate(&item.url).await? {
                continue;
            }
            let now = now_ts();
            let result = sqlx::query(
                r#"
                INSERT INTO downloads (url, name, status, downloaded_bytes, total_bytes, speed_bytes, error, created_at, updated_at)
                VALUES (?1, ?2, 'queued', 0, ?3, 0, NULL, ?4, ?4)
                "#,
            )
            .bind(&item.url)
            .bind(&item.name)
            .bind(item.size.map(|v| v as i64))
            .bind(now)
            .execute(&self.db_pool)
            .await
            .map_err(|err| err.to_string())?;
            let id = result.last_insert_rowid();
            self.start_download(id).await?;
            added += 1;
        }
        Ok(added)
    }

    pub async fn list_downloads(&self) -> Result<DownloadListResponse, String> {
        let rows = sqlx::query(
            r#"
            SELECT id, url, name, status, downloaded_bytes, total_bytes, speed_bytes, error, save_path, temp_path, created_at, updated_at
            FROM downloads
            ORDER BY created_at DESC
            "#,
        )
        .fetch_all(&self.db_pool)
        .await
        .map_err(|err| err.to_string())?;

        let mut items = Vec::with_capacity(rows.len());
        let mut summary = DownloadSummary {
            total: rows.len(),
            queued: 0,
            downloading: 0,
            paused: 0,
            failed: 0,
            completed: 0,
            downloaded_bytes: 0,
            total_bytes: 0,
        };

        for row in rows {
            let status: String = row
                .try_get("status")
                .unwrap_or_else(|_| "queued".to_string());
            let downloaded_bytes: i64 = row.try_get("downloaded_bytes").unwrap_or(0);
            let total_bytes: Option<i64> = row.try_get("total_bytes").ok();
            let speed_bytes: i64 = row.try_get("speed_bytes").unwrap_or(0);
            summary.downloaded_bytes = summary
                .downloaded_bytes
                .saturating_add(downloaded_bytes.max(0) as u64);
            if let Some(total) = total_bytes {
                if total > 0 {
                    summary.total_bytes = summary.total_bytes.saturating_add(total as u64);
                }
            }
            match status.as_str() {
                "queued" => summary.queued += 1,
                "downloading" => summary.downloading += 1,
                "paused" => summary.paused += 1,
                "failed" => summary.failed += 1,
                "completed" => summary.completed += 1,
                _ => {}
            }
            items.push(DownloadItemView {
                id: row.try_get("id").unwrap_or_default(),
                url: row.try_get("url").unwrap_or_default(),
                name: row.try_get("name").ok(),
                status,
                downloaded_bytes: downloaded_bytes.max(0) as u64,
                total_bytes: total_bytes.and_then(|v| if v > 0 { Some(v as u64) } else { None }),
                speed_bytes: speed_bytes.max(0) as u64,
                error: row.try_get("error").ok(),
                save_path: row.try_get("save_path").ok(),
                temp_path: row.try_get("temp_path").ok(),
                created_at: row.try_get("created_at").unwrap_or(0),
                updated_at: row.try_get("updated_at").unwrap_or(0),
            });
        }

        Ok(DownloadListResponse { items, summary })
    }

    pub async fn apply_action(&self, action: DownloadAction, ids: Vec<i64>) -> Result<(), String> {
        match action {
            DownloadAction::Pause => self.pause_ids(ids).await,
            DownloadAction::Resume => self.resume_ids(ids).await,
            DownloadAction::Remove => self.remove_ids(ids).await,
            DownloadAction::Delete => self.delete_ids(ids).await,
        }
    }

    async fn pause_ids(&self, ids: Vec<i64>) -> Result<(), String> {
        if ids.is_empty() {
            return Ok(());
        }
        let now = now_ts();
        for id in ids {
            sqlx::query(
                "UPDATE downloads SET status = 'paused', speed_bytes = 0, updated_at = ?1 WHERE id = ?2",
            )
            .bind(now)
            .bind(id)
            .execute(&self.db_pool)
            .await
            .map_err(|err| err.to_string())?;
            if let Some(handle) = self.active.get(&id) {
                let _ = handle.cancel.send(true);
            }
            self.active.remove(&id);
        }
        Ok(())
    }

    async fn resume_ids(&self, ids: Vec<i64>) -> Result<(), String> {
        for id in ids {
            let now = now_ts();
            sqlx::query(
                "UPDATE downloads SET status = 'queued', error = NULL, updated_at = ?1 WHERE id = ?2",
            )
            .bind(now)
            .bind(id)
            .execute(&self.db_pool)
            .await
            .map_err(|err| err.to_string())?;
            self.start_download(id).await?;
        }
        Ok(())
    }

    async fn remove_ids(&self, ids: Vec<i64>) -> Result<(), String> {
        for id in ids {
            self.cancel_active(id).await;
            sqlx::query("DELETE FROM downloads WHERE id = ?1")
                .bind(id)
                .execute(&self.db_pool)
                .await
                .map_err(|err| err.to_string())?;
        }
        Ok(())
    }

    async fn delete_ids(&self, ids: Vec<i64>) -> Result<(), String> {
        for id in ids {
            self.cancel_active(id).await;
            let row = sqlx::query("SELECT save_path, temp_path FROM downloads WHERE id = ?1")
                .bind(id)
                .fetch_optional(&self.db_pool)
                .await
                .map_err(|err| err.to_string())?;
            if let Some(row) = row {
                let save_path: Option<String> = row.try_get("save_path").ok();
                let temp_path: Option<String> = row.try_get("temp_path").ok();
                if let Some(path) = save_path.as_ref() {
                    let _ = delete_file(path);
                }
                if let Some(path) = temp_path.as_ref() {
                    let _ = delete_file(path);
                }
            }
            sqlx::query("DELETE FROM downloads WHERE id = ?1")
                .bind(id)
                .execute(&self.db_pool)
                .await
                .map_err(|err| err.to_string())?;
        }
        Ok(())
    }

    async fn cancel_active(&self, id: i64) {
        if let Some(handle) = self.active.get(&id) {
            let _ = handle.cancel.send(true);
        }
        self.active.remove(&id);
    }

    async fn is_duplicate(&self, url: &str) -> Result<bool, String> {
        let row = sqlx::query(
            "SELECT 1 FROM downloads WHERE url = ?1 AND status IN ('queued', 'downloading', 'paused') LIMIT 1",
        )
        .bind(url)
        .fetch_optional(&self.db_pool)
        .await
        .map_err(|err| err.to_string())?;
        Ok(row.is_some())
    }

    async fn start_download(&self, id: i64) -> Result<(), String> {
        if self.active.contains_key(&id) {
            return Ok(());
        }
        let row = sqlx::query("SELECT url, name FROM downloads WHERE id = ?1")
            .bind(id)
            .fetch_optional(&self.db_pool)
            .await
            .map_err(|err| err.to_string())?;
        let Some(row) = row else {
            return Ok(());
        };
        let url: String = row.try_get("url").unwrap_or_default();
        let name: Option<String> = row.try_get("name").ok();
        if url.is_empty() {
            return Ok(());
        }
        let (cancel_tx, cancel_rx) = watch::channel(false);
        self.active.insert(id, DownloadHandle { cancel: cancel_tx });
        let db_pool = self.db_pool.clone();
        let client = Arc::clone(&self.client);
        let config = Arc::clone(&self.config);
        let semaphore = Arc::clone(&self.semaphore);
        let active = Arc::clone(&self.active);

        tokio::spawn(async move {
            let _permit = match semaphore.acquire().await {
                Ok(permit) => permit,
                Err(_) => {
                    let _ = update_status(
                        &db_pool,
                        id,
                        "failed",
                        Some("failed to acquire download slot".to_string()),
                    )
                    .await;
                    active.remove(&id);
                    return;
                }
            };
            let _ = update_status(&db_pool, id, "downloading", None).await;
            let result = download_with_progress(
                &db_pool,
                &config,
                &client,
                id,
                &url,
                name.as_deref(),
                cancel_rx,
            )
            .await;
            if let Err(err) = result {
                let _ = update_status(&db_pool, id, "failed", Some(err)).await;
            }
            active.remove(&id);
        });

        Ok(())
    }
}

async fn download_with_progress(
    db_pool: &SqlitePool,
    config: &Arc<RwLock<Config>>,
    client: &Client,
    id: i64,
    url: &str,
    name_hint: Option<&str>,
    cancel_rx: watch::Receiver<bool>,
) -> Result<(), String> {
    let runtime = read_runtime_config(config);
    let save_dir = {
        let cfg = config
            .read()
            .map_err(|_| "config lock poisoned".to_string())?;
        resolve_download_save_path_config(&cfg)?
    };
    ensure_dir(&save_dir)?;

    let final_url = resolve_final_url_with_retry(url, client, runtime.max_get_retries).await?;
    let (filename, head_size) = resolve_file_info(&final_url, client).await?;

    // Priority: Content-Disposition filename > name_hint > URL filename
    // Content-Disposition from server is the most accurate source
    let final_name = if filename != "default_filename" && filename.to_lowercase().ends_with(".var")
    {
        // Server returned a valid .var filename, use it
        filename
    } else if let Some(hint) = name_hint {
        // Fallback to name_hint if provided
        let trimmed = hint.trim();
        if trimmed.is_empty() {
            filename
        } else if trimmed.to_lowercase().ends_with(".var") {
            trimmed.to_string()
        } else {
            format!("{}.var", trimmed)
        }
    } else {
        filename
    };
    let url_obj = Url::parse(&final_url).map_err(|err| err.to_string())?;
    let temp_path = download_temp_path(&url_obj, &save_dir);
    let save_path = save_dir.join(&final_name);
    let _ = update_paths(db_pool, id, &save_path, &temp_path).await;
    if let Some(size) = head_size {
        let _ = update_total_bytes(db_pool, id, size).await;
    }

    let mut attempt: u8 = 0;
    loop {
        if *cancel_rx.borrow() {
            let _ = update_status(db_pool, id, "paused", None).await;
            return Ok(());
        }
        attempt += 1;
        let mut cancel_rx = cancel_rx.clone();
        let (mut downloader, (_status_state, speed_state, _speed_limiter)) =
            HttpDownloaderBuilder::new(url_obj.clone(), save_dir.clone())
                .chunk_size(runtime.chunk_size)
                .download_connection_count(runtime.connection_count)
                .request_retry_count(runtime.max_get_retries)
                .header_map(hub_headers_compat())
                .build((
                    DownloadStatusTrackerExtension { log: false },
                    DownloadSpeedTrackerExtension { log: false },
                    DownloadSpeedLimiterExtension::new(None),
                ));

        let download_future = downloader
            .prepare_download()
            .map_err(|err| err.to_string())?;
        tokio::pin!(download_future);

        let mut ticker = interval(runtime.progress_tick);
        let mut last_flush = Instant::now();
        let mut last_downloaded = 0u64;
        let mut last_speed = 0u64;
        let download_result = timeout(
            runtime.per_file_timeout,
            async {
                loop {
                    tokio::select! {
                        _ = cancel_rx.changed() => {
                            if !*cancel_rx.borrow() {
                                continue;
                            }
                            downloader.cancel().await;
                            break Ok(DownloadingEndCause::Cancelled);
                        }
                        _ = ticker.tick() => {
                            let downloaded = downloader.downloaded_len();
                            let total = downloader
                                .current_total_size()
                                .map(|v| v.get())
                                .or(head_size);
                            let speed = speed_state.download_speed();
                            if downloaded != last_downloaded || speed != last_speed || last_flush.elapsed() >= runtime.progress_db_flush {
                                let _ = update_progress(db_pool, id, downloaded, total, speed).await;
                                last_downloaded = downloaded;
                                last_speed = speed;
                                last_flush = Instant::now();
                            }
                        }
                        result = &mut download_future => {
                            match result {
                                Ok(end) => {
                                    break Ok(end);
                                }
                                Err(err) => {
                                    break Err(err.to_string());
                                }
                            }
                        }
                    }
                }
            },
        )
        .await;

        match download_result {
            Ok(Ok(DownloadingEndCause::DownloadFinished)) => {
                finalize_download(&url_obj, &save_dir, &final_name)?;
                let total = downloader
                    .current_total_size()
                    .map(|v| v.get())
                    .or(head_size);
                let downloaded = downloader.downloaded_len();
                let _ = update_progress(db_pool, id, downloaded, total, 0).await;
                let _ = update_status(db_pool, id, "completed", None).await;
                return Ok(());
            }
            Ok(Ok(DownloadingEndCause::Cancelled)) => {
                let _ = update_status(db_pool, id, "paused", None).await;
                return Ok(());
            }
            Ok(Err(err)) => {
                if attempt <= runtime.max_download_retries && is_retryable_error(&err) {
                    tokio::time::sleep(Duration::from_secs(2)).await;
                    continue;
                }
                return Err(err);
            }
            Err(_) => {
                if attempt <= runtime.max_download_retries {
                    tokio::time::sleep(Duration::from_secs(2)).await;
                    continue;
                }
                return Err(format!("download timed out after {} attempts", attempt));
            }
        }
    }
}

fn download_temp_path(url: &Url, save_dir: &Path) -> PathBuf {
    let filename = url
        .path_segments()
        .and_then(|mut s| s.next_back())
        .unwrap_or("unknown_temp_file");
    save_dir.join(filename)
}

fn read_runtime_config(config: &Arc<RwLock<Config>>) -> DownloadRuntimeConfig {
    let defaults = crate::app::DownloadConfig::default();
    let cfg = config
        .read()
        .map(|guard| guard.download.clone())
        .unwrap_or(defaults.clone());
    let concurrency = if cfg.concurrency >= 1 {
        cfg.concurrency
    } else {
        defaults.concurrency
    };
    let connection_count = NonZeroU8::new(cfg.connection_count.max(1))
        .unwrap_or_else(|| NonZeroU8::new(defaults.connection_count.max(1)).unwrap());
    let chunk_mb = if cfg.chunk_size_mb >= 1 {
        cfg.chunk_size_mb
    } else {
        defaults.chunk_size_mb
    };
    let mut chunk_bytes = chunk_mb.saturating_mul(1024 * 1024);
    if chunk_bytes == 0 {
        chunk_bytes = 1024 * 1024;
    }
    let chunk_bytes = chunk_bytes.min(usize::MAX as u64) as usize;
    let chunk_size =
        NonZeroUsize::new(chunk_bytes).unwrap_or_else(|| NonZeroUsize::new(1024 * 1024).unwrap());
    let http_timeout_secs = if cfg.http_timeout_secs > 0 {
        cfg.http_timeout_secs
    } else {
        defaults.http_timeout_secs
    };
    let per_file_timeout_secs = if cfg.per_file_timeout_secs > 0 {
        cfg.per_file_timeout_secs
    } else {
        defaults.per_file_timeout_secs
    };
    let progress_tick_ms = if cfg.progress_tick_ms >= 50 {
        cfg.progress_tick_ms
    } else {
        defaults.progress_tick_ms
    };
    let progress_db_flush_secs = if cfg.progress_db_flush_secs > 0 {
        cfg.progress_db_flush_secs
    } else {
        defaults.progress_db_flush_secs
    };
    DownloadRuntimeConfig {
        concurrency,
        connection_count,
        chunk_size,
        http_timeout: Duration::from_secs(http_timeout_secs),
        per_file_timeout: Duration::from_secs(per_file_timeout_secs),
        max_get_retries: cfg.max_get_retries,
        max_download_retries: cfg.max_download_retries,
        progress_tick: Duration::from_millis(progress_tick_ms),
        progress_db_flush: Duration::from_secs(progress_db_flush_secs),
    }
}

fn hub_headers_compat() -> HeaderMap {
    let mut headers = HeaderMap::new();
    headers.insert(
        HeaderName::from_static("accept"),
        HeaderValue::from_static(
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
        ),
    );
    headers.insert(
        HeaderName::from_static("accept-encoding"),
        HeaderValue::from_static("gzip, deflate, br, zstd"),
    );
    headers.insert(
        HeaderName::from_static("accept-language"),
        HeaderValue::from_static("en-US,en;q=0.9"),
    );
    headers.insert(
        HeaderName::from_static("cookie"),
        HeaderValue::from_static("vamhubconsent=yes"),
    );
    headers.insert(
        HeaderName::from_static("dnt"),
        HeaderValue::from_static("1"),
    );
    headers.insert(
        HeaderName::from_static("sec-ch-ua"),
        HeaderValue::from_static(
            "\"Not)A;Brand\";v=\"99\", \"Microsoft Edge\";v=\"127\", \"Chromium\";v=\"127\"",
        ),
    );
    headers.insert(
        HeaderName::from_static("sec-ch-ua-mobile"),
        HeaderValue::from_static("?0"),
    );
    headers.insert(
        HeaderName::from_static("sec-ch-ua-platform"),
        HeaderValue::from_static("\"Windows\""),
    );
    headers.insert(
        HeaderName::from_static("sec-fetch-dest"),
        HeaderValue::from_static("document"),
    );
    headers.insert(
        HeaderName::from_static("sec-fetch-mode"),
        HeaderValue::from_static("navigate"),
    );
    headers.insert(
        HeaderName::from_static("sec-fetch-site"),
        HeaderValue::from_static("none"),
    );
    headers.insert(
        HeaderName::from_static("sec-fetch-user"),
        HeaderValue::from_static("?1"),
    );
    headers.insert(
        HeaderName::from_static("upgrade-insecure-requests"),
        HeaderValue::from_static("1"),
    );
    headers.insert(
        HeaderName::from_static("user-agent"),
        HeaderValue::from_static(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36 Edg/127.0.0.0",
        ),
    );
    headers
}

async fn update_status(
    db_pool: &SqlitePool,
    id: i64,
    status: &str,
    error: Option<String>,
) -> Result<(), String> {
    let now = now_ts();
    sqlx::query("UPDATE downloads SET status = ?1, error = ?2, updated_at = ?3 WHERE id = ?4")
        .bind(status)
        .bind(error)
        .bind(now)
        .bind(id)
        .execute(db_pool)
        .await
        .map_err(|err| err.to_string())?;
    Ok(())
}

async fn update_progress(
    db_pool: &SqlitePool,
    id: i64,
    downloaded: u64,
    total: Option<u64>,
    speed: u64,
) -> Result<(), String> {
    let now = now_ts();
    sqlx::query(
        "UPDATE downloads SET downloaded_bytes = ?1, total_bytes = ?2, speed_bytes = ?3, updated_at = ?4 WHERE id = ?5",
    )
    .bind(downloaded as i64)
    .bind(total.map(|v| v as i64))
    .bind(speed as i64)
    .bind(now)
    .bind(id)
    .execute(db_pool)
    .await
    .map_err(|err| err.to_string())?;
    Ok(())
}

async fn update_total_bytes(db_pool: &SqlitePool, id: i64, total: u64) -> Result<(), String> {
    let now = now_ts();
    sqlx::query("UPDATE downloads SET total_bytes = ?1, updated_at = ?2 WHERE id = ?3")
        .bind(total as i64)
        .bind(now)
        .bind(id)
        .execute(db_pool)
        .await
        .map_err(|err| err.to_string())?;
    Ok(())
}

async fn update_paths(
    db_pool: &SqlitePool,
    id: i64,
    save_path: &Path,
    temp_path: &Path,
) -> Result<(), String> {
    let now = now_ts();
    sqlx::query(
        "UPDATE downloads SET save_path = ?1, temp_path = ?2, updated_at = ?3 WHERE id = ?4",
    )
    .bind(save_path.to_string_lossy().to_string())
    .bind(temp_path.to_string_lossy().to_string())
    .bind(now)
    .bind(id)
    .execute(db_pool)
    .await
    .map_err(|err| err.to_string())?;
    Ok(())
}

fn delete_file(path: &str) -> Result<(), String> {
    let path = PathBuf::from(path);
    if !path.exists() {
        return Ok(());
    }
    std::fs::remove_file(&path).map_err(|err| err.to_string())
}

fn now_ts() -> i64 {
    chrono::Local::now().timestamp()
}
