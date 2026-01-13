use crate::app::data_dir;
use crate::app::AppState;
use crate::infra::paths::config_paths;
use crate::jobs::job_channel::JobReporter;
use serde::{Deserialize, Serialize};
use serde_bencode::value::Value as BencodeValue;
use serde_json::Value;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::fs;
use tokio::process::Command;

#[derive(Deserialize)]
pub struct TorrentDownloadArgs {
    pub items: Vec<TorrentDownloadItem>,
}

#[derive(Deserialize)]
pub struct TorrentDownloadItem {
    pub var_name: String,
    pub torrents: Vec<String>,
}

#[derive(Serialize)]
pub struct TorrentDownloadResult {
    pub downloaded: usize,
    pub skipped: usize,
    pub missing: Vec<String>,
    pub failed: Vec<String>,
}

#[derive(Clone, Debug)]
struct TorrentFileEntry {
    index: usize,
    relative_path: PathBuf,
    file_name: String,
}

#[derive(Clone, Debug)]
struct TorrentMeta {
    files: Vec<TorrentFileEntry>,
}

#[derive(Clone, Debug)]
struct ResolvedEntry {
    var_name: String,
    torrent_name: String,
    entry: TorrentFileEntry,
}

pub async fn run_torrent_download_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    torrent_download_async(&state, &reporter, args).await
}

async fn torrent_download_async(
    state: &AppState,
    reporter: &JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    let args = args.ok_or_else(|| "torrent_download args required".to_string())?;
    let args: TorrentDownloadArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
    if args.items.is_empty() {
        return Err("torrent_download items required".to_string());
    }

    let aria2_path = data_dir().join("aria2c.exe");
    if !tokio::fs::try_exists(&aria2_path).await.unwrap_or(false) {
        return Err(format!("aria2c.exe not found: {}", aria2_path.display()));
    }

    let (varspath, _) = config_paths(state)?;
    let temp_dir = torrent_download_dir();
    fs::create_dir_all(&temp_dir).await.map_err(|err| err.to_string())?;

    let torrents_root = data_dir().join("links").join("torrents");
    if !tokio::fs::try_exists(&torrents_root).await.unwrap_or(false) {
        return Err(format!("torrents directory missing: {}", torrents_root.display()));
    }

    let mut requested: HashMap<String, Vec<String>> = HashMap::new();
    for item in args.items {
        let name = item.var_name.trim().to_string();
        if name.is_empty() {
            continue;
        }
        let mut list = Vec::new();
        for torrent in item.torrents {
            let trimmed = torrent.trim();
            if trimmed.is_empty() {
                continue;
            }
            list.push(trimmed.to_string());
        }
        if list.is_empty() {
            continue;
        }
        requested.insert(name, list);
    }

    if requested.is_empty() {
        return Err("torrent_download items required".to_string());
    }

    let mut meta_cache: HashMap<String, TorrentMeta> = HashMap::new();
    let mut resolved: Vec<ResolvedEntry> = Vec::new();
    let mut missing = Vec::new();

    for (var_name, torrents) in &requested {
        let target = format!("{}.var", var_name);
        let mut found = None;
        for torrent_name in torrents {
            let meta = match meta_cache.get(torrent_name) {
                Some(existing) => existing.clone(),
                None => {
                    let path = torrents_root.join(torrent_name);
                    let meta = parse_torrent(&path)?;
                    meta_cache.insert(torrent_name.to_string(), meta.clone());
                    meta
                }
            };

            if let Some(entry) = meta.files.iter().find(|entry| {
                entry.file_name.eq_ignore_ascii_case(&target)
            }) {
                found = Some(ResolvedEntry {
                    var_name: var_name.to_string(),
                    torrent_name: torrent_name.to_string(),
                    entry: entry.clone(),
                });
                break;
            }
        }
        if let Some(entry) = found {
            resolved.push(entry);
        } else {
            missing.push(var_name.to_string());
        }
    }

    if resolved.is_empty() {
        return Err("no matching torrent files found".to_string());
    }

    let mut by_torrent: HashMap<String, Vec<ResolvedEntry>> = HashMap::new();
    for entry in resolved {
        by_torrent
            .entry(entry.torrent_name.clone())
            .or_insert_with(Vec::new)
            .push(entry);
    }

    let temp_torrent_dir = temp_dir.join(".torrents");
    fs::create_dir_all(&temp_torrent_dir).await.map_err(|err| err.to_string())?;

    let total_targets: usize = by_torrent.values().map(|v| v.len()).sum();
    let mut completed_targets = 0usize;
    let mut downloaded = 0usize;
    let mut skipped = 0usize;
    let mut failed = Vec::new();

    // Spawn parallel downloads
    let mut handles = Vec::new();

    for (torrent_name, entries) in by_torrent {
        // Check if already downloading
        if state.torrent_tracker.is_active(&torrent_name) {
            reporter.log(format!(
                "Skipping {}: already downloading in another job",
                torrent_name
            ));
            skipped += entries.len();
            completed_targets += entries.len();
            continue;
        }

        let torrent_path = torrents_root.join(&torrent_name);
        if !tokio::fs::try_exists(&torrent_path).await.unwrap_or(false) {
            failed.push(torrent_name);
            continue;
        }

        // Register torrent download
        let var_names: Vec<String> = entries.iter()
            .map(|e| e.var_name.clone())
            .collect();
        state.torrent_tracker.register(torrent_name.clone(), var_names);

        reporter.log(format!(
            "aria2 start: {} target(s) from {}",
            entries.len(),
            torrent_name
        ));

        // Clone all necessary data for the task
        let aria2_path_clone = aria2_path.clone();
        let temp_dir_clone = temp_dir.clone();
        let temp_torrent_dir_clone = temp_torrent_dir.clone();
        let varspath_clone = varspath.clone();
        let state_clone = state.clone();

        let handle = tokio::spawn(async move {
            let indices = entries
                .iter()
                .map(|entry| entry.entry.index.to_string())
                .collect::<Vec<_>>()
                .join(",");

            let temp_torrent_path =
                temp_torrent_dir_clone.join(unique_torrent_name(&torrent_name));

            if let Err(e) = fs::copy(&torrent_path, &temp_torrent_path).await {
                return Err((torrent_name, vec![], format!("Copy failed: {}", e)));
            }

            let status = Command::new(&aria2_path_clone)
                .arg("--continue=true")
                .arg("--allow-overwrite=true")
                .arg("--check-integrity=true")
                .arg("--file-allocation=none")
                .arg("--seed-time=0")
                .arg("--seed-ratio=0.0")
                .arg("--bt-stop-timeout=0")
                .arg(format!(
                    "--stop-with-process={}",
                    std::process::id()
                ))
                .arg("--dir")
                .arg(&temp_dir_clone)
                .arg(format!("--select-file={}", indices))
                .arg(&temp_torrent_path)
                .status()
                .await;

            let _ = fs::remove_file(&temp_torrent_path).await;

            let status = match status {
                Ok(s) => s,
                Err(e) => return Err((torrent_name, vec![], format!("aria2 failed: {}", e))),
            };

            if !status.success() {
                return Err((torrent_name, vec![], "aria2 returned error".to_string()));
            }

            // Move files to final location
            let mut moved = Vec::new();
            let mut move_errors = Vec::new();
            let mut skipped_count = 0usize;

            for entry in entries {
                let src = temp_dir_clone.join(&entry.entry.relative_path);
                let dest = varspath_clone.join(format!("{}.var", entry.var_name));

                if tokio::fs::try_exists(&dest).await.unwrap_or(false) {
                    let _ = fs::remove_file(&src).await;
                    skipped_count += 1;
                    continue;
                }

                if !tokio::fs::try_exists(&src).await.unwrap_or(false) {
                    move_errors.push(entry.var_name.clone());
                    continue;
                }

                if let Some(parent) = dest.parent() {
                    let _ = fs::create_dir_all(parent).await;
                }

                if let Err(_) = fs::rename(&src, &dest).await {
                    move_errors.push(entry.var_name.clone());
                    continue;
                }

                moved.push(entry.var_name);
            }

            // Unregister from tracker
            state_clone.torrent_tracker.unregister(&torrent_name);

            Ok::<_, (String, Vec<String>, String)>((torrent_name, moved, move_errors, skipped_count))
        });

        handles.push(handle);
    }

    // Wait for all downloads to complete
    for handle in handles {
        match handle.await {
            Ok(Ok((torrent_name, moved, move_errors, skipped_count))) => {
                downloaded += moved.len();
                skipped += skipped_count;
                failed.extend(move_errors);
                completed_targets += moved.len() + failed.len() + skipped_count;
                reporter.log(format!("aria2 done: {}", torrent_name));
            }
            Ok(Err((torrent_name, _, error))) => {
                reporter.log(format!("aria2 failed for {}: {}", torrent_name, error));
                failed.push(torrent_name);
            }
            Err(e) => {
                reporter.log(format!("Task join error: {}", e));
            }
        }

        // Update progress after each torrent completes
        let progress = if total_targets == 0 {
            100
        } else {
            ((completed_targets * 100) / total_targets).min(100) as u8
        };
        reporter.progress(progress);
    }

    if !failed.is_empty() {
        reporter.log(format!(
            "torrent download failures: {}",
            failed.join(", ")
        ));
    }

    reporter.set_result(
        serde_json::to_value(TorrentDownloadResult {
            downloaded,
            skipped,
            missing,
            failed,
        })
        .map_err(|err| err.to_string())?,
    );

    Ok(())
}

fn parse_torrent(path: &Path) -> Result<TorrentMeta, String> {
    let data = std::fs::read(path).map_err(|err| err.to_string())?;
    let value: BencodeValue =
        serde_bencode::from_bytes(&data).map_err(|err| err.to_string())?;
    let info = match value {
        BencodeValue::Dict(map) => dict_get(&map, "info")
            .ok_or_else(|| format!("torrent missing info: {}", path.display()))?
            .clone(),
        _ => return Err(format!("invalid torrent root: {}", path.display())),
    };
    let info_map = match info {
        BencodeValue::Dict(map) => map,
        _ => return Err(format!("invalid torrent info: {}", path.display())),
    };
    let name_value = dict_get(&info_map, "name.utf-8")
        .or_else(|| dict_get(&info_map, "name"))
        .ok_or_else(|| format!("torrent missing name: {}", path.display()))?;
    let name = bencode_str(name_value)
        .ok_or_else(|| format!("torrent name invalid: {}", path.display()))?;

    let mut files = Vec::new();
    if let Some(file_list) = dict_get(&info_map, "files") {
        let file_list = match file_list {
            BencodeValue::List(list) => list,
            _ => return Err(format!("torrent files invalid: {}", path.display())),
        };
        for (idx, file) in file_list.iter().enumerate() {
            let file_map = match file {
                BencodeValue::Dict(map) => map,
                _ => return Err(format!("torrent file entry invalid: {}", path.display())),
            };
            let parts = dict_get(file_map, "path.utf-8")
                .or_else(|| dict_get(file_map, "path"))
                .ok_or_else(|| format!("torrent file path missing: {}", path.display()))?;
            let parts = match parts {
                BencodeValue::List(list) => list,
                _ => return Err(format!("torrent path invalid: {}", path.display())),
            };
            let mut relative = PathBuf::from(&name);
            let mut file_name = None;
            for part in parts {
                let text = bencode_str(part)
                    .ok_or_else(|| format!("torrent path part invalid: {}", path.display()))?;
                relative.push(&text);
                file_name = Some(text);
            }
            let file_name = file_name.ok_or_else(|| {
                format!("torrent path empty: {}", path.display())
            })?;
            files.push(TorrentFileEntry {
                index: idx + 1,
                relative_path: relative,
                file_name,
            });
        }
    } else {
        files.push(TorrentFileEntry {
            index: 1,
            relative_path: PathBuf::from(&name),
            file_name: name.clone(),
        });
    }

    Ok(TorrentMeta { files })
}

fn dict_get<'a>(
    map: &'a HashMap<Vec<u8>, BencodeValue>,
    key: &str,
) -> Option<&'a BencodeValue> {
    map.get(key.as_bytes())
}

fn bencode_str(value: &BencodeValue) -> Option<String> {
    match value {
        BencodeValue::Bytes(bytes) => {
            Some(String::from_utf8_lossy(bytes).to_string())
        }
        _ => None,
    }
}

fn unique_torrent_name(original: &str) -> String {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0);
    let base = Path::new(original)
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or(original);
    format!("{}_{}", now, base)
}

fn torrent_download_dir() -> PathBuf {
    use crate::app::app_root;
    app_root().join("down")
}
