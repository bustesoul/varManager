use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{
    collections::{HashMap, VecDeque},
    net::SocketAddr,
    path::PathBuf,
    sync::{
        atomic::{AtomicU64, Ordering},
        Arc,
    },
};
use tokio::sync::{oneshot, Mutex, Semaphore};
use tracing_subscriber::EnvFilter;

mod db;
mod deps_jobs;
mod hub;
mod links;
mod missing_deps;
mod packswitch;
mod paths;
mod preview_jobs;
mod scenes;
mod stale_jobs;
mod system_jobs;
mod system_ops;
mod update_db;
mod var_logic;
mod vars_misc;
mod vars_jobs;
mod winfs;

const LOG_CAPACITY: usize = 1000;

#[derive(Clone, Serialize, Deserialize)]
struct Config {
    listen_host: String,
    listen_port: u16,
    log_level: String,
    job_concurrency: usize,
    #[serde(default)]
    varspath: Option<String>,
    #[serde(default)]
    vampath: Option<String>,
    #[serde(default)]
    vam_exec: Option<String>,
    #[serde(default)]
    downloader_path: Option<String>,
    #[serde(default)]
    downloader_save_path: Option<String>,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            listen_host: "127.0.0.1".to_string(),
            listen_port: 57123,
            log_level: "info".to_string(),
            job_concurrency: 2,
            varspath: None,
            vampath: None,
            vam_exec: Some("VaM (Desktop Mode).bat".to_string()),
            downloader_path: Some("plugin\\vam_downloader.exe".to_string()),
            downloader_save_path: None,
        }
    }
}

#[derive(Clone)]
pub(crate) struct AppState {
    config: Arc<Config>,
    shutdown_tx: Arc<Mutex<Option<oneshot::Sender<()>>>>,
    jobs: Arc<Mutex<HashMap<u64, Job>>>,
    job_counter: Arc<AtomicU64>,
    job_semaphore: Arc<Semaphore>,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "snake_case")]
enum JobStatus {
    Queued,
    Running,
    Succeeded,
    Failed,
}

#[derive(Clone, Debug)]
struct Job {
    id: u64,
    kind: String,
    status: JobStatus,
    progress: u8,
    message: String,
    error: Option<String>,
    logs: VecDeque<String>,
    log_offset: usize,
    result: Option<Value>,
}

impl Job {
    fn new(id: u64, kind: String) -> Self {
        Self {
            id,
            kind,
            status: JobStatus::Queued,
            progress: 0,
            message: String::new(),
            error: None,
            logs: VecDeque::new(),
            log_offset: 0,
            result: None,
        }
    }
}

#[derive(Serialize)]
struct JobView {
    id: u64,
    kind: String,
    status: JobStatus,
    progress: u8,
    message: String,
    error: Option<String>,
    log_offset: usize,
    log_count: usize,
    result_available: bool,
}

impl From<&Job> for JobView {
    fn from(job: &Job) -> Self {
        Self {
            id: job.id,
            kind: job.kind.clone(),
            status: job.status.clone(),
            progress: job.progress,
            message: job.message.clone(),
            error: job.error.clone(),
            log_offset: job.log_offset,
            log_count: job.logs.len(),
            result_available: job.result.is_some(),
        }
    }
}

#[derive(Deserialize)]
struct StartJobRequest {
    kind: String,
    #[serde(default)]
    args: Option<Value>,
}

#[derive(Serialize)]
struct StartJobResponse {
    id: u64,
    status: JobStatus,
}

#[derive(Deserialize)]
struct JobLogsQuery {
    from: Option<usize>,
}

#[derive(Serialize)]
struct JobLogsResponse {
    id: u64,
    from: usize,
    next: usize,
    dropped: bool,
    lines: Vec<String>,
}

#[derive(Serialize)]
struct JobResultResponse {
    id: u64,
    result: Value,
}

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = load_or_write_config()?;
    let env_filter =
        EnvFilter::try_new(config.log_level.as_str()).unwrap_or_else(|_| EnvFilter::new("info"));
    tracing_subscriber::fmt().with_env_filter(env_filter).init();

    let (shutdown_tx, shutdown_rx) = oneshot::channel();
    let state = AppState {
        config: Arc::new(config.clone()),
        shutdown_tx: Arc::new(Mutex::new(Some(shutdown_tx))),
        jobs: Arc::new(Mutex::new(HashMap::new())),
        job_counter: Arc::new(AtomicU64::new(1)),
        job_semaphore: Arc::new(Semaphore::new(config.job_concurrency)),
    };

    let app = Router::new()
        .route("/health", get(health))
        .route("/config", get(get_config))
        .route("/jobs", post(start_job))
        .route("/jobs/:id", get(get_job))
        .route("/jobs/:id/logs", get(get_job_logs))
        .route("/jobs/:id/result", get(get_job_result))
        .route("/shutdown", post(shutdown))
        .with_state(state);

    let addr: SocketAddr = format!("{}:{}", config.listen_host, config.listen_port).parse()?;
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    tracing::info!(%addr, "backend listening");

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal(shutdown_rx))
        .await?;

    Ok(())
}

async fn health() -> impl IntoResponse {
    Json(json!({ "status": "ok" }))
}

async fn get_config(State(state): State<AppState>) -> impl IntoResponse {
    Json(state.config.as_ref().clone())
}

async fn shutdown(State(state): State<AppState>) -> impl IntoResponse {
    let mut guard = state.shutdown_tx.lock().await;
    if let Some(tx) = guard.take() {
        let _ = tx.send(());
    }
    Json(json!({ "status": "shutting_down" }))
}

async fn start_job(
    State(state): State<AppState>,
    Json(req): Json<StartJobRequest>,
) -> Result<Json<StartJobResponse>, (StatusCode, Json<ErrorResponse>)> {
    let kind = req.kind.trim();
    if kind.is_empty() {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "kind is required".to_string(),
            }),
        ));
    }

    let id = state.job_counter.fetch_add(1, Ordering::SeqCst);
    let job = Job::new(id, kind.to_string());
    {
        let mut jobs = state.jobs.lock().await;
        jobs.insert(id, job);
    }

    spawn_job(state.clone(), id, kind.to_string(), req.args);

    Ok(Json(StartJobResponse {
        id,
        status: JobStatus::Queued,
    }))
}

async fn get_job(
    State(state): State<AppState>,
    Path(id): Path<u64>,
) -> Result<Json<JobView>, (StatusCode, Json<ErrorResponse>)> {
    let jobs = state.jobs.lock().await;
    let job = jobs.get(&id).ok_or_else(|| {
        (
            StatusCode::NOT_FOUND,
            Json(ErrorResponse {
                error: "job not found".to_string(),
            }),
        )
    })?;
    Ok(Json(JobView::from(job)))
}

async fn get_job_logs(
    State(state): State<AppState>,
    Path(id): Path<u64>,
    Query(query): Query<JobLogsQuery>,
) -> Result<Json<JobLogsResponse>, (StatusCode, Json<ErrorResponse>)> {
    let jobs = state.jobs.lock().await;
    let job = jobs.get(&id).ok_or_else(|| {
        (
            StatusCode::NOT_FOUND,
            Json(ErrorResponse {
                error: "job not found".to_string(),
            }),
        )
    })?;

    let request_from = query.from.unwrap_or(job.log_offset);
    let dropped = request_from < job.log_offset;
    let from = if dropped { job.log_offset } else { request_from };
    let start = from.saturating_sub(job.log_offset);
    let lines: Vec<String> = job.logs.iter().skip(start).cloned().collect();
    let next = job.log_offset + job.logs.len();

    Ok(Json(JobLogsResponse {
        id,
        from,
        next,
        dropped,
        lines,
    }))
}

async fn get_job_result(
    State(state): State<AppState>,
    Path(id): Path<u64>,
) -> Result<Json<JobResultResponse>, (StatusCode, Json<ErrorResponse>)> {
    let jobs = state.jobs.lock().await;
    let job = jobs.get(&id).ok_or_else(|| {
        (
            StatusCode::NOT_FOUND,
            Json(ErrorResponse {
                error: "job not found".to_string(),
            }),
        )
    })?;

    let result = job.result.clone().ok_or_else(|| {
        (
            StatusCode::CONFLICT,
            Json(ErrorResponse {
                error: "job result not ready".to_string(),
            }),
        )
    })?;

    Ok(Json(JobResultResponse { id, result }))
}

async fn shutdown_signal(mut rx: oneshot::Receiver<()>) {
    let ctrl_c = tokio::signal::ctrl_c();
    tokio::select! {
        _ = &mut rx => {},
        _ = ctrl_c => {},
    }
}

fn load_or_write_config() -> Result<Config, Box<dyn std::error::Error>> {
    let path = config_path();
    if !path.exists() {
        let default_cfg = Config::default();
        let contents = serde_json::to_string_pretty(&default_cfg)?;
        std::fs::write(&path, contents)?;
        return Ok(default_cfg);
    }

    let contents = std::fs::read_to_string(&path)?;
    let cfg = serde_json::from_str::<Config>(&contents)?;
    Ok(cfg)
}

fn config_path() -> PathBuf {
    exe_dir().join("config.json")
}

pub(crate) fn exe_dir() -> PathBuf {
    if let Ok(exe) = std::env::current_exe() {
        if let Some(parent) = exe.parent() {
            return parent.to_path_buf();
        }
    }
    std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."))
}

fn spawn_job(state: AppState, id: u64, kind: String, args: Option<Value>) {
    tokio::spawn(async move {
        let permit = state.job_semaphore.acquire().await;
        if permit.is_err() {
            job_fail(&state, id, "failed to acquire job slot".to_string()).await;
            return;
        }
        let _permit = permit.unwrap();
        job_start(&state, id, &format!("job started: {}", kind)).await;
        if let Err(err) = run_job(&state, id, &kind, args).await {
            job_fail(&state, id, err).await;
            return;
        }
        job_finish(&state, id, "job completed".to_string()).await;
    });
}

async fn run_job(
    state: &AppState,
    id: u64,
    kind: &str,
    args: Option<Value>,
) -> Result<(), String> {
    match kind {
        "noop" => {
            let _args = args;
            for step in 0..=5 {
                let progress = (step * 20) as u8;
                job_progress(state, id, progress).await;
                job_log(state, id, format!("noop step {}/5", step)).await;
                tokio::time::sleep(std::time::Duration::from_millis(200)).await;
            }
            Ok(())
        }
        "update_db" => update_db::run_update_db_job(state.clone(), id).await,
        "missing_deps" => missing_deps::run_missing_deps_job(state.clone(), id, args).await,
        "rebuild_links" => links::run_rebuild_links_job(state.clone(), id, args).await,
        "links_move" => links::run_move_links_job(state.clone(), id, args).await,
        "links_missing_create" => links::run_missing_links_create_job(state.clone(), id, args).await,
        "install_vars" => vars_jobs::run_install_vars_job(state.clone(), id, args).await,
        "uninstall_vars" => vars_jobs::run_uninstall_vars_job(state.clone(), id, args).await,
        "delete_vars" => vars_jobs::run_delete_vars_job(state.clone(), id, args).await,
        "vars_export_installed" => vars_misc::run_export_installed_job(state.clone(), id, args).await,
        "vars_install_batch" => vars_misc::run_install_batch_job(state.clone(), id, args).await,
        "vars_toggle_install" => vars_misc::run_toggle_install_job(state.clone(), id, args).await,
        "vars_locate" => vars_misc::run_locate_job(state.clone(), id, args).await,
        "refresh_install_status" => vars_misc::run_refresh_install_status_job(state.clone(), id, args).await,
        "saves_deps" => deps_jobs::run_saves_deps_job(state.clone(), id, args).await,
        "log_deps" => deps_jobs::run_log_deps_job(state.clone(), id, args).await,
        "fix_previews" => preview_jobs::run_fix_previews_job(state.clone(), id, args).await,
        "stale_vars" => stale_jobs::run_stale_vars_job(state.clone(), id, args).await,
        "old_version_vars" => stale_jobs::run_old_version_vars_job(state.clone(), id, args).await,
        "packswitch_add" => packswitch::run_packswitch_add_job(state.clone(), id, args).await,
        "packswitch_delete" => packswitch::run_packswitch_delete_job(state.clone(), id, args).await,
        "packswitch_rename" => packswitch::run_packswitch_rename_job(state.clone(), id, args).await,
        "packswitch_set" => packswitch::run_packswitch_set_job(state.clone(), id, args).await,
        "hub_missing_scan" => hub::run_hub_missing_scan_job(state.clone(), id, args).await,
        "hub_updates_scan" => hub::run_hub_updates_scan_job(state.clone(), id, args).await,
        "hub_download_all" => hub::run_hub_download_all_job(state.clone(), id, args).await,
        "hub_info" => hub::run_hub_info_job(state.clone(), id).await,
        "hub_resources" => hub::run_hub_resources_job(state.clone(), id, args).await,
        "hub_resource_detail" => hub::run_hub_resource_detail_job(state.clone(), id, args).await,
        "hub_find_packages" => hub::run_hub_find_packages_job(state.clone(), id, args).await,
        "scene_load" => scenes::run_scene_load_job(state.clone(), id, args).await,
        "scene_analyze" => scenes::run_scene_analyze_job(state.clone(), id, args).await,
        "scene_preset_look" => scenes::run_scene_preset_look_job(state.clone(), id, args).await,
        "scene_preset_plugin" => scenes::run_scene_preset_plugin_job(state.clone(), id, args).await,
        "scene_preset_pose" => scenes::run_scene_preset_pose_job(state.clone(), id, args).await,
        "scene_preset_animation" => scenes::run_scene_preset_animation_job(state.clone(), id, args).await,
        "scene_preset_scene" => scenes::run_scene_preset_scene_job(state.clone(), id, args).await,
        "scene_add_atoms" => scenes::run_scene_add_atoms_job(state.clone(), id, args).await,
        "scene_add_subscene" => scenes::run_scene_add_subscene_job(state.clone(), id, args).await,
        "scene_hide" => scenes::run_scene_hide_job(state.clone(), id, args).await,
        "scene_fav" => scenes::run_scene_fav_job(state.clone(), id, args).await,
        "scene_unhide" => scenes::run_scene_unhide_job(state.clone(), id, args).await,
        "scene_unfav" => scenes::run_scene_unfav_job(state.clone(), id, args).await,
        "cache_clear" => scenes::run_cache_clear_job(state.clone(), id, args).await,
        "vam_start" => system_jobs::run_vam_start_job(state.clone(), id, args).await,
        "rescan_packages" => system_jobs::run_rescan_packages_job(state.clone(), id, args).await,
        "open_url" => system_jobs::run_open_url_job(state.clone(), id, args).await,
        _ => Err(format!("job kind not implemented: {}", kind)),
    }
}

pub(crate) async fn job_start(state: &AppState, id: u64, message: &str) {
    let mut jobs = state.jobs.lock().await;
    if let Some(job) = jobs.get_mut(&id) {
        job.status = JobStatus::Running;
        job.message = message.to_string();
        push_log(job, message.to_string());
        job.result = None;
    }
}

pub(crate) async fn job_finish(state: &AppState, id: u64, message: String) {
    let mut jobs = state.jobs.lock().await;
    if let Some(job) = jobs.get_mut(&id) {
        job.status = JobStatus::Succeeded;
        job.progress = 100;
        job.message = message.clone();
        job.error = None;
        push_log(job, message);
    }
}

pub(crate) async fn job_fail(state: &AppState, id: u64, error: String) {
    let mut jobs = state.jobs.lock().await;
    if let Some(job) = jobs.get_mut(&id) {
        job.status = JobStatus::Failed;
        job.message = "job failed".to_string();
        job.error = Some(error.clone());
        push_log(job, format!("error: {}", error));
    }
}

pub(crate) async fn job_progress(state: &AppState, id: u64, progress: u8) {
    let mut jobs = state.jobs.lock().await;
    if let Some(job) = jobs.get_mut(&id) {
        job.progress = progress.min(100);
    }
}

pub(crate) async fn job_log(state: &AppState, id: u64, line: String) {
    let mut jobs = state.jobs.lock().await;
    if let Some(job) = jobs.get_mut(&id) {
        push_log(job, line);
    }
}

pub(crate) async fn job_set_result(state: &AppState, id: u64, result: Value) {
    let mut jobs = state.jobs.lock().await;
    if let Some(job) = jobs.get_mut(&id) {
        job.result = Some(result);
    }
}

fn push_log(job: &mut Job, line: String) {
    if job.logs.len() >= LOG_CAPACITY {
        job.logs.pop_front();
        job.log_offset += 1;
    }
    job.logs.push_back(line);
}
