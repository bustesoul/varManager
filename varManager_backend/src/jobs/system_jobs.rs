use crate::app::data_dir;
use crate::app::AppState;
use crate::infra::system_ops;
use crate::jobs::job_channel::JobReporter;
use crate::util;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::path::{Path, PathBuf};

#[derive(Deserialize)]
struct OpenUrlArgs {
    url: String,
}

#[derive(Deserialize)]
struct OpenTorrentsArgs {
    torrents: Vec<String>,
}

#[derive(Serialize)]
struct RescanResult {
    rescan: bool,
}

#[derive(Serialize)]
struct StartResult {
    started: bool,
}

#[derive(Serialize)]
struct OpenTorrentsResult {
    opened: usize,
    missing: Vec<String>,
}

pub async fn run_vam_start_job(
    state: AppState,
    reporter: JobReporter,
    _args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || vam_start_blocking(&state, &reporter))
        .await
        .map_err(|err| err.to_string())?
}

fn vam_start_blocking(state: &AppState, reporter: &JobReporter) -> Result<(), String> {
    system_ops::start_vam(state)?;
    reporter.set_result(
        serde_json::to_value(StartResult { started: true }).map_err(|e| e.to_string())?,
    );
    Ok(())
}

pub async fn run_rescan_packages_job(
    state: AppState,
    reporter: JobReporter,
    _args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || rescan_packages_blocking(&state, &reporter))
        .await
        .map_err(|err| err.to_string())?
}

fn rescan_packages_blocking(state: &AppState, reporter: &JobReporter) -> Result<(), String> {
    let rescan = system_ops::rescan_packages(state)?;
    reporter.set_result(serde_json::to_value(RescanResult { rescan }).map_err(|e| e.to_string())?);
    Ok(())
}

pub async fn run_open_url_job(
    _state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || open_url_blocking(&reporter, args))
        .await
        .map_err(|err| err.to_string())?
}

pub async fn run_open_torrents_job(
    _state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || open_torrents_blocking(&reporter, args))
        .await
        .map_err(|err| err.to_string())?
}

fn open_url_blocking(reporter: &JobReporter, args: Option<Value>) -> Result<(), String> {
    let args = args.ok_or_else(|| "open_url args required".to_string())?;
    let args: OpenUrlArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
    util::open_url(&args.url)?;
    reporter.log("open_url completed");
    Ok(())
}

fn open_torrents_blocking(reporter: &JobReporter, args: Option<Value>) -> Result<(), String> {
    let args = args.ok_or_else(|| "open_torrents args required".to_string())?;
    let args: OpenTorrentsArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
    if args.torrents.is_empty() {
        return Err("torrents list required".to_string());
    }

    let torrents_root = data_dir().join("links").join("torrents");
    let mut opened = 0usize;
    let mut missing = Vec::new();

    for raw in args.torrents {
        let trimmed = raw.trim();
        if trimmed.is_empty() {
            continue;
        }
        let name = Path::new(trimmed)
            .file_name()
            .and_then(|value| value.to_str())
            .unwrap_or("")
            .trim();
        if name.is_empty() {
            continue;
        }
        let path = if Path::new(trimmed).is_absolute() {
            PathBuf::from(trimmed)
        } else {
            torrents_root.join(name)
        };
        if !path.exists() {
            missing.push(name.to_string());
            continue;
        }
        util::open_url(&path.to_string_lossy())?;
        opened += 1;
    }

    if opened == 0 {
        return Err("no torrents opened".to_string());
    }

    if !missing.is_empty() {
        reporter.log(format!("missing torrents: {}", missing.join(", ")));
    }

    reporter.set_result(
        serde_json::to_value(OpenTorrentsResult { opened, missing })
            .map_err(|err| err.to_string())?,
    );
    Ok(())
}
