use axum::{
    body::Body,
    extract::{Path, Query, State},
    http::{header, StatusCode},
    response::{IntoResponse, Response},
    routing::{get, post, put},
    Json, Router,
};
use rusqlite::{params_from_iter, types::Value as SqlValue};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{
    collections::HashMap,
    env,
    net::SocketAddr,
    path::{Component, Path as StdPath, PathBuf},
    sync::{
        atomic::{AtomicU64, Ordering},
        Arc, RwLock,
    },
};
use tokio::sync::{oneshot, Semaphore};
use tokio::time::{interval, Duration};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter, Layer};
use walkdir::WalkDir;
use sysinfo::{Pid, ProcessesToUpdate, System};

mod db;
mod deps_jobs;
mod fs_util;
mod hub;
pub mod job_channel;
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
mod util;
mod var_logic;
mod vars_misc;
mod vars_jobs;
mod winfs;

use job_channel::{
    create_job_channel, create_job_map, JobEventSender, JobManager, JobMap,
    JobState, JobStatus, JobView, JobLogsResponse, JobResultResponse, JobReporter,
    send_job_started, send_job_finished, send_job_failed,
};
const PARENT_PID_ENV: &str = "VARMANAGER_PARENT_PID";

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
    config: Arc<RwLock<Config>>,
    shutdown_tx: Arc<tokio::sync::Mutex<Option<oneshot::Sender<()>>>>,
    jobs: JobMap,
    job_counter: Arc<AtomicU64>,
    job_semaphore: Arc<RwLock<Arc<Semaphore>>>,
    job_tx: JobEventSender,
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

#[derive(Deserialize)]
struct VarsQuery {
    page: Option<u32>,
    per_page: Option<u32>,
    search: Option<String>,
    creator: Option<String>,
    package: Option<String>,
    version: Option<String>,
    installed: Option<String>,
    disabled: Option<String>,
    min_size: Option<f64>,
    max_size: Option<f64>,
    min_dependency: Option<i64>,
    max_dependency: Option<i64>,
    has_scene: Option<bool>,
    has_look: Option<bool>,
    has_cloth: Option<bool>,
    has_hair: Option<bool>,
    has_skin: Option<bool>,
    has_pose: Option<bool>,
    has_morph: Option<bool>,
    has_plugin: Option<bool>,
    has_script: Option<bool>,
    has_asset: Option<bool>,
    has_texture: Option<bool>,
    has_sub_scene: Option<bool>,
    has_appearance: Option<bool>,
    sort: Option<String>,
    order: Option<String>,
}

#[derive(Deserialize)]
struct ScenesQuery {
    page: Option<u32>,
    per_page: Option<u32>,
    search: Option<String>,
    creator: Option<String>,
    category: Option<String>,
    installed: Option<String>,
    hide_fav: Option<String>,
    location: Option<String>,
    sort: Option<String>,
    order: Option<String>,
}

#[derive(Deserialize)]
struct DependentsQuery {
    name: String,
}

#[derive(Deserialize)]
struct AnalysisAtomsQuery {
    var_name: String,
    entry_name: String,
}

#[derive(Deserialize)]
struct ResolveVarsRequest {
    names: Vec<String>,
}

#[derive(Deserialize)]
struct ValidateOutputRequest {
    path: String,
}

#[derive(Serialize)]
struct ValidateOutputResponse {
    ok: bool,
    reason: Option<String>,
}

#[derive(Deserialize, Serialize)]
struct MissingMapItem {
    missing_var: String,
    dest_var: String,
}

#[derive(Deserialize)]
struct MissingMapSaveRequest {
    path: String,
    links: Vec<MissingMapItem>,
}

#[derive(Deserialize)]
struct MissingMapLoadRequest {
    path: String,
}

#[derive(Serialize)]
struct MissingMapResponse {
    links: Vec<MissingMapItem>,
}

#[derive(Deserialize)]
struct VarDependenciesRequest {
    var_names: Vec<String>,
}

#[derive(Serialize)]
struct VarDependencyItem {
    var_name: String,
    dependency: String,
}

#[derive(Serialize)]
struct VarDependenciesResponse {
    items: Vec<VarDependencyItem>,
}

#[derive(Deserialize)]
struct VarPreviewsRequest {
    var_names: Vec<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
struct VarPreviewItem {
    var_name: String,
    atom_type: String,
    preview_pic: Option<String>,
    scene_path: String,
    is_preset: bool,
    is_loadable: bool,
}

#[derive(Serialize)]
struct VarPreviewsResponse {
    items: Vec<VarPreviewItem>,
}

#[derive(Deserialize)]
struct PreviewQuery {
    root: String,
    path: String,
}

#[derive(Deserialize)]
struct UpdateConfigRequest {
    listen_host: Option<String>,
    listen_port: Option<u16>,
    log_level: Option<String>,
    job_concurrency: Option<usize>,
    varspath: Option<String>,
    vampath: Option<String>,
    vam_exec: Option<String>,
    downloader_path: Option<String>,
    downloader_save_path: Option<String>,
}

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
}

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
struct VarListItem {
    var_name: String,
    creator_name: Option<String>,
    package_name: Option<String>,
    meta_date: Option<String>,
    var_date: Option<String>,
    version: Option<String>,
    description: Option<String>,
    morph: Option<i64>,
    cloth: Option<i64>,
    hair: Option<i64>,
    skin: Option<i64>,
    pose: Option<i64>,
    scene: Option<i64>,
    script: Option<i64>,
    plugin: Option<i64>,
    asset: Option<i64>,
    texture: Option<i64>,
    look: Option<i64>,
    sub_scene: Option<i64>,
    appearance: Option<i64>,
    dependency_cnt: Option<i64>,
    fsize: Option<f64>,
    installed: bool,
    disabled: bool,
}

#[derive(Serialize)]
struct VarsListResponse {
    items: Vec<VarListItem>,
    page: u32,
    per_page: u32,
    total: u64,
}

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
struct SceneListItem {
    var_name: String,
    atom_type: String,
    preview_pic: Option<String>,
    scene_path: String,
    is_preset: bool,
    is_loadable: bool,
    creator_name: Option<String>,
    package_name: Option<String>,
    meta_date: Option<String>,
    var_date: Option<String>,
    version: Option<String>,
    installed: bool,
    disabled: bool,
    hide: bool,
    fav: bool,
    hide_fav: i32,
    location: String,
}

#[derive(Serialize)]
struct ScenesListResponse {
    items: Vec<SceneListItem>,
    page: u32,
    per_page: u32,
    total: u64,
}

#[derive(Serialize)]
struct CreatorsResponse {
    creators: Vec<String>,
}

#[derive(Serialize)]
struct PackSwitchListResponse {
    current: String,
    switches: Vec<String>,
}

#[derive(Serialize)]
struct DependentsResponse {
    dependents: Vec<String>,
    dependent_saves: Vec<String>,
}

#[derive(Serialize)]
struct AnalysisAtomsResponse {
    atoms: Vec<scenes::AtomTreeNode>,
    person_atoms: Vec<String>,
}

#[derive(Serialize)]
struct SavesTreeItem {
    path: String,
    name: String,
    preview: Option<String>,
    modified: Option<String>,
}

#[derive(Serialize)]
struct SavesTreeGroup {
    id: String,
    title: String,
    items: Vec<SavesTreeItem>,
}

#[derive(Serialize)]
struct SavesTreeResponse {
    groups: Vec<SavesTreeGroup>,
}

#[derive(Serialize)]
struct ResolveVarsResponse {
    resolved: HashMap<String, String>,
}

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
struct StatsResponse {
    vars_total: u64,
    vars_installed: u64,
    vars_disabled: u64,
    scenes_total: u64,
    missing_deps: u64,
}

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
struct DependencyStatus {
    name: String,
    resolved: String,
    missing: bool,
    closest: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
struct ScenePreviewItem {
    atom_type: String,
    preview_pic: Option<String>,
    scene_path: String,
    is_preset: bool,
    is_loadable: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
struct VarDetailResponse {
    var_info: VarListItem,
    dependencies: Vec<DependencyStatus>,
    dependents: Vec<String>,
    dependent_saves: Vec<String>,
    scenes: Vec<ScenePreviewItem>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = load_or_write_config()?;

    // Parse the configured log level, but filter out noisy third-party libraries
    let base_level = config.log_level.as_str();
    let env_filter = if base_level == "debug" {
        // If debug is requested, only show debug for our crate, info for others
        EnvFilter::new("varManager_backend=debug,h2=info,reqwest=info,hyper=info,hyper_util=info")
    } else {
        // For other levels, use the configured level
        EnvFilter::try_new(base_level).unwrap_or_else(|_| EnvFilter::new("info"))
    };

    let log_dir = exe_dir();
    let file_appender = tracing_appender::rolling::never(&log_dir, "backend.log");
    let (file_writer, file_guard) = tracing_appender::non_blocking(file_appender);

    // IMPORTANT: Also use non_blocking for stdout to prevent blocking tokio threads
    // when Flutter frontend doesn't read stdout pipe fast enough
    let (stdout_writer, stdout_guard) = tracing_appender::non_blocking(std::io::stdout());
    let stdout_layer = tracing_subscriber::fmt::layer()
        .with_writer(stdout_writer)
        .with_filter(env_filter);

    // File layer: debug for our crate, info for third-party libraries
    let file_filter = EnvFilter::new("varManager_backend=debug,h2=info,reqwest=info,hyper=info,hyper_util=info");
    let file_layer = tracing_subscriber::fmt::layer()
        .with_ansi(false)
        .with_writer(file_writer)
        .with_filter(file_filter);

    tracing_subscriber::registry()
        .with(stdout_layer)
        .with(file_layer)
        .init();
    let _file_guard = file_guard;
    let _stdout_guard = stdout_guard;

    let (shutdown_tx, shutdown_rx) = oneshot::channel();
    let (job_tx, job_rx) = create_job_channel();
    let jobs = create_job_map();
    let state = AppState {
        config: Arc::new(RwLock::new(config.clone())),
        shutdown_tx: Arc::new(tokio::sync::Mutex::new(Some(shutdown_tx))),
        jobs: jobs.clone(),
        job_counter: Arc::new(AtomicU64::new(1)),
        job_semaphore: Arc::new(RwLock::new(Arc::new(Semaphore::new(config.job_concurrency)))),
        job_tx,
    };

    // Start JobManager to consume job events and update state
    let job_manager = JobManager::new(job_rx, jobs);
    tokio::spawn(async move {
        job_manager.run().await;
    });

    if let Some(parent_pid) = read_parent_pid() {
        tracing::info!(parent_pid, "parent watchdog enabled");
        let state_clone = state.clone();
        tokio::spawn(async move {
            parent_watchdog(parent_pid, state_clone).await;
        });
    }

    let app = Router::new()
        .route("/health", get(health))
        .route("/config", get(get_config))
        .route("/config", put(update_config))
        .route("/vars", get(list_vars))
        .route("/vars/{name}", get(get_var_detail))
        .route("/vars/resolve", post(resolve_vars))
        .route("/vars/dependencies", post(list_var_dependencies))
        .route("/vars/previews", post(list_var_previews))
        .route("/scenes", get(list_scenes))
        .route("/creators", get(list_creators))
        .route("/stats", get(get_stats))
        .route("/preview", get(get_preview))
        .route("/packswitch", get(list_packswitch))
        .route("/dependents", get(list_dependents))
        .route("/analysis/atoms", get(list_analysis_atoms))
        .route("/saves/tree", get(list_saves_tree))
        .route("/saves/validate_output", post(validate_output_dir))
        .route("/missing/map/save", post(save_missing_map))
        .route("/missing/map/load", post(load_missing_map))
        .route("/jobs", post(start_job))
        .route("/jobs/{id}", get(get_job))
        .route("/jobs/{id}/logs", get(get_job_logs))
        .route("/jobs/{id}/result", get(get_job_result))
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
    match read_config(&state) {
        Ok(cfg) => Json(cfg).into_response(),
        Err(err) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
            .into_response(),
    }
}

async fn shutdown(State(state): State<AppState>) -> impl IntoResponse {
    trigger_shutdown(&state).await;
    Json(json!({ "status": "shutting_down" }))
}

async fn trigger_shutdown(state: &AppState) {
    let mut guard = state.shutdown_tx.lock().await;
    if let Some(tx) = guard.take() {
        let _ = tx.send(());
    }
}

fn read_parent_pid() -> Option<u32> {
    let raw = env::var(PARENT_PID_ENV).ok()?;
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return None;
    }
    let pid = trimmed.parse::<u32>().ok()?;
    if pid == 0 {
        return None;
    }
    Some(pid)
}

async fn parent_watchdog(parent_pid: u32, state: AppState) {
    let target = Pid::from_u32(parent_pid);
    let mut system = System::new();
    let mut ticker = interval(Duration::from_secs(3));
    loop {
        ticker.tick().await;
        system.refresh_processes(ProcessesToUpdate::Some(&[target]), true);
        if system.process(target).is_none() {
            tracing::info!(parent_pid, "parent process exited, shutting down backend");
            trigger_shutdown(&state).await;
            break;
        }
    }
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
    let job = JobState::new(id, kind.to_string());
    {
        let mut jobs = state.jobs.write().await;
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
    let jobs = state.jobs.read().await;
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
    let jobs = state.jobs.read().await;
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
    let jobs = state.jobs.read().await;
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

fn read_config(state: &AppState) -> Result<Config, String> {
    let guard = state
        .config
        .read()
        .map_err(|_| "config lock poisoned".to_string())?;
    Ok(guard.clone())
}

fn normalize_optional(value: Option<String>) -> Option<String> {
    value.and_then(|raw| {
        let trimmed = raw.trim().to_string();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed)
        }
    })
}

fn apply_config_update(current: &Config, req: UpdateConfigRequest) -> Result<Config, String> {
    let mut next = current.clone();
    if let Some(host) = req.listen_host {
        let trimmed = host.trim();
        if trimmed.is_empty() {
            return Err("listen_host cannot be empty".to_string());
        }
        next.listen_host = trimmed.to_string();
    }
    if let Some(port) = req.listen_port {
        if !(1..=65535).contains(&port) {
            return Err("listen_port must be between 1 and 65535".to_string());
        }
        next.listen_port = port;
    }
    if let Some(level) = req.log_level {
        let trimmed = level.trim();
        if trimmed.is_empty() {
            return Err("log_level cannot be empty".to_string());
        }
        next.log_level = trimmed.to_string();
    }
    if let Some(concurrency) = req.job_concurrency {
        if concurrency == 0 {
            return Err("job_concurrency must be >= 1".to_string());
        }
        next.job_concurrency = concurrency;
    }
    if req.varspath.is_some() {
        next.varspath = normalize_optional(req.varspath);
    }
    if req.vampath.is_some() {
        next.vampath = normalize_optional(req.vampath);
    }
    if req.vam_exec.is_some() {
        next.vam_exec = normalize_optional(req.vam_exec);
    }
    if req.downloader_path.is_some() {
        next.downloader_path = normalize_optional(req.downloader_path);
    }
    if req.downloader_save_path.is_some() {
        next.downloader_save_path = normalize_optional(req.downloader_save_path);
    }
    Ok(next)
}

async fn update_config(
    State(state): State<AppState>,
    Json(req): Json<UpdateConfigRequest>,
) -> Result<Json<Config>, (StatusCode, Json<ErrorResponse>)> {
    let current = read_config(&state).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    let next = apply_config_update(&current, req).map_err(|err| {
        (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse { error: err }),
        )
    })?;

    let path = config_path();
    let contents = serde_json::to_string_pretty(&next).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: err.to_string(),
            }),
        )
    })?;
    std::fs::write(&path, contents).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: err.to_string(),
            }),
        )
    })?;

    {
        let mut guard = state
            .config
            .write()
            .map_err(|_| {
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    Json(ErrorResponse {
                        error: "config lock poisoned".to_string(),
                    }),
                )
            })?;
        *guard = next.clone();
    }
    {
        let mut guard = state
            .job_semaphore
            .write()
            .map_err(|_| {
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    Json(ErrorResponse {
                        error: "semaphore lock poisoned".to_string(),
                    }),
                )
            })?;
        *guard = Arc::new(Semaphore::new(next.job_concurrency));
    }

    Ok(Json(next))
}

async fn list_vars(
    State(state): State<AppState>,
    Query(query): Query<VarsQuery>,
) -> Result<Json<VarsListResponse>, (StatusCode, Json<ErrorResponse>)> {
    let _cfg = read_config(&state).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    let db_path = exe_dir().join("varManager.db");
    let db = crate::db::Db::open(&db_path).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    db.ensure_schema().map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;

    let page = query.page.unwrap_or(1).max(1);
    let per_page = query.per_page.unwrap_or(50).clamp(1, 200);
    let offset = ((page - 1) * per_page) as i64;

    let mut conditions = Vec::new();
    let mut params: Vec<SqlValue> = Vec::new();

    if let Some(creator) = query.creator.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty()) {
        conditions.push("v.creatorName = ?".to_string());
        params.push(SqlValue::from(creator.to_string()));
    }
    if let Some(package) = query.package.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty()) {
        conditions.push("v.packageName LIKE ?".to_string());
        params.push(SqlValue::from(format!("%{}%", package)));
    }
    if let Some(version) = query.version.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty()) {
        conditions.push("v.version LIKE ?".to_string());
        params.push(SqlValue::from(format!("%{}%", version)));
    }
    if let Some(search) = query.search.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty()) {
        conditions.push("(v.varName LIKE ? OR v.packageName LIKE ?)".to_string());
        let like = format!("%{}%", search);
        params.push(SqlValue::from(like.clone()));
        params.push(SqlValue::from(like));
    }
    if let Some(installed) = query.installed.as_ref().map(|s| s.to_lowercase()) {
        match installed.as_str() {
            "true" | "1" | "yes" => {
                conditions.push("i.installed = 1".to_string());
            }
            "false" | "0" | "no" => {
                conditions.push("(i.installed IS NULL OR i.installed = 0)".to_string());
            }
            _ => {}
        }
    }
    if let Some(disabled) = query.disabled.as_ref().map(|s| s.to_lowercase()) {
        match disabled.as_str() {
            "true" | "1" | "yes" => {
                conditions.push("i.disabled = 1".to_string());
            }
            "false" | "0" | "no" => {
                conditions.push("(i.disabled IS NULL OR i.disabled = 0)".to_string());
            }
            _ => {}
        }
    }
    if let Some(min_size) = query.min_size {
        conditions.push("COALESCE(v.fsize, 0) >= ?".to_string());
        params.push(SqlValue::from(min_size));
    }
    if let Some(max_size) = query.max_size {
        conditions.push("COALESCE(v.fsize, 0) <= ?".to_string());
        params.push(SqlValue::from(max_size));
    }
    if let Some(min_dependency) = query.min_dependency {
        conditions.push("COALESCE(v.dependencyCnt, 0) >= ?".to_string());
        params.push(SqlValue::from(min_dependency));
    }
    if let Some(max_dependency) = query.max_dependency {
        conditions.push("COALESCE(v.dependencyCnt, 0) <= ?".to_string());
        params.push(SqlValue::from(max_dependency));
    }
    if let Some(value) = query.has_scene {
        conditions.push(format!(
            "COALESCE(v.scene, 0) {} 0",
            if value { ">" } else { "=" }
        ));
    }
    if let Some(value) = query.has_look {
        conditions.push(format!(
            "COALESCE(v.look, 0) {} 0",
            if value { ">" } else { "=" }
        ));
    }
    if let Some(value) = query.has_cloth {
        conditions.push(format!(
            "COALESCE(v.cloth, 0) {} 0",
            if value { ">" } else { "=" }
        ));
    }
    if let Some(value) = query.has_hair {
        conditions.push(format!(
            "COALESCE(v.hair, 0) {} 0",
            if value { ">" } else { "=" }
        ));
    }
    if let Some(value) = query.has_skin {
        conditions.push(format!(
            "COALESCE(v.skin, 0) {} 0",
            if value { ">" } else { "=" }
        ));
    }
    if let Some(value) = query.has_pose {
        conditions.push(format!(
            "COALESCE(v.pose, 0) {} 0",
            if value { ">" } else { "=" }
        ));
    }
    if let Some(value) = query.has_morph {
        conditions.push(format!(
            "COALESCE(v.morph, 0) {} 0",
            if value { ">" } else { "=" }
        ));
    }
    if let Some(value) = query.has_plugin {
        conditions.push(format!(
            "COALESCE(v.plugin, 0) {} 0",
            if value { ">" } else { "=" }
        ));
    }
    if let Some(value) = query.has_script {
        conditions.push(format!(
            "COALESCE(v.script, 0) {} 0",
            if value { ">" } else { "=" }
        ));
    }
    if let Some(value) = query.has_asset {
        conditions.push(format!(
            "COALESCE(v.asset, 0) {} 0",
            if value { ">" } else { "=" }
        ));
    }
    if let Some(value) = query.has_texture {
        conditions.push(format!(
            "COALESCE(v.texture, 0) {} 0",
            if value { ">" } else { "=" }
        ));
    }
    if let Some(value) = query.has_sub_scene {
        conditions.push(format!(
            "COALESCE(v.subScene, 0) {} 0",
            if value { ">" } else { "=" }
        ));
    }
    if let Some(value) = query.has_appearance {
        conditions.push(format!(
            "COALESCE(v.appearance, 0) {} 0",
            if value { ">" } else { "=" }
        ));
    }

    let where_clause = if conditions.is_empty() {
        "".to_string()
    } else {
        format!("WHERE {}", conditions.join(" AND "))
    };

    let sort = query.sort.as_deref().unwrap_or("meta_date");
    let order = query.order.as_deref().unwrap_or("desc");
    let sort_col = match sort {
        "var_name" => "v.varName",
        "creator" => "v.creatorName",
        "package" => "v.packageName",
        "var_date" => "v.varDate",
        "size" => "v.fsize",
        _ => "v.metaDate",
    };
    let order_sql = if order.eq_ignore_ascii_case("asc") {
        "ASC"
    } else {
        "DESC"
    };

    let count_sql = format!(
        "SELECT COUNT(1) FROM vars v LEFT JOIN installStatus i ON v.varName = i.varName {}",
        where_clause
    );
    let total: i64 = db
        .connection()
        .query_row(&count_sql, params_from_iter(params.iter()), |row| row.get(0))
        .map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: err.to_string(),
                }),
            )
        })?;
    let total = total as u64;

    let mut list_params = params.clone();
    list_params.push(SqlValue::from(per_page as i64));
    list_params.push(SqlValue::from(offset));
    let sql = format!(
        "SELECT v.varName, v.creatorName, v.packageName, v.metaDate, v.varDate, v.version, v.description,
                v.morph, v.cloth, v.hair, v.skin, v.pose, v.scene, v.script, v.plugin, v.asset, v.texture,
                v.look, v.subScene, v.appearance, v.dependencyCnt, v.fsize,
                COALESCE(i.installed, 0), COALESCE(i.disabled, 0)
         FROM vars v
         LEFT JOIN installStatus i ON v.varName = i.varName
         {}
         ORDER BY {} {}
         LIMIT ? OFFSET ?",
        where_clause, sort_col, order_sql
    );

    let mut stmt = db.connection().prepare(&sql).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: err.to_string(),
            }),
        )
    })?;
    let rows = stmt
        .query_map(params_from_iter(list_params.iter()), |row| {
            Ok(VarListItem {
                var_name: row.get(0)?,
                creator_name: row.get(1)?,
                package_name: row.get(2)?,
                meta_date: row.get(3)?,
                var_date: row.get(4)?,
                version: row.get(5)?,
                description: row.get(6)?,
                morph: row.get(7)?,
                cloth: row.get(8)?,
                hair: row.get(9)?,
                skin: row.get(10)?,
                pose: row.get(11)?,
                scene: row.get(12)?,
                script: row.get(13)?,
                plugin: row.get(14)?,
                asset: row.get(15)?,
                texture: row.get(16)?,
                look: row.get(17)?,
                sub_scene: row.get(18)?,
                appearance: row.get(19)?,
                dependency_cnt: row.get(20)?,
                fsize: row.get(21)?,
                installed: row.get::<_, i64>(22)? != 0,
                disabled: row.get::<_, i64>(23)? != 0,
            })
        })
        .map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: err.to_string(),
                }),
            )
        })?;

    let mut items = Vec::new();
    for row in rows {
        items.push(row.map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: err.to_string(),
                }),
            )
        })?);
    }

    Ok(Json(VarsListResponse {
        items,
        page,
        per_page,
        total,
    }))
}

async fn resolve_vars(
    State(state): State<AppState>,
    Json(req): Json<ResolveVarsRequest>,
) -> Result<Json<ResolveVarsResponse>, (StatusCode, Json<ErrorResponse>)> {
    let _cfg = read_config(&state).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    let db_path = exe_dir().join("varManager.db");
    let db = crate::db::Db::open(&db_path).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    db.ensure_schema().map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;

    let mut resolved = HashMap::new();
    for name in req.names {
        let value = crate::var_logic::resolve_var_exist_name(db.connection(), &name)
            .unwrap_or_else(|_| "missing".to_string());
        resolved.insert(name, value);
    }
    Ok(Json(ResolveVarsResponse { resolved }))
}

async fn validate_output_dir(
    Json(req): Json<ValidateOutputRequest>,
) -> Result<Json<ValidateOutputResponse>, (StatusCode, Json<ErrorResponse>)> {
    let path_str = req.path.trim();
    if path_str.is_empty() {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "path is required".to_string(),
            }),
        ));
    }
    let mut path = PathBuf::from(path_str);
    if !path.is_absolute() {
        path = exe_dir().join(&path);
    }
    if !path.exists() {
        return Ok(Json(ValidateOutputResponse {
            ok: false,
            reason: Some("path does not exist".to_string()),
        }));
    }
    if !path.is_dir() {
        return Ok(Json(ValidateOutputResponse {
            ok: false,
            reason: Some("path is not a directory".to_string()),
        }));
    }
    let mut entries = std::fs::read_dir(&path).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: err.to_string(),
            }),
        )
    })?;
    if entries.next().is_some() {
        return Ok(Json(ValidateOutputResponse {
            ok: false,
            reason: Some("directory not empty".to_string()),
        }));
    }
    Ok(Json(ValidateOutputResponse { ok: true, reason: None }))
}

async fn save_missing_map(
    Json(req): Json<MissingMapSaveRequest>,
) -> Result<Json<MissingMapResponse>, (StatusCode, Json<ErrorResponse>)> {
    let path_str = req.path.trim();
    if path_str.is_empty() {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "path is required".to_string(),
            }),
        ));
    }
    let mut path = PathBuf::from(path_str);
    if !path.is_absolute() {
        path = exe_dir().join(&path);
    }
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: err.to_string(),
                }),
            )
        })?;
    }
    let mut lines = Vec::new();
    let mut saved = Vec::new();
    for item in req.links {
        let missing = item.missing_var.trim();
        let dest = item.dest_var.trim();
        if missing.is_empty() || dest.is_empty() {
            continue;
        }
        lines.push(format!("{}|{}", missing, dest));
        saved.push(MissingMapItem {
            missing_var: missing.to_string(),
            dest_var: dest.to_string(),
        });
    }
    std::fs::write(&path, lines.join("\n")).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: err.to_string(),
            }),
        )
    })?;
    Ok(Json(MissingMapResponse { links: saved }))
}

async fn load_missing_map(
    Json(req): Json<MissingMapLoadRequest>,
) -> Result<Json<MissingMapResponse>, (StatusCode, Json<ErrorResponse>)> {
    let path_str = req.path.trim();
    if path_str.is_empty() {
        return Err((
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "path is required".to_string(),
            }),
        ));
    }
    let mut path = PathBuf::from(path_str);
    if !path.is_absolute() {
        path = exe_dir().join(&path);
    }
    let contents = std::fs::read_to_string(&path).map_err(|err| {
        (
            StatusCode::NOT_FOUND,
            Json(ErrorResponse {
                error: err.to_string(),
            }),
        )
    })?;
    let mut links = Vec::new();
    for line in contents.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let mut parts = line.splitn(2, '|');
        let missing = parts.next().unwrap_or("").trim();
        let dest = parts.next().unwrap_or("").trim();
        if missing.is_empty() || dest.is_empty() {
            continue;
        }
        links.push(MissingMapItem {
            missing_var: missing.to_string(),
            dest_var: dest.to_string(),
        });
    }
    Ok(Json(MissingMapResponse { links }))
}

async fn get_var_detail(
    State(state): State<AppState>,
    Path(name): Path<String>,
) -> Result<Json<VarDetailResponse>, (StatusCode, Json<ErrorResponse>)> {
    let _cfg = read_config(&state).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    let db_path = exe_dir().join("varManager.db");
    let db = crate::db::Db::open(&db_path).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    db.ensure_schema().map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;

    let mut stmt = db.connection().prepare(
        "SELECT v.varName, v.creatorName, v.packageName, v.metaDate, v.varDate, v.version, v.description,
                v.morph, v.cloth, v.hair, v.skin, v.pose, v.scene, v.script, v.plugin, v.asset, v.texture,
                v.look, v.subScene, v.appearance, v.dependencyCnt, v.fsize,
                COALESCE(i.installed, 0), COALESCE(i.disabled, 0)
         FROM vars v
         LEFT JOIN installStatus i ON v.varName = i.varName
         WHERE v.varName = ?1
         LIMIT 1",
    ).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err.to_string() }),
        )
    })?;

    let var_info = stmt
        .query_row([&name], |row| {
            Ok(VarListItem {
                var_name: row.get(0)?,
                creator_name: row.get(1)?,
                package_name: row.get(2)?,
                meta_date: row.get(3)?,
                var_date: row.get(4)?,
                version: row.get(5)?,
                description: row.get(6)?,
                morph: row.get(7)?,
                cloth: row.get(8)?,
                hair: row.get(9)?,
                skin: row.get(10)?,
                pose: row.get(11)?,
                scene: row.get(12)?,
                script: row.get(13)?,
                plugin: row.get(14)?,
                asset: row.get(15)?,
                texture: row.get(16)?,
                look: row.get(17)?,
                sub_scene: row.get(18)?,
                appearance: row.get(19)?,
                dependency_cnt: row.get(20)?,
                fsize: row.get(21)?,
                installed: row.get::<_, i64>(22)? != 0,
                disabled: row.get::<_, i64>(23)? != 0,
            })
        })
        .map_err(|err| {
            (
                StatusCode::NOT_FOUND,
                Json(ErrorResponse {
                    error: format!("var not found: {}", err),
                }),
            )
        })?;

    let dependencies = list_dependencies_with_status(db.connection(), &name)
        .map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse { error: err }),
            )
        })?;
    let dependents = list_dependents_conn(db.connection(), &name).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    let dependent_saves = list_dependent_saves(db.connection(), &name).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    let scenes = list_var_scenes(db.connection(), &name).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;

    Ok(Json(VarDetailResponse {
        var_info,
        dependencies,
        dependents,
        dependent_saves,
        scenes,
    }))
}

async fn list_scenes(
    State(state): State<AppState>,
    Query(query): Query<ScenesQuery>,
) -> Result<Json<ScenesListResponse>, (StatusCode, Json<ErrorResponse>)> {
    let _cfg = read_config(&state).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    let db_path = exe_dir().join("varManager.db");
    let db = crate::db::Db::open(&db_path).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    db.ensure_schema().map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;

    let page = query.page.unwrap_or(1).max(1);
    let per_page = query.per_page.unwrap_or(50).clamp(1, 200);

    let mut conditions = Vec::new();
    let mut params: Vec<SqlValue> = Vec::new();

    if let Some(category) = query.category.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty()) {
        conditions.push("s.atomType = ?".to_string());
        params.push(SqlValue::from(category.to_string()));
    }
    if let Some(creator) = query.creator.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty()) {
        conditions.push("v.creatorName = ?".to_string());
        params.push(SqlValue::from(creator.to_string()));
    }
    if let Some(search) = query.search.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty()) {
        conditions.push("(s.scenePath LIKE ? OR v.varName LIKE ?)".to_string());
        let like = format!("%{}%", search);
        params.push(SqlValue::from(like.clone()));
        params.push(SqlValue::from(like));
    }
    if let Some(installed) = query.installed.as_ref().map(|s| s.to_lowercase()) {
        match installed.as_str() {
            "true" | "1" | "yes" => conditions.push("i.installed = 1".to_string()),
            "false" | "0" | "no" => {
                conditions.push("(i.installed IS NULL OR i.installed = 0)".to_string())
            }
            _ => {}
        }
    }
    if let Some(hide_fav) = query.hide_fav.as_ref().map(|s| s.to_lowercase()) {
        let mut flags = Vec::new();
        for part in hide_fav.split(',') {
            let value = part.trim();
            if value == "hide" {
                flags.push("h.hide = 1".to_string());
            } else if value == "fav" {
                flags.push("h.fav = 1".to_string());
            } else if value == "normal" {
                flags.push(
                    "(h.hide IS NULL OR h.hide = 0) AND (h.fav IS NULL OR h.fav = 0)".to_string(),
                );
            }
        }
        if !flags.is_empty() {
            conditions.push(format!("({})", flags.join(" OR ")));
        }
    }

    let where_clause = if conditions.is_empty() {
        "".to_string()
    } else {
        format!("WHERE {}", conditions.join(" AND "))
    };

    let sql = format!(
        "SELECT s.varName, s.atomType, s.previewPic, s.scenePath, s.isPreset, s.isLoadable,
                v.creatorName, v.packageName, v.metaDate, v.varDate, v.version,
                COALESCE(i.installed, 0), COALESCE(i.disabled, 0),
                COALESCE(h.hide, 0), COALESCE(h.fav, 0)
         FROM scenes s
         LEFT JOIN vars v ON s.varName = v.varName
         LEFT JOIN installStatus i ON s.varName = i.varName
         LEFT JOIN HideFav h ON s.varName = h.varName
         {}",
        where_clause
    );
    let mut stmt = db.connection().prepare(&sql).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: err.to_string(),
            }),
        )
    })?;
    let rows = stmt
        .query_map(params_from_iter(params.iter()), |row| {
            let hide: i64 = row.get(13)?;
            let fav: i64 = row.get(14)?;
            let hide_fav = if hide != 0 { -1 } else if fav != 0 { 1 } else { 0 };
            let installed = row.get::<_, i64>(11)? != 0;
            let location = if installed {
                "installed".to_string()
            } else {
                "not_installed".to_string()
            };
            Ok(SceneListItem {
                var_name: row.get(0)?,
                atom_type: row.get(1)?,
                preview_pic: row.get(2)?,
                scene_path: row.get(3)?,
                is_preset: row.get::<_, i64>(4)? != 0,
                is_loadable: row.get::<_, i64>(5)? != 0,
                creator_name: row.get(6)?,
                package_name: row.get(7)?,
                meta_date: row.get(8)?,
                var_date: row.get(9)?,
                version: row.get(10)?,
                installed,
                disabled: row.get::<_, i64>(12)? != 0,
                hide: hide != 0,
                fav: fav != 0,
                hide_fav,
                location,
            })
        })
        .map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: err.to_string(),
                }),
            )
        })?;

    let mut items = Vec::new();
    for row in rows {
        items.push(row.map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: err.to_string(),
                }),
            )
        })?);
    }

    let location_filter = parse_location_filter(query.location.as_deref());
    let include_save = location_filter.contains("save");
    let include_missing = location_filter.contains("missinglink");
    if include_save || include_missing {
        let (_, vampath) = crate::paths::config_paths(&state).map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse { error: err }),
            )
        })?;
        let vampath = vampath.ok_or_else(|| {
            (
                StatusCode::BAD_REQUEST,
                Json(ErrorResponse {
                    error: "vampath is required in config.json".to_string(),
                }),
            )
        })?;

        if include_save {
            items.extend(load_save_scenes(&vampath));
        }
        if include_missing {
            items.extend(load_missing_link_scenes(&db, &vampath));
        }
    }

    let installed_filter = parse_bool_filter(query.installed.as_deref());
    let hide_fav_filter = parse_hide_fav_filter(query.hide_fav.as_deref());
    let category_filter = query.category.as_ref().map(|s| s.trim().to_string());
    let creator_filter = query.creator.as_ref().map(|s| s.trim().to_string());
    let search_filter = query
        .search
        .as_ref()
        .map(|s| s.trim().to_lowercase())
        .filter(|s| !s.is_empty());

    let mut filtered = items
        .into_iter()
        .filter(|item| {
            if !location_filter.is_empty() && !location_filter.contains(&item.location) {
                return false;
            }
            if let Some(installed) = installed_filter {
                if item.installed != installed {
                    return false;
                }
            }
            if let Some(allowed) = hide_fav_filter.as_ref() {
                if !allowed.contains(&item.hide_fav) {
                    return false;
                }
            }
            if let Some(category) = category_filter.as_ref() {
                if !category.is_empty() && item.atom_type != *category {
                    return false;
                }
            }
            if let Some(creator) = creator_filter.as_ref() {
                if !creator.is_empty() {
                    if item
                        .creator_name
                        .as_ref()
                        .map(|c| c != creator)
                        .unwrap_or(true)
                    {
                        return false;
                    }
                }
            }
            if let Some(search) = search_filter.as_ref() {
                let name = item.var_name.to_lowercase();
                let path = item.scene_path.to_lowercase();
                if !name.contains(search) && !path.contains(search) {
                    return false;
                }
            }
            true
        })
        .collect::<Vec<_>>();

    let sort = query.sort.as_deref().unwrap_or("var_date");
    let order = query.order.as_deref().unwrap_or("desc");
    filtered.sort_by(|a, b| {
        let ordering = match sort {
            "var_name" => a.var_name.cmp(&b.var_name),
            "scene_name" => scene_name(&a.scene_path).cmp(&scene_name(&b.scene_path)),
            "meta_date" => a
                .meta_date
                .as_deref()
                .unwrap_or("")
                .cmp(b.meta_date.as_deref().unwrap_or("")),
            _ => a
                .var_date
                .as_deref()
                .unwrap_or("")
                .cmp(b.var_date.as_deref().unwrap_or("")),
        };
        if order.eq_ignore_ascii_case("asc") {
            ordering
        } else {
            ordering.reverse()
        }
    });

    let total = filtered.len() as u64;
    let start = ((page - 1) * per_page) as usize;
    let page_items = filtered
        .into_iter()
        .skip(start)
        .take(per_page as usize)
        .collect::<Vec<_>>();

    Ok(Json(ScenesListResponse {
        items: page_items,
        page,
        per_page,
        total,
    }))
}

fn parse_location_filter(raw: Option<&str>) -> std::collections::HashSet<String> {
    let mut set = std::collections::HashSet::new();
    let raw = match raw {
        Some(value) => value,
        None => return set,
    };
    for part in raw.split(',') {
        let value = part.trim().to_ascii_lowercase();
        if value.is_empty() {
            continue;
        }
        let normalized = match value.as_str() {
            "installed" => "installed",
            "not installed" | "not_installed" | "notinstalled" => "not_installed",
            "missinglink" | "missing_link" | "missing link" => "missinglink",
            "save" => "save",
            other => other,
        };
        set.insert(normalized.to_string());
    }
    set
}

fn parse_bool_filter(raw: Option<&str>) -> Option<bool> {
    match raw.map(|s| s.to_ascii_lowercase()) {
        Some(value) if ["true", "1", "yes"].contains(&value.as_str()) => Some(true),
        Some(value) if ["false", "0", "no"].contains(&value.as_str()) => Some(false),
        _ => None,
    }
}

fn parse_hide_fav_filter(raw: Option<&str>) -> Option<std::collections::HashSet<i32>> {
    let raw = raw?;
    let mut set = std::collections::HashSet::new();
    for part in raw.split(',') {
        let value = part.trim().to_ascii_lowercase();
        match value.as_str() {
            "hide" => {
                set.insert(-1);
            }
            "fav" => {
                set.insert(1);
            }
            "normal" => {
                set.insert(0);
            }
            _ => {}
        }
    }
    if set.is_empty() {
        None
    } else {
        Some(set)
    }
}

fn scene_name(path: &str) -> String {
    StdPath::new(path)
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or(path)
        .to_string()
}

fn load_save_scenes(vampath: &StdPath) -> Vec<SceneListItem> {
    let mut items = Vec::new();
    let groups = vec![
        ("scenes", vampath.join("Saves").join("scene"), "json"),
        ("looks", vampath.join("Saves").join("Person").join("full"), "json"),
        (
            "looks",
            vampath.join("Saves").join("Person").join("appearance"),
            "json",
        ),
        (
            "looks",
            vampath.join("Custom").join("Atom").join("Person").join("Appearance"),
            "vap",
        ),
        (
            "pose",
            vampath.join("Saves").join("Person").join("pose"),
            "json",
        ),
        (
            "pose",
            vampath.join("Custom").join("Atom").join("Person").join("Pose"),
            "vap",
        ),
        (
            "clothing",
            vampath.join("Custom").join("Atom").join("Person").join("Clothing"),
            "vap",
        ),
        ("clothing", vampath.join("Custom").join("Clothing"), "vap"),
        (
            "hairstyle",
            vampath.join("Custom").join("Atom").join("Person").join("Hair"),
            "vap",
        ),
        ("hairstyle", vampath.join("Custom").join("Hair"), "vap"),
        (
            "morphs",
            vampath.join("Custom").join("Atom").join("Person").join("Morphs"),
            "vap",
        ),
        (
            "skin",
            vampath.join("Custom").join("Atom").join("Person").join("Skin"),
            "vap",
        ),
    ];
    for (atom_type, root, ext) in groups {
        if !root.exists() {
            continue;
        }
        for entry in WalkDir::new(&root)
            .into_iter()
            .filter_map(Result::ok)
            .filter(|e| e.file_type().is_file())
        {
            let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) != Some(ext) {
                continue;
            }
            let rel = path.strip_prefix(vampath).unwrap_or(path);
            let scene_path = rel.to_string_lossy().replace('\\', "/");
            let preview_path = path.with_extension("jpg");
            let preview_pic = if preview_path.exists() {
                Some(
                    preview_path
                        .strip_prefix(vampath)
                        .unwrap_or(&preview_path)
                        .to_string_lossy()
                        .replace('\\', "/"),
                )
            } else {
                None
            };
            let (hide, fav, hide_fav) = read_hide_fav_for_save(path);
            let modified = entry
                .metadata()
                .ok()
                .and_then(|m| m.modified().ok())
                .map(format_system_time)
                .unwrap_or_default();
            items.push(SceneListItem {
                var_name: "save".to_string(),
                atom_type: atom_type.to_string(),
                preview_pic,
                scene_path,
                is_preset: true,
                is_loadable: true,
                creator_name: Some("(save)".to_string()),
                package_name: None,
                meta_date: Some(modified.clone()),
                var_date: Some(modified),
                version: None,
                installed: true,
                disabled: false,
                hide,
                fav,
                hide_fav,
                location: "save".to_string(),
            });
        }
    }
    items
}

fn load_missing_link_scenes(db: &crate::db::Db, vampath: &StdPath) -> Vec<SceneListItem> {
    let mut items = Vec::new();
    let root = crate::paths::missing_links_dir(vampath);
    if !root.exists() {
        return items;
    }
    let mut vars = Vec::new();
    for entry in WalkDir::new(&root)
        .into_iter()
        .filter_map(Result::ok)
        .filter(|e| e.file_type().is_file())
    {
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) != Some("var") {
            continue;
        }
        let name = path.file_stem().and_then(|s| s.to_str()).unwrap_or("");
        if name.is_empty() {
            continue;
        }
        let mut dest = name.to_string();
        if let Ok(target) = crate::winfs::read_link_target(path) {
            if let Some(stem) = target.file_stem().and_then(|s| s.to_str()) {
                dest = stem.to_string();
            }
        }
        vars.push(dest);
    }
    vars.sort();
    vars.dedup();

    let mut stmt = match db.connection().prepare(
        "SELECT s.varName, s.atomType, s.previewPic, s.scenePath, s.isPreset, s.isLoadable,
                v.creatorName, v.packageName, v.metaDate, v.varDate, v.version,
                COALESCE(i.installed, 0), COALESCE(i.disabled, 0)
         FROM scenes s
         LEFT JOIN vars v ON s.varName = v.varName
         LEFT JOIN installStatus i ON s.varName = i.varName
         WHERE s.varName = ?1",
    ) {
        Ok(stmt) => stmt,
        Err(_) => return items,
    };

    for var_name in vars {
        let rows = stmt.query_map([&var_name], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, Option<String>>(2)?,
                row.get::<_, String>(3)?,
                row.get::<_, i64>(4)?,
                row.get::<_, i64>(5)?,
                row.get::<_, Option<String>>(6)?,
                row.get::<_, Option<String>>(7)?,
                row.get::<_, Option<String>>(8)?,
                row.get::<_, Option<String>>(9)?,
                row.get::<_, Option<String>>(10)?,
                row.get::<_, i64>(11)?,
                row.get::<_, i64>(12)?,
            ))
        });
        if let Ok(rows) = rows {
            for row in rows.flatten() {
                let (hide, fav, hide_fav) =
                    read_hide_fav_for_var(vampath, &row.0, &row.3);
                items.push(SceneListItem {
                    var_name: row.0,
                    atom_type: row.1,
                    preview_pic: row.2,
                    scene_path: row.3,
                    is_preset: row.4 != 0,
                    is_loadable: row.5 != 0,
                    creator_name: row.6,
                    package_name: row.7,
                    meta_date: row.8,
                    var_date: row.9,
                    version: row.10,
                    installed: row.11 != 0,
                    disabled: row.12 != 0,
                    hide,
                    fav,
                    hide_fav,
                    location: "missinglink".to_string(),
                });
            }
        }
    }

    items
}

fn read_hide_fav_for_var(vampath: &StdPath, var_name: &str, scene_path: &str) -> (bool, bool, i32) {
    let scenepath = StdPath::new(scene_path)
        .parent()
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_default();
    let scenename = StdPath::new(scene_path)
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_string();
    let base = crate::paths::prefs_root(vampath)
        .join(var_name)
        .join(&scenepath);
    let pathhide = base.join(format!("{}.hide", scenename));
    let pathfav = base.join(format!("{}.fav", scenename));
    let hide = pathhide.exists();
    let fav = pathfav.exists();
    let hide_fav = if hide { -1 } else if fav { 1 } else { 0 };
    (hide, fav, hide_fav)
}

fn read_hide_fav_for_save(path: &StdPath) -> (bool, bool, i32) {
    let hide = path.with_extension(format!(
        "{}.hide",
        path.extension().and_then(|s| s.to_str()).unwrap_or("")
    ));
    let fav = path.with_extension(format!(
        "{}.fav",
        path.extension().and_then(|s| s.to_str()).unwrap_or("")
    ));
    let hide_exists = hide.exists();
    let fav_exists = fav.exists();
    let hide_fav = if hide_exists { -1 } else if fav_exists { 1 } else { 0 };
    (hide_exists, fav_exists, hide_fav)
}

fn format_system_time(time: std::time::SystemTime) -> String {
    let dt: chrono::DateTime<chrono::Local> = time.into();
    dt.format("%Y-%m-%d %H:%M:%S").to_string()
}

async fn list_creators(
    State(state): State<AppState>,
) -> Result<Json<CreatorsResponse>, (StatusCode, Json<ErrorResponse>)> {
    let _cfg = read_config(&state).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    let db_path = exe_dir().join("varManager.db");
    let db = crate::db::Db::open(&db_path).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    db.ensure_schema().map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;

    let mut stmt = db
        .connection()
        .prepare(
            "SELECT DISTINCT creatorName FROM vars WHERE creatorName IS NOT NULL AND creatorName <> '' ORDER BY creatorName",
        )
        .map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: err.to_string(),
                }),
            )
        })?;
    let rows = stmt
        .query_map([], |row| row.get::<_, String>(0))
        .map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: err.to_string(),
                }),
            )
        })?;
    let mut creators = Vec::new();
    for row in rows {
        creators.push(row.map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: err.to_string(),
                }),
            )
        })?);
    }

    Ok(Json(CreatorsResponse { creators }))
}

async fn list_packswitch(
    State(state): State<AppState>,
) -> Result<Json<PackSwitchListResponse>, (StatusCode, Json<ErrorResponse>)> {
    let (_, vampath) = crate::paths::config_paths(&state).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    let vampath = vampath.ok_or_else(|| {
        (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "vampath is required in config.json".to_string(),
            }),
        )
    })?;
    let root = crate::paths::addon_switch_root(&vampath);
    std::fs::create_dir_all(&root).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: err.to_string(),
            }),
        )
    })?;

    let mut switches = Vec::new();
    if let Ok(entries) = std::fs::read_dir(&root) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                if let Some(name) = path.file_name().and_then(|s| s.to_str()) {
                    switches.push(name.to_string());
                }
            }
        }
    }
    if !switches.iter().any(|name| name.eq_ignore_ascii_case("default")) {
        switches.push("default".to_string());
    }
    switches.sort_by(|a, b| a.to_ascii_lowercase().cmp(&b.to_ascii_lowercase()));

    let addon_path = crate::paths::addon_packages_dir(&vampath);
    let current = if let Ok(target) = crate::winfs::read_link_target(&addon_path) {
        target
            .file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("default")
            .to_string()
    } else {
        "default".to_string()
    };

    Ok(Json(PackSwitchListResponse { current, switches }))
}

async fn list_var_dependencies(
    Json(req): Json<VarDependenciesRequest>,
) -> Result<Json<VarDependenciesResponse>, (StatusCode, Json<ErrorResponse>)> {
    let mut names: Vec<String> = req
        .var_names
        .into_iter()
        .map(|name| name.trim().to_string())
        .filter(|name| !name.is_empty())
        .collect();
    names.sort();
    names.dedup();
    if names.is_empty() {
        return Ok(Json(VarDependenciesResponse { items: Vec::new() }));
    }

    let db_path = exe_dir().join("varManager.db");
    let db = crate::db::Db::open(&db_path).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err.to_string() }),
        )
    })?;
    db.ensure_schema().map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err.to_string() }),
        )
    })?;

    let placeholders = std::iter::repeat("?")
        .take(names.len())
        .collect::<Vec<_>>()
        .join(",");
    let sql = format!(
        "SELECT varName, dependency FROM dependencies WHERE varName IN ({}) ORDER BY varName, dependency",
        placeholders
    );
    let mut stmt = db.connection().prepare(&sql).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err.to_string() }),
        )
    })?;
    let rows = stmt
        .query_map(params_from_iter(names.iter()), |row| {
            Ok(VarDependencyItem {
                var_name: row.get(0)?,
                dependency: row.get(1)?,
            })
        })
        .map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse { error: err.to_string() }),
            )
        })?;
    let mut items = Vec::new();
    for row in rows {
        items.push(row.map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse { error: err.to_string() }),
            )
        })?);
    }
    Ok(Json(VarDependenciesResponse { items }))
}

async fn list_var_previews(
    Json(req): Json<VarPreviewsRequest>,
) -> Result<Json<VarPreviewsResponse>, (StatusCode, Json<ErrorResponse>)> {
    let mut names: Vec<String> = req
        .var_names
        .into_iter()
        .map(|name| name.trim().to_string())
        .filter(|name| !name.is_empty())
        .collect();
    names.sort();
    names.dedup();
    if names.is_empty() {
        return Ok(Json(VarPreviewsResponse { items: Vec::new() }));
    }

    let db_path = exe_dir().join("varManager.db");
    let db = crate::db::Db::open(&db_path).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err.to_string() }),
        )
    })?;
    db.ensure_schema().map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err.to_string() }),
        )
    })?;

    let placeholders = std::iter::repeat("?")
        .take(names.len())
        .collect::<Vec<_>>()
        .join(",");
    let sql = format!(
        "SELECT varName, atomType, previewPic, scenePath, isPreset, isLoadable \
         FROM scenes WHERE varName IN ({}) AND previewPic IS NOT NULL AND previewPic != '' \
         ORDER BY varName, atomType, scenePath",
        placeholders
    );
    let mut stmt = db.connection().prepare(&sql).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err.to_string() }),
        )
    })?;
    let rows = stmt
        .query_map(params_from_iter(names.iter()), |row| {
            Ok(VarPreviewItem {
                var_name: row.get(0)?,
                atom_type: row.get(1)?,
                preview_pic: row.get(2)?,
                scene_path: row.get(3)?,
                is_preset: row.get::<_, i64>(4)? != 0,
                is_loadable: row.get::<_, i64>(5)? != 0,
            })
        })
        .map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse { error: err.to_string() }),
            )
        })?;
    let mut items = Vec::new();
    for row in rows {
        items.push(row.map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse { error: err.to_string() }),
            )
        })?);
    }
    Ok(Json(VarPreviewsResponse { items }))
}

async fn list_dependents(
    State(state): State<AppState>,
    Query(query): Query<DependentsQuery>,
) -> Result<Json<DependentsResponse>, (StatusCode, Json<ErrorResponse>)> {
    let db_path = exe_dir().join("varManager.db");
    let db = crate::db::Db::open(&db_path).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    db.ensure_schema().map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;

    let mut dependents = Vec::new();
    let mut stmt = db
        .connection()
        .prepare("SELECT varName FROM dependencies WHERE dependency = ?1")
        .map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: err.to_string(),
                }),
            )
        })?;
    let rows = stmt
        .query_map([&query.name], |row| row.get::<_, String>(0))
        .map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: err.to_string(),
                }),
            )
        })?;
    for row in rows {
        if let Ok(value) = row {
            dependents.push(value);
        }
    }

    let mut dependent_saves = Vec::new();
    let mut stmt = db
        .connection()
        .prepare("SELECT SavePath FROM savedepens WHERE dependency = ?1")
        .map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: err.to_string(),
                }),
            )
        })?;
    let rows = stmt
        .query_map([&query.name], |row| row.get::<_, String>(0))
        .map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: err.to_string(),
                }),
            )
        })?;
    for row in rows {
        if let Ok(value) = row {
            dependent_saves.push(value);
        }
    }

    dependents.sort();
    dependents.dedup();
    dependent_saves.sort();
    dependent_saves.dedup();

    Ok(Json(DependentsResponse {
        dependents,
        dependent_saves,
    }))
}

async fn list_analysis_atoms(
    State(state): State<AppState>,
    Query(query): Query<AnalysisAtomsQuery>,
) -> Result<Json<AnalysisAtomsResponse>, (StatusCode, Json<ErrorResponse>)> {
    let (atoms, person_atoms) =
        scenes::list_analysis_atoms(&state, &query.var_name, &query.entry_name).map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse { error: err }),
            )
        })?;
    Ok(Json(AnalysisAtomsResponse {
        atoms,
        person_atoms,
    }))
}

async fn list_saves_tree(
    State(state): State<AppState>,
) -> Result<Json<SavesTreeResponse>, (StatusCode, Json<ErrorResponse>)> {
    let (_, vampath) = crate::paths::config_paths(&state).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    let vampath = vampath.ok_or_else(|| {
        (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse {
                error: "vampath is required in config.json".to_string(),
            }),
        )
    })?;

    let groups = vec![
        ("scenes", "[Scenes]: ./Saves/scene", vampath.join("Saves").join("scene"), "json"),
        (
            "appearance",
            "[Appearance]: ./Saves/Person/appearance",
            vampath.join("Saves").join("Person").join("appearance"),
            "json",
        ),
        (
            "presets",
            "[Appearance Presets]: ./Custom/Atom/Person/Appearance",
            vampath.join("Custom").join("Atom").join("Person").join("Appearance"),
            "vap",
        ),
    ];

    let mut response_groups = Vec::new();
    for (id, title, root, ext) in groups {
        let mut items = Vec::new();
        if root.exists() {
            for entry in WalkDir::new(&root)
                .into_iter()
                .filter_map(Result::ok)
                .filter(|e| e.file_type().is_file())
            {
                let path = entry.path();
                if path.extension().and_then(|s| s.to_str()) != Some(ext) {
                    continue;
                }
                let rel = path.strip_prefix(&vampath).unwrap_or(path);
                let rel_str = rel.to_string_lossy().replace('\\', "/");
                let name = path
                    .file_name()
                    .and_then(|s| s.to_str())
                    .unwrap_or("")
                    .to_string();
                let preview_path = path.with_extension("jpg");
                let preview = if preview_path.exists() {
                    Some(
                        preview_path
                            .strip_prefix(&vampath)
                            .unwrap_or(&preview_path)
                            .to_string_lossy()
                            .replace('\\', "/"),
                    )
                } else {
                    None
                };
                items.push(SavesTreeItem {
                    path: rel_str,
                    name,
                    preview,
                    modified: None,
                });
            }
        }
        response_groups.push(SavesTreeGroup {
            id: id.to_string(),
            title: title.to_string(),
            items,
        });
    }

    Ok(Json(SavesTreeResponse {
        groups: response_groups,
    }))
}

async fn get_stats(
    State(state): State<AppState>,
) -> Result<Json<StatsResponse>, (StatusCode, Json<ErrorResponse>)> {
    let _cfg = read_config(&state).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    let db_path = exe_dir().join("varManager.db");
    let db = crate::db::Db::open(&db_path).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    db.ensure_schema().map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;

    let vars_total: u64 = db
        .connection()
        .query_row("SELECT COUNT(1) FROM vars", [], |row| row.get::<_, i64>(0))
        .unwrap_or(0) as u64;
    let vars_installed: u64 = db
        .connection()
        .query_row(
            "SELECT COUNT(1) FROM installStatus WHERE installed = 1",
            [],
            |row| row.get::<_, i64>(0),
        )
        .unwrap_or(0) as u64;
    let vars_disabled: u64 = db
        .connection()
        .query_row(
            "SELECT COUNT(1) FROM installStatus WHERE disabled = 1",
            [],
            |row| row.get::<_, i64>(0),
        )
        .unwrap_or(0) as u64;
    let scenes_total: u64 = db
        .connection()
        .query_row("SELECT COUNT(1) FROM scenes", [], |row| row.get::<_, i64>(0))
        .unwrap_or(0) as u64;
    let missing_deps: u64 = db
        .connection()
        .query_row(
            "SELECT COUNT(DISTINCT d.dependency)
             FROM dependencies d
             LEFT JOIN vars v ON d.dependency = v.varName
             WHERE v.varName IS NULL",
            [],
            |row| row.get::<_, i64>(0),
        )
        .unwrap_or(0) as u64;

    Ok(Json(StatsResponse {
        vars_total,
        vars_installed,
        vars_disabled,
        scenes_total,
        missing_deps,
    }))
}

async fn get_preview(
    State(state): State<AppState>,
    Query(query): Query<PreviewQuery>,
) -> Result<Response, (StatusCode, Json<ErrorResponse>)> {
    let cfg = read_config(&state).map_err(|err| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse { error: err }),
        )
    })?;
    let base = match query.root.as_str() {
        "varspath" => cfg
            .varspath
            .as_ref()
            .map(PathBuf::from)
            .ok_or_else(|| "varspath not set".to_string()),
        "vampath" => cfg
            .vampath
            .as_ref()
            .map(PathBuf::from)
            .ok_or_else(|| "vampath not set".to_string()),
        "cache" => Ok(exe_dir().join("Cache")),
        _ => Err("invalid preview root".to_string()),
    }
    .map_err(|err| {
        (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse { error: err }),
        )
    })?;

    let joined = safe_join(&base, &query.path).map_err(|err| {
        (
            StatusCode::BAD_REQUEST,
            Json(ErrorResponse { error: err }),
        )
    })?;

    let bytes = std::fs::read(&joined).map_err(|err| {
        (
            StatusCode::NOT_FOUND,
            Json(ErrorResponse {
                error: err.to_string(),
            }),
        )
    })?;
    let content_type = match joined.extension().and_then(|s| s.to_str()) {
        Some(ext) if ext.eq_ignore_ascii_case("png") => "image/png",
        Some(ext) if ext.eq_ignore_ascii_case("jpg") || ext.eq_ignore_ascii_case("jpeg") => "image/jpeg",
        Some(ext) if ext.eq_ignore_ascii_case("gif") => "image/gif",
        _ => "application/octet-stream",
    };
    let resp = Response::builder()
        .status(StatusCode::OK)
        .header(header::CONTENT_TYPE, content_type)
        .body(Body::from(bytes))
        .map_err(|err| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: err.to_string(),
                }),
            )
        })?;
    Ok(resp)
}

fn safe_join(base: &PathBuf, relative: &str) -> Result<PathBuf, String> {
    let rel = PathBuf::from(relative);
    for comp in rel.components() {
        match comp {
            Component::ParentDir | Component::Prefix(_) | Component::RootDir => {
                return Err("invalid preview path".to_string())
            }
            Component::CurDir | Component::Normal(_) => {}
        }
    }
    Ok(base.join(rel))
}

fn list_dependencies_with_status(
    conn: &rusqlite::Connection,
    var_name: &str,
) -> Result<Vec<DependencyStatus>, String> {
    let mut stmt = conn
        .prepare("SELECT dependency FROM dependencies WHERE varName = ?1")
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map([var_name], |row| row.get::<_, Option<String>>(0))
        .map_err(|err| err.to_string())?;
    let mut result = Vec::new();
    for row in rows {
        if let Some(dep) = row.map_err(|err| err.to_string())? {
            let mut resolved = crate::var_logic::resolve_var_exist_name(conn, &dep)?;
            let mut closest = false;
            if resolved.ends_with('$') {
                closest = true;
                resolved = resolved.trim_end_matches('$').to_string();
            }
            let missing = resolved == "missing";
            result.push(DependencyStatus {
                name: dep,
                resolved,
                missing,
                closest,
            });
        }
    }
    Ok(result)
}

fn list_dependents_conn(conn: &rusqlite::Connection, var_name: &str) -> Result<Vec<String>, String> {
    let mut names = Vec::new();
    let targets = dependency_targets(conn, var_name)?;
    let mut stmt = conn
        .prepare("SELECT varName FROM dependencies WHERE dependency = ?1")
        .map_err(|err| err.to_string())?;
    for dep in targets {
        let rows = stmt
            .query_map([dep], |row| row.get::<_, Option<String>>(0))
            .map_err(|err| err.to_string())?;
        for row in rows {
            if let Some(name) = row.map_err(|err| err.to_string())? {
                names.push(name);
            }
        }
    }
    names.sort();
    names.dedup();
    Ok(names)
}

fn list_dependent_saves(
    conn: &rusqlite::Connection,
    var_name: &str,
) -> Result<Vec<String>, String> {
    let mut names = Vec::new();
    let targets = dependency_targets(conn, var_name)?;
    let mut stmt = conn
        .prepare("SELECT SavePath FROM savedepens WHERE dependency = ?1")
        .map_err(|err| err.to_string())?;
    for dep in targets {
        let rows = stmt
            .query_map([dep], |row| row.get::<_, Option<String>>(0))
            .map_err(|err| err.to_string())?;
        for row in rows {
            if let Some(name) = row.map_err(|err| err.to_string())? {
                names.push(name);
            }
        }
    }
    names.sort();
    names.dedup();
    Ok(names)
}

fn list_var_scenes(
    conn: &rusqlite::Connection,
    var_name: &str,
) -> Result<Vec<ScenePreviewItem>, String> {
    let mut stmt = conn
        .prepare(
            "SELECT atomType, previewPic, scenePath, isPreset, isLoadable FROM scenes WHERE varName = ?1",
        )
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map([var_name], |row| {
            Ok(ScenePreviewItem {
                atom_type: row.get(0)?,
                preview_pic: row.get(1)?,
                scene_path: row.get(2)?,
                is_preset: row.get::<_, i64>(3)? != 0,
                is_loadable: row.get::<_, i64>(4)? != 0,
            })
        })
        .map_err(|err| err.to_string())?;
    let mut items = Vec::new();
    for row in rows {
        items.push(row.map_err(|err| err.to_string())?);
    }
    Ok(items)
}

fn dependency_targets(conn: &rusqlite::Connection, var_name: &str) -> Result<Vec<String>, String> {
    let parts: Vec<&str> = var_name.split('.').collect();
    if parts.len() != 3 {
        return Ok(vec![var_name.to_string()]);
    }
    let is_latest = is_var_latest(conn, parts[0], parts[1], parts[2])?;
    let mut targets = vec![var_name.to_string()];
    if is_latest {
        targets.push(format!("{}.{}.latest", parts[0], parts[1]));
    }
    Ok(targets)
}

fn is_var_latest(
    conn: &rusqlite::Connection,
    creator: &str,
    package: &str,
    version: &str,
) -> Result<bool, String> {
    let current: i64 = match version.parse() {
        Ok(ver) => ver,
        Err(_) => return Ok(true),
    };
    let mut stmt = conn
        .prepare("SELECT version FROM vars WHERE creatorName = ?1 AND packageName = ?2")
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map([creator, package], |row| row.get::<_, Option<String>>(0))
        .map_err(|err| err.to_string())?;
    let mut max_ver: Option<i64> = None;
    for row in rows {
        if let Some(ver) = row.map_err(|err| err.to_string())? {
            if let Ok(parsed) = ver.parse::<i64>() {
                if max_ver.map(|cur| parsed > cur).unwrap_or(true) {
                    max_ver = Some(parsed);
                }
            }
        }
    }
    Ok(max_ver.map(|max| current >= max).unwrap_or(true))
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
    let job_tx = state.job_tx.clone();
    tokio::spawn(async move {
        let semaphore = match state.job_semaphore.read() {
            Ok(guard) => guard.clone(),
            Err(err) => err.into_inner().clone(),
        };
        let permit = semaphore.acquire().await;
        if permit.is_err() {
            send_job_failed(&job_tx, id, "failed to acquire job slot".to_string()).await;
            return;
        }
        let _permit = permit.unwrap();
        send_job_started(&job_tx, id, format!("job started: {}", kind)).await;

        // Create JobReporter for this job
        let reporter = JobReporter::new(id, kind.clone(), job_tx.clone());

        if let Err(err) = run_job(&state, &reporter, &kind, args).await {
            send_job_failed(&job_tx, id, err).await;
            return;
        }
        send_job_finished(&job_tx, id, "job completed".to_string()).await;
    });
}

async fn run_job(
    state: &AppState,
    reporter: &JobReporter,
    kind: &str,
    args: Option<Value>,
) -> Result<(), String> {
    match kind {
        "noop" => {
            let _args = args;
            for step in 0..=5 {
                let progress = (step * 20) as u8;
                reporter.progress(progress);
                reporter.log(format!("noop step {}/5", step));
                tokio::time::sleep(std::time::Duration::from_millis(200)).await;
            }
            Ok(())
        }
        "update_db" => update_db::run_update_db_job(state.clone(), reporter.clone()).await,
        "missing_deps" => missing_deps::run_missing_deps_job(state.clone(), reporter.clone(), args).await,
        "rebuild_links" => links::run_rebuild_links_job(state.clone(), reporter.clone(), args).await,
        "links_move" => links::run_move_links_job(state.clone(), reporter.clone(), args).await,
        "links_missing_create" => links::run_missing_links_create_job(state.clone(), reporter.clone(), args).await,
        "install_vars" => vars_jobs::run_install_vars_job(state.clone(), reporter.clone(), args).await,
        "preview_uninstall" => vars_jobs::run_preview_uninstall_job(state.clone(), reporter.clone(), args).await,
        "uninstall_vars" => vars_jobs::run_uninstall_vars_job(state.clone(), reporter.clone(), args).await,
        "delete_vars" => vars_jobs::run_delete_vars_job(state.clone(), reporter.clone(), args).await,
        "vars_export_installed" => vars_misc::run_export_installed_job(state.clone(), reporter.clone(), args).await,
        "vars_install_batch" => vars_misc::run_install_batch_job(state.clone(), reporter.clone(), args).await,
        "vars_toggle_install" => vars_misc::run_toggle_install_job(state.clone(), reporter.clone(), args).await,
        "vars_locate" => vars_misc::run_locate_job(state.clone(), reporter.clone(), args).await,
        "refresh_install_status" => vars_misc::run_refresh_install_status_job(state.clone(), reporter.clone(), args).await,
        "saves_deps" => deps_jobs::run_saves_deps_job(state.clone(), reporter.clone(), args).await,
        "log_deps" => deps_jobs::run_log_deps_job(state.clone(), reporter.clone(), args).await,
        "fix_previews" => preview_jobs::run_fix_previews_job(state.clone(), reporter.clone(), args).await,
        "stale_vars" => stale_jobs::run_stale_vars_job(state.clone(), reporter.clone(), args).await,
        "old_version_vars" => stale_jobs::run_old_version_vars_job(state.clone(), reporter.clone(), args).await,
        "packswitch_add" => packswitch::run_packswitch_add_job(state.clone(), reporter.clone(), args).await,
        "packswitch_delete" => packswitch::run_packswitch_delete_job(state.clone(), reporter.clone(), args).await,
        "packswitch_rename" => packswitch::run_packswitch_rename_job(state.clone(), reporter.clone(), args).await,
        "packswitch_set" => packswitch::run_packswitch_set_job(state.clone(), reporter.clone(), args).await,
        "hub_missing_scan" => hub::run_hub_missing_scan_job(state.clone(), reporter.clone(), args).await,
        "hub_updates_scan" => hub::run_hub_updates_scan_job(state.clone(), reporter.clone(), args).await,
        "hub_download_all" => hub::run_hub_download_all_job(state.clone(), reporter.clone(), args).await,
        "hub_info" => hub::run_hub_info_job(state.clone(), reporter.clone()).await,
        "hub_resources" => hub::run_hub_resources_job(state.clone(), reporter.clone(), args).await,
        "hub_resource_detail" => hub::run_hub_resource_detail_job(state.clone(), reporter.clone(), args).await,
        "hub_find_packages" => hub::run_hub_find_packages_job(state.clone(), reporter.clone(), args).await,
        "scene_load" => scenes::run_scene_load_job(state.clone(), reporter.clone(), args).await,
        "scene_analyze" => scenes::run_scene_analyze_job(state.clone(), reporter.clone(), args).await,
        "scene_preset_look" => scenes::run_scene_preset_look_job(state.clone(), reporter.clone(), args).await,
        "scene_preset_plugin" => scenes::run_scene_preset_plugin_job(state.clone(), reporter.clone(), args).await,
        "scene_preset_pose" => scenes::run_scene_preset_pose_job(state.clone(), reporter.clone(), args).await,
        "scene_preset_animation" => scenes::run_scene_preset_animation_job(state.clone(), reporter.clone(), args).await,
        "scene_preset_scene" => scenes::run_scene_preset_scene_job(state.clone(), reporter.clone(), args).await,
        "scene_add_atoms" => scenes::run_scene_add_atoms_job(state.clone(), reporter.clone(), args).await,
        "scene_add_subscene" => scenes::run_scene_add_subscene_job(state.clone(), reporter.clone(), args).await,
        "scene_hide" => scenes::run_scene_hide_job(state.clone(), reporter.clone(), args).await,
        "scene_fav" => scenes::run_scene_fav_job(state.clone(), reporter.clone(), args).await,
        "scene_unhide" => scenes::run_scene_unhide_job(state.clone(), reporter.clone(), args).await,
        "scene_unfav" => scenes::run_scene_unfav_job(state.clone(), reporter.clone(), args).await,
        "cache_clear" => scenes::run_cache_clear_job(state.clone(), reporter.clone(), args).await,
        "vam_start" => system_jobs::run_vam_start_job(state.clone(), reporter.clone(), args).await,
        "rescan_packages" => system_jobs::run_rescan_packages_job(state.clone(), reporter.clone(), args).await,
        "open_url" => system_jobs::run_open_url_job(state.clone(), reporter.clone(), args).await,
        _ => Err(format!("job kind not implemented: {}", kind)),
    }
}
