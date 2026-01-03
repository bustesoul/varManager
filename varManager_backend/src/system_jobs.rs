use crate::{job_log, job_set_result, system_ops, util, AppState};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use tokio::runtime::Handle;

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
    id: u64,
    _args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        system_ops::start_vam(&reporter.state)?;
        reporter.set_result(serde_json::to_value(StartResult { started: true }).map_err(|e| e.to_string())?);
        Ok(())
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_rescan_packages_job(
    state: AppState,
    id: u64,
    _args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        let rescan = system_ops::rescan_packages(&reporter.state)?;
        reporter.set_result(serde_json::to_value(RescanResult { rescan }).map_err(|e| e.to_string())?);
        Ok(())
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_open_url_job(
    state: AppState,
    id: u64,
    args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        let args = args.ok_or_else(|| "open_url args required".to_string())?;
        let args: OpenUrlArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
        util::open_url(&args.url)?;
        reporter.log("open_url completed");
        Ok(())
    })
    .await
    .map_err(|err| err.to_string())?
}

struct JobReporter {
    state: AppState,
    id: u64,
    handle: Handle,
}

impl JobReporter {
    fn new(state: AppState, id: u64, handle: Handle) -> Self {
        Self { state, id, handle }
    }

    fn log(&self, msg: impl Into<String>) {
        let msg = msg.into();
        let _ = self.handle.block_on(job_log(&self.state, self.id, msg));
    }

    fn set_result(&self, result: Value) {
        let _ = self.handle.block_on(job_set_result(&self.state, self.id, result));
    }
}
