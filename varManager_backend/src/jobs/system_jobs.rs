use crate::jobs::job_channel::JobReporter;
use crate::app::AppState;
use crate::infra::system_ops;
use crate::util;
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Deserialize)]
struct OpenUrlArgs {
    url: String,
}

#[derive(Serialize)]
struct RescanResult {
    rescan: bool,
}

#[derive(Serialize)]
struct StartResult {
    started: bool,
}

pub async fn run_vam_start_job(
    state: AppState,
    reporter: JobReporter,
    _args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        vam_start_blocking(&state, &reporter)
    })
    .await
    .map_err(|err| err.to_string())?
}

fn vam_start_blocking(state: &AppState, reporter: &JobReporter) -> Result<(), String> {
    system_ops::start_vam(state)?;
    reporter.set_result(serde_json::to_value(StartResult { started: true }).map_err(|e| e.to_string())?);
    Ok(())
}

pub async fn run_rescan_packages_job(
    state: AppState,
    reporter: JobReporter,
    _args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        rescan_packages_blocking(&state, &reporter)
    })
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
    tokio::task::spawn_blocking(move || {
        open_url_blocking(&reporter, args)
    })
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
