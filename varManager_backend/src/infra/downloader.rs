use crate::app::{exe_dir, AppState};
use crate::infra::paths::addon_packages_dir;
use crate::jobs::job_channel::JobReporter;
use http_downloader::{
    speed_limiter::DownloadSpeedLimiterExtension,
    speed_tracker::DownloadSpeedTrackerExtension,
    status_tracker::DownloadStatusTrackerExtension,
    DownloadingEndCause, HttpDownloaderBuilder,
};
use percent_encoding::percent_decode;
use regex::Regex;
use reqwest::{header, Client, StatusCode};
use serde::Serialize;
use std::collections::HashSet;
use std::fs;
use std::num::{NonZeroU8, NonZeroUsize};
use std::path::{Path, PathBuf};
use std::sync::{
    atomic::{AtomicUsize, Ordering},
    Arc,
};
use std::time::Duration;
use tokio::sync::Semaphore;
use tokio::time::{interval, timeout, Instant};
use url::Url;

const DEFAULT_DOWNLOAD_CONCURRENCY: usize = 3;
const MAX_FAILURE_SAMPLES: usize = 5;
const PROGRESS_TICK_SECS: u64 = 2;
const LOG_STEP_DIVISOR: usize = 10;
const PER_FILE_TIMEOUT_SECS: u64 = 300;
const HTTP_TIMEOUT_SECS: u64 = 30;
const MAX_GET_RETRIES: u8 = 3;
const MAX_DOWNLOAD_RETRIES: u8 = 3;

#[derive(Debug, Serialize, Clone)]
pub struct DownloadFailure {
    pub url: String,
    pub error: String,
}

#[derive(Debug, Serialize, Clone)]
pub struct DownloadSummary {
    pub total: usize,
    pub success: usize,
    pub failed: usize,
    pub failed_samples: Vec<DownloadFailure>,
}

pub async fn download_urls(
    state: &AppState,
    reporter: &JobReporter,
    urls: &[String],
) -> Result<DownloadSummary, String> {
    let urls = normalize_urls(urls);
    if urls.is_empty() {
        return Err("no download urls provided".to_string());
    }

    let save_dir = resolve_download_save_path(state)?;
    ensure_dir(&save_dir)?;

    let client = Arc::new(
        Client::builder()
            .redirect(reqwest::redirect::Policy::none())
            .timeout(Duration::from_secs(HTTP_TIMEOUT_SECS))
            .build()
            .map_err(|err| err.to_string())?,
    );

    let total = urls.len();
    reporter.log(format!("Hub download start: {} urls", total));
    reporter.progress(1);

    let completed = Arc::new(AtomicUsize::new(0));
    let failed = Arc::new(AtomicUsize::new(0));

    let progress_task = spawn_progress_task(
        reporter.clone(),
        total,
        Arc::clone(&completed),
        Arc::clone(&failed),
    );

    let concurrency = DEFAULT_DOWNLOAD_CONCURRENCY.min(total).max(1);
    let semaphore = Arc::new(Semaphore::new(concurrency));

    let mut handles = Vec::with_capacity(total);
    for url in urls {
        let permit = semaphore
            .clone()
            .acquire_owned()
            .await
            .map_err(|err| err.to_string())?;
        let client = Arc::clone(&client);
        let save_dir = save_dir.clone();
        let url_clone = url.clone();
        let completed = Arc::clone(&completed);
        let failed = Arc::clone(&failed);
        handles.push(tokio::spawn(async move {
            let result = download_one(url_clone.clone(), save_dir, client).await;
            drop(permit);
            if result.is_err() {
                failed.fetch_add(1, Ordering::Relaxed);
            }
            completed.fetch_add(1, Ordering::Relaxed);
            (url_clone, result)
        }));
    }

    let mut success = 0usize;
    let mut failures = Vec::new();
    for handle in handles {
        match handle.await {
            Ok((_url, Ok(_filename))) => {
                success += 1;
            }
            Ok((url, Err(err))) => {
                if failures.len() < MAX_FAILURE_SAMPLES {
                    failures.push(DownloadFailure { url, error: err });
                }
            }
            Err(err) => {
                if failures.len() < MAX_FAILURE_SAMPLES {
                    failures.push(DownloadFailure {
                        url: "<join_error>".to_string(),
                        error: err.to_string(),
                    });
                }
            }
        }
    }

    progress_task.abort();

    let failed_count = total.saturating_sub(success);
    let summary = DownloadSummary {
        total,
        success,
        failed: failed_count,
        failed_samples: failures.clone(),
    };

    reporter.progress(100);
    reporter.log(format!(
        "Hub download done: success {} failed {}",
        summary.success, summary.failed
    ));
    if summary.failed > 0 && !failures.is_empty() {
        for failure in failures {
            reporter.log(format!("Failure sample: {} -> {}", failure.url, failure.error));
        }
    }

    Ok(summary)
}

fn normalize_urls(urls: &[String]) -> Vec<String> {
    let mut seen = HashSet::new();
    let mut normalized = Vec::new();
    for raw in urls {
        let trimmed = raw.trim();
        if trimmed.is_empty() {
            continue;
        }
        if !trimmed.starts_with("http://") && !trimmed.starts_with("https://") {
            continue;
        }
        if seen.insert(trimmed.to_string()) {
            normalized.push(trimmed.to_string());
        }
    }
    normalized
}

fn ensure_dir(path: &Path) -> Result<(), String> {
    if path.exists() {
        if path.is_dir() {
            return Ok(());
        }
        return Err(format!("save path exists but is not a directory: {}", path.display()));
    }
    fs::create_dir_all(path).map_err(|err| err.to_string())
}

fn spawn_progress_task(
    reporter: JobReporter,
    total: usize,
    completed: Arc<AtomicUsize>,
    failed: Arc<AtomicUsize>,
) -> tokio::task::JoinHandle<()> {
    let log_step = total.div_ceil(LOG_STEP_DIVISOR);
    tokio::spawn(async move {
        let mut ticker = interval(Duration::from_secs(PROGRESS_TICK_SECS));
        let mut next_log_at = log_step.max(1);
        let mut last_log_time = Instant::now();
        loop {
            ticker.tick().await;
            let done = completed.load(Ordering::Relaxed);
            let failed_count = failed.load(Ordering::Relaxed);
            if total > 0 {
                let progress = ((done * 100) / total).min(99) as u8;
                reporter.progress(progress);
            }
            if done >= total {
                break;
            }
            if done >= next_log_at && last_log_time.elapsed() >= Duration::from_secs(5) {
                reporter.log(format!(
                    "Download progress: {}/{} (failed {})",
                    done, total, failed_count
                ));
                next_log_at = next_log_at.saturating_add(log_step.max(1));
                last_log_time = Instant::now();
            }
        }
    })
}

async fn download_one(
    url_to_download: String,
    save_dir: PathBuf,
    client: Arc<Client>,
) -> Result<String, String> {
    let final_url = resolve_final_url(&url_to_download, &client).await?;
    let filename = resolve_filename(&final_url, &client).await?;
    let download_url_obj = Url::parse(&final_url).map_err(|err| err.to_string())?;

    let mut attempt: u8 = 0;
    loop {
        attempt += 1;
        let result = timeout(
            Duration::from_secs(PER_FILE_TIMEOUT_SECS),
            async {
                let (mut downloader, (_status_state, _speed_state, _speed_limiter, ..)) =
                    HttpDownloaderBuilder::new(download_url_obj.clone(), save_dir.clone())
                        .chunk_size(NonZeroUsize::new(1024 * 1024 * 10).unwrap())
                        .download_connection_count(NonZeroU8::new(4).unwrap())
                        .build((
                            DownloadStatusTrackerExtension { log: false },
                            DownloadSpeedTrackerExtension { log: false },
                            DownloadSpeedLimiterExtension::new(None),
                        ));

                let download_future = downloader
                    .prepare_download()
                    .map_err(|err| err.to_string())?;
                let dec = download_future.await.map_err(|err| err.to_string())?;
                Ok::<DownloadingEndCause, String>(dec)
            },
        )
        .await;

        match result {
            Ok(Ok(_dec)) => break,
            Ok(Err(err)) => {
                if attempt <= MAX_DOWNLOAD_RETRIES && is_retryable_error(&err) {
                    tokio::time::sleep(Duration::from_secs(2)).await;
                    continue;
                }
                return Err(err);
            }
            Err(_) => {
                if attempt <= MAX_DOWNLOAD_RETRIES {
                    tokio::time::sleep(Duration::from_secs(2)).await;
                    continue;
                }
                return Err(format!(
                    "download timed out after {} attempts",
                    attempt
                ));
            }
        }
    }

    finalize_download(&download_url_obj, &save_dir, &filename)?;
    Ok(filename)
}

async fn resolve_final_url(url: &str, client: &Client) -> Result<String, String> {
    if url.ends_with(".data") {
        return Ok(url.to_string());
    }

    let mut attempt: u8 = 0;
    loop {
        attempt += 1;
        let result = async {
            let response = client
                .get(url)
                .headers(hub_headers())
                .send()
                .await
                .map_err(|err| err.to_string())?;
            if response.status() == StatusCode::SEE_OTHER {
                if let Some(location) = response.headers().get(header::LOCATION) {
                    let location_str = location.to_str().map_err(|err| err.to_string())?;
                    return Ok(location_str.to_string());
                }
            }
            if !response.status().is_success() {
                let status = response.status();
                let body = response.text().await.unwrap_or_default();
                return Err(format!("GET {} failed with status {}: {}", url, status, body));
            }
            Ok(url.to_string())
        }
        .await;

        match result {
            Ok(url) => return Ok(url),
            Err(err) => {
                if attempt <= MAX_GET_RETRIES && is_retryable_error(&err) {
                    tokio::time::sleep(Duration::from_secs(2)).await;
                    continue;
                }
                return Err(err);
            }
        }
    }
}

async fn resolve_filename(url: &str, client: &Client) -> Result<String, String> {
    let response = client
        .head(url)
        .headers(hub_headers())
        .send()
        .await
        .map_err(|err| err.to_string())?;

    let content_disposition = response.headers().get(header::CONTENT_DISPOSITION);
    let mut extracted = if let Some(cd_val) = content_disposition {
        let cd_str = percent_decode(cd_val.as_bytes())
            .decode_utf8()
            .unwrap_or_else(|_| "".into());
        let re = Regex::new(r#"filename(?:\*)?=(?:"([^"]+)"|([^;\s]+))(?:;.*)?$"#)
            .map_err(|err| err.to_string())?;
        if let Some(captures) = re.captures(&cd_str) {
            captures
                .get(1)
                .or(captures.get(2))
                .map(|m| m.as_str().to_string())
                .unwrap_or_else(|| "default_filename".to_string())
        } else {
            Path::new(url)
                .file_name()
                .map(|name| name.to_string_lossy().into_owned())
                .unwrap_or_else(|| "default_filename".to_string())
        }
    } else {
        Path::new(url)
            .file_name()
            .map(|name| name.to_string_lossy().into_owned())
            .unwrap_or_else(|| "default_filename".to_string())
    };

    extracted = extracted.trim_end_matches(';').to_string();
    let invalid_chars = ['\\', '/', ':', '*', '?', '"', '<', '>', '|'];
    for c in invalid_chars.iter() {
        extracted = extracted.replace(*c, "_");
    }
    if extracted.is_empty() {
        extracted = "default_filename".to_string();
    }
    Ok(extracted)
}

fn finalize_download(url: &Url, save_dir: &Path, filename: &str) -> Result<(), String> {
    let downloaded_file_path = save_dir.join(
        url.path_segments()
            .and_then(|mut s| s.next_back())
            .unwrap_or("unknown_temp_file"),
    );
    let new_file_path = save_dir.join(filename);

    if downloaded_file_path == new_file_path {
        verify_file_size(&new_file_path)?;
        return Ok(());
    }

    if downloaded_file_path.exists() {
        verify_file_size(&downloaded_file_path)?;
        fs::rename(&downloaded_file_path, &new_file_path).map_err(|err| err.to_string())?;
        return Ok(());
    }

    if new_file_path.exists() {
        verify_file_size(&new_file_path)?;
        return Ok(());
    }

    Err(format!(
        "final file not found after download: {}",
        new_file_path.display()
    ))
}

fn verify_file_size(path: &Path) -> Result<(), String> {
    let metadata = fs::metadata(path).map_err(|err| err.to_string())?;
    if metadata.len() == 0 {
        return Err(format!("downloaded file is empty: {}", path.display()));
    }
    Ok(())
}

fn is_retryable_error(err: &str) -> bool {
    let lower = err.to_lowercase();
    lower.contains("error sending request")
        || lower.contains("connection")
        || lower.contains("timeout")
        || lower.contains("dns")
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

fn resolve_download_save_path(state: &AppState) -> Result<PathBuf, String> {
    let cfg = state
        .config
        .read()
        .map_err(|_| "config lock poisoned".to_string())?;
    if let Some(path) = cfg
        .downloader_save_path
        .as_ref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
    {
        let candidate = PathBuf::from(path);
        if candidate.is_absolute() {
            return Ok(candidate);
        }
        if let Some(vampath) = cfg.vampath.as_ref() {
            return Ok(PathBuf::from(vampath).join(candidate));
        }
        return Ok(exe_dir().join(candidate));
    }

    let vampath = cfg
        .vampath
        .as_ref()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .map(PathBuf::from)
        .ok_or_else(|| "vampath is required in config.json".to_string())?;
    Ok(addon_packages_dir(&vampath))
}
