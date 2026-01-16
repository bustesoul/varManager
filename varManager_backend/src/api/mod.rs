use axum::{
    body::Body,
    extract::{Path, Query, State},
    http::{header, StatusCode},
    response::{IntoResponse, Response},
    Json,
};
use sqlx::{QueryBuilder, Row, SqlitePool};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{
    collections::HashMap,
    path::{Component, Path as StdPath, PathBuf},
    sync::atomic::Ordering,
    sync::Arc,
};
use tokio::sync::Semaphore;
use walkdir::WalkDir;

use crate::jobs::job_channel::{
    min_job_log_level, JobLogsResponse, JobResultResponse, JobState, JobStatus, JobView,
};
use crate::infra::download_manager::{DownloadAction, DownloadEnqueueItem, DownloadListResponse};
use crate::app::{app_root, data_dir, AppState, APP_VERSION, Config};
use crate::infra::db;
use crate::services::image_cache::{
    CacheStats, ImageCacheError, ImageSource, ResolvedImageSource,
};
use crate::{jobs, scenes};

#[derive(Deserialize)]
pub(crate) struct StartJobRequest {
    kind: String,
    #[serde(default)]
    args: Option<Value>,
}

#[derive(Serialize)]
pub(crate) struct StartJobResponse {
    id: u64,
    status: JobStatus,
}

#[derive(Deserialize)]
pub(crate) struct JobLogsQuery {
    from: Option<usize>,
}

#[derive(Deserialize)]
pub(crate) struct VarsQuery {
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
pub(crate) struct CreatorsQuery {
    q: Option<String>,
    offset: Option<u32>,
    limit: Option<u32>,
}

#[derive(Deserialize)]
pub(crate) struct ScenesQuery {
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
pub(crate) struct DependentsQuery {
    name: String,
}

#[derive(Deserialize)]
pub(crate) struct AnalysisAtomsQuery {
    var_name: String,
    entry_name: String,
}

#[derive(Deserialize)]
pub(crate) struct ResolveVarsRequest {
    names: Vec<String>,
}

#[derive(Deserialize)]
pub(crate) struct ValidateOutputRequest {
    path: String,
}

#[derive(Serialize)]
pub(crate) struct ValidateOutputResponse {
    ok: bool,
    reason: Option<String>,
}

#[derive(Deserialize, Serialize)]
pub(crate) struct MissingMapItem {
    missing_var: String,
    dest_var: String,
}

#[derive(Deserialize)]
pub(crate) struct MissingMapSaveRequest {
    path: String,
    links: Vec<MissingMapItem>,
}

#[derive(Deserialize)]
pub(crate) struct MissingMapLoadRequest {
    path: String,
}

#[derive(Serialize)]
pub(crate) struct MissingMapResponse {
    links: Vec<MissingMapItem>,
}

#[derive(Deserialize)]
pub(crate) struct VarDependenciesRequest {
    var_names: Vec<String>,
}

#[derive(Serialize)]
pub(crate) struct VarDependencyItem {
    var_name: String,
    dependency: String,
}

#[derive(Serialize)]
pub(crate) struct VarDependenciesResponse {
    items: Vec<VarDependencyItem>,
}

#[derive(Deserialize)]
pub(crate) struct VarPreviewsRequest {
    var_names: Vec<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
pub(crate) struct VarPreviewItem {
    var_name: String,
    atom_type: String,
    preview_pic: Option<String>,
    scene_path: String,
    is_preset: bool,
    is_loadable: bool,
    installed: bool,
}

#[derive(Serialize)]
pub(crate) struct VarPreviewsResponse {
    items: Vec<VarPreviewItem>,
}

#[derive(Deserialize)]
pub(crate) struct PreviewQuery {
    source: Option<String>,
    url: Option<String>,
    root: Option<String>,
    path: Option<String>,
}

#[derive(Deserialize)]
pub(crate) struct HubOptionsQuery {
    kind: String,
    q: Option<String>,
    offset: Option<u32>,
    limit: Option<u32>,
    refresh: Option<bool>,
}

#[derive(Serialize)]
pub(crate) struct HubOptionsResponse {
    items: Vec<String>,
    total: usize,
}

#[derive(Deserialize)]
pub(crate) struct UpdateConfigRequest {
    listen_host: Option<String>,
    listen_port: Option<u16>,
    log_level: Option<String>,
    job_concurrency: Option<usize>,
    varspath: Option<String>,
    vampath: Option<String>,
    vam_exec: Option<String>,
    downloader_save_path: Option<String>,
    image_cache: Option<crate::app::ImageCacheConfig>,
    proxy_mode: Option<crate::app::ProxyMode>,
    proxy: Option<crate::app::ProxyConfig>,
    ui_theme: Option<String>,
    ui_language: Option<String>,
}

#[derive(Deserialize)]
pub(crate) struct DeleteCacheEntryQuery {
    key: String,
}

#[derive(Serialize)]
pub(crate) struct ErrorResponse {
    error: String,
}

#[derive(Debug)]
pub(crate) struct ApiError {
    status: StatusCode,
    message: String,
}

impl ApiError {
    fn new(status: StatusCode, message: impl Into<String>) -> Self {
        Self {
            status,
            message: message.into(),
        }
    }

    fn bad_request(message: impl Into<String>) -> Self {
        Self::new(StatusCode::BAD_REQUEST, message)
    }

    fn not_found(message: impl Into<String>) -> Self {
        Self::new(StatusCode::NOT_FOUND, message)
    }

    fn conflict(message: impl Into<String>) -> Self {
        Self::new(StatusCode::CONFLICT, message)
    }

    fn internal(message: impl Into<String>) -> Self {
        Self::new(StatusCode::INTERNAL_SERVER_ERROR, message)
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        (
            self.status,
            Json(ErrorResponse {
                error: self.message,
            }),
        )
            .into_response()
    }
}

type ApiResult<T> = Result<T, ApiError>;

fn internal_error<E: ToString>(err: E) -> ApiError {
    ApiError::internal(err.to_string())
}

fn bad_request_error<E: ToString>(err: E) -> ApiError {
    ApiError::bad_request(err.to_string())
}

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
pub(crate) struct VarListItem {
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
pub(crate) struct VarsListResponse {
    items: Vec<VarListItem>,
    page: u32,
    per_page: u32,
    total: u64,
}

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
pub(crate) struct SceneListItem {
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
pub(crate) struct ScenesListResponse {
    items: Vec<SceneListItem>,
    page: u32,
    per_page: u32,
    total: u64,
}

#[derive(Serialize)]
pub(crate) struct CreatorsResponse {
    creators: Vec<String>,
}

#[derive(Serialize)]
pub(crate) struct PackSwitchListResponse {
    current: String,
    switches: Vec<String>,
}

#[derive(Serialize)]
pub(crate) struct DependentsResponse {
    dependents: Vec<String>,
    dependent_saves: Vec<String>,
}

#[derive(Serialize)]
pub(crate) struct AnalysisAtomsResponse {
    atoms: Vec<scenes::AtomTreeNode>,
    person_atoms: Vec<String>,
}

#[derive(Serialize)]
pub(crate) struct SavesTreeItem {
    path: String,
    name: String,
    preview: Option<String>,
    modified: Option<String>,
}

#[derive(Serialize)]
pub(crate) struct SavesTreeGroup {
    id: String,
    title: String,
    items: Vec<SavesTreeItem>,
}

#[derive(Serialize)]
pub(crate) struct SavesTreeResponse {
    groups: Vec<SavesTreeGroup>,
}

#[derive(Serialize)]
pub(crate) struct ResolveVarsResponse {
    resolved: HashMap<String, String>,
}

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
pub(crate) struct StatsResponse {
    vars_total: u64,
    vars_installed: u64,
    vars_disabled: u64,
    scenes_total: u64,
    missing_deps: u64,
}

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
pub(crate) struct DependencyStatus {
    name: String,
    resolved: String,
    missing: bool,
    closest: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
pub(crate) struct ScenePreviewItem {
    atom_type: String,
    preview_pic: Option<String>,
    scene_path: String,
    is_preset: bool,
    is_loadable: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "snake_case")]
pub(crate) struct VarDetailResponse {
    var_info: VarListItem,
    dependencies: Vec<DependencyStatus>,
    dependents: Vec<String>,
    dependent_saves: Vec<String>,
    scenes: Vec<ScenePreviewItem>,
}

pub async fn health() -> impl IntoResponse {
    Json(json!({ "status": "ok", "version": APP_VERSION }))
}

pub async fn get_config(State(state): State<AppState>) -> ApiResult<Json<Config>> {
    let cfg = read_config(&state).map_err(ApiError::internal)?;
    Ok(Json(cfg))
}

pub async fn shutdown(State(state): State<AppState>) -> impl IntoResponse {
    crate::app::trigger_shutdown(&state).await;
    Json(json!({ "status": "shutting_down" }))
}

pub async fn start_job(
    State(state): State<AppState>,
    Json(req): Json<StartJobRequest>,
) -> ApiResult<Json<StartJobResponse>> {
    let kind = req.kind.trim();
    if kind.is_empty() {
        return Err(ApiError::bad_request("kind is required"));
    }

    let id = state.job_counter.fetch_add(1, Ordering::SeqCst);
    let job = JobState::new(id, kind.to_string());
    {
        let mut jobs = state.jobs.write().await;
        jobs.insert(id, job);
    }

    jobs::spawn_job(state.clone(), id, kind.to_string(), req.args);

    Ok(Json(StartJobResponse {
        id,
        status: JobStatus::Queued,
    }))
}

pub async fn get_job(
    State(state): State<AppState>,
    Path(id): Path<u64>,
) -> ApiResult<Json<JobView>> {
    let jobs = state.jobs.read().await;
    let job = jobs
        .get(&id)
        .ok_or_else(|| ApiError::not_found("job not found"))?;
    Ok(Json(JobView::from(job)))
}

pub async fn get_job_logs(
    State(state): State<AppState>,
    Path(id): Path<u64>,
    Query(query): Query<JobLogsQuery>,
) -> ApiResult<Json<JobLogsResponse>> {
    let jobs = state.jobs.read().await;
    let job = jobs
        .get(&id)
        .ok_or_else(|| ApiError::not_found("job not found"))?;

    let cfg = read_config(&state).map_err(ApiError::internal)?;
    let min_level = min_job_log_level(&cfg.log_level);

    let request_from = query.from.unwrap_or(job.log_offset);
    let dropped = request_from < job.log_offset;
    let from = if dropped { job.log_offset } else { request_from };
    let start = from.saturating_sub(job.log_offset);
    let entries = job
        .logs
        .iter()
        .skip(start)
        .filter(|entry| entry.level.severity() >= min_level.severity())
        .cloned()
        .collect();
    let next = job.log_offset + job.logs.len();

    Ok(Json(JobLogsResponse {
        id,
        from,
        next,
        dropped,
        entries,
    }))
}

pub async fn get_job_result(
    State(state): State<AppState>,
    Path(id): Path<u64>,
) -> ApiResult<Json<JobResultResponse>> {
    let jobs = state.jobs.read().await;
    let job = jobs
        .get(&id)
        .ok_or_else(|| ApiError::not_found("job not found"))?;

    let result = job
        .result
        .clone()
        .ok_or_else(|| ApiError::conflict("job result not ready"))?;

    Ok(Json(JobResultResponse { id, result }))
}

#[derive(Deserialize)]
pub struct DownloadEnqueueItemRequest {
    pub url: String,
    pub name: Option<String>,
    pub size: Option<u64>,
}

#[derive(Deserialize)]
pub struct DownloadEnqueueRequest {
    pub urls: Option<Vec<String>>,
    pub items: Option<Vec<DownloadEnqueueItemRequest>>,
}

#[derive(Deserialize)]
pub struct DownloadActionRequest {
    pub action: String,
    pub ids: Vec<i64>,
}

pub async fn list_downloads(
    State(state): State<AppState>,
) -> ApiResult<Json<DownloadListResponse>> {
    let data = state
        .download_manager
        .list_downloads()
        .await
        .map_err(ApiError::internal)?;
    Ok(Json(data))
}

pub async fn enqueue_downloads(
    State(state): State<AppState>,
    Json(req): Json<DownloadEnqueueRequest>,
) -> ApiResult<Json<Value>> {
    let mut items = Vec::new();
    if let Some(urls) = req.urls {
        for url in urls {
            items.push(DownloadEnqueueItem {
                url,
                name: None,
                size: None,
            });
        }
    }
    if let Some(extra) = req.items {
        for item in extra {
            items.push(DownloadEnqueueItem {
                url: item.url,
                name: item.name,
                size: item.size,
            });
        }
    }
    if items.is_empty() {
        return Err(ApiError::bad_request("download urls required"));
    }
    let added = state
        .download_manager
        .enqueue_items(items)
        .await
        .map_err(ApiError::internal)?;
    Ok(Json(json!({ "added": added })))
}

pub async fn download_actions(
    State(state): State<AppState>,
    Json(req): Json<DownloadActionRequest>,
) -> ApiResult<Json<Value>> {
    let action = parse_download_action(&req.action)
        .ok_or_else(|| ApiError::bad_request("invalid download action"))?;
    state
        .download_manager
        .apply_action(action, req.ids)
        .await
        .map_err(ApiError::internal)?;
    Ok(Json(json!({ "status": "ok" })))
}

fn parse_download_action(raw: &str) -> Option<DownloadAction> {
    match raw.trim().to_ascii_lowercase().as_str() {
        "pause" => Some(DownloadAction::Pause),
        "resume" => Some(DownloadAction::Resume),
        "remove" => Some(DownloadAction::Remove),
        "delete" => Some(DownloadAction::Delete),
        _ => None,
    }
}

fn read_config(state: &AppState) -> Result<Config, String> {
    let guard = state
        .config
        .read()
        .map_err(|_| "config lock poisoned".to_string())?;
    Ok(guard.clone())
}

fn config_path() -> PathBuf {
    app_root().join("config.json")
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

/// Normalize vam_exec: if user provides a full path, extract just the filename.
/// The system always combines vampath + vam_exec, so only the filename is needed.
fn normalize_vam_exec(value: Option<String>) -> Option<String> {
    normalize_optional(value).map(|s| {
        let path = std::path::Path::new(&s);
        if path.is_absolute() || s.contains('\\') || s.contains('/') {
            // Extract filename from path
            path.file_name()
                .and_then(|n| n.to_str())
                .map(|n| n.to_string())
                .unwrap_or(s)
        } else {
            s
        }
    })
}

fn normalize_proxy(mut proxy: crate::app::ProxyConfig) -> crate::app::ProxyConfig {
    proxy.host = proxy.host.trim().to_string();
    proxy.username = normalize_optional(proxy.username);
    proxy.password = normalize_optional(proxy.password);
    if proxy.host.is_empty() || proxy.port == 0 {
        proxy.host.clear();
        proxy.port = 0;
        proxy.username = None;
        proxy.password = None;
    }
    proxy
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
        next.vam_exec = normalize_vam_exec(req.vam_exec);
    }
    if req.downloader_save_path.is_some() {
        next.downloader_save_path = normalize_optional(req.downloader_save_path);
    }
    if let Some(image_cache) = req.image_cache {
        next.image_cache = image_cache;
    }
    if let Some(proxy_mode) = req.proxy_mode {
        next.proxy_mode = proxy_mode;
    }
    if let Some(proxy) = req.proxy {
        next.proxy = normalize_proxy(proxy);
    }
    if req.ui_theme.is_some() {
        next.ui_theme = normalize_optional(req.ui_theme);
    }
    if req.ui_language.is_some() {
        next.ui_language = normalize_optional(req.ui_language);
    }
    Ok(next)
}

pub async fn update_config(
    State(state): State<AppState>,
    Json(req): Json<UpdateConfigRequest>,
) -> ApiResult<Json<Config>> {
    let current = read_config(&state).map_err(ApiError::internal)?;
    let next = apply_config_update(&current, req).map_err(ApiError::bad_request)?;

    let path = config_path();
    let contents =
        serde_json::to_string_pretty(&next).map_err(|err| ApiError::internal(err.to_string()))?;
    std::fs::write(&path, contents).map_err(|err| ApiError::internal(err.to_string()))?;

    {
        let mut guard = state
            .config
            .write()
            .map_err(|_| ApiError::internal("config lock poisoned"))?;
        *guard = next.clone();
    }
    {
        let mut guard = state
            .job_semaphore
            .write()
            .map_err(|_| ApiError::internal("semaphore lock poisoned"))?;
        *guard = Arc::new(Semaphore::new(next.job_concurrency));
    }

    Ok(Json(next))
}

pub async fn list_vars(
    State(state): State<AppState>,
    Query(query): Query<VarsQuery>,
) -> ApiResult<Json<VarsListResponse>> {
    let _cfg = read_config(&state).map_err(internal_error)?;
    let pool = &state.db_pool;

    let page = query.page.unwrap_or(1).max(1);
    let per_page = query.per_page.unwrap_or(50).clamp(1, 200);
    let offset = ((page - 1) * per_page) as i64;

    enum BindValue {
        Text(String),
        Int(i64),
        Float(f64),
    }

    let mut conditions = Vec::new();
    let mut params: Vec<BindValue> = Vec::new();

    if let Some(creator) = query.creator.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty()) {
        conditions.push("v.creatorName = ?".to_string());
        params.push(BindValue::Text(creator.to_string()));
    }
    if let Some(package) = query.package.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty()) {
        conditions.push("v.packageName LIKE ?".to_string());
        params.push(BindValue::Text(format!("%{}%", package)));
    }
    if let Some(version) = query.version.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty()) {
        conditions.push("v.version LIKE ?".to_string());
        params.push(BindValue::Text(format!("%{}%", version)));
    }
    if let Some(search) = query.search.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty()) {
        conditions.push("(v.varName LIKE ? OR v.packageName LIKE ?)".to_string());
        let like = format!("%{}%", search);
        params.push(BindValue::Text(like.clone()));
        params.push(BindValue::Text(like));
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
        params.push(BindValue::Float(min_size));
    }
    if let Some(max_size) = query.max_size {
        conditions.push("COALESCE(v.fsize, 0) <= ?".to_string());
        params.push(BindValue::Float(max_size));
    }
    if let Some(min_dependency) = query.min_dependency {
        conditions.push("COALESCE(v.dependencyCnt, 0) >= ?".to_string());
        params.push(BindValue::Int(min_dependency));
    }
    if let Some(max_dependency) = query.max_dependency {
        conditions.push("COALESCE(v.dependencyCnt, 0) <= ?".to_string());
        params.push(BindValue::Int(max_dependency));
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
    let mut count_query = sqlx::query_scalar::<_, i64>(&count_sql);
    for param in &params {
        count_query = match param {
            BindValue::Text(value) => count_query.bind(value),
            BindValue::Int(value) => count_query.bind(*value),
            BindValue::Float(value) => count_query.bind(*value),
        };
    }
    let total: i64 = count_query
        .fetch_one(pool)
        .await
        .map_err(internal_error)?;
    let total = total as u64;

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
    let mut list_query = sqlx::query(&sql);
    for param in &params {
        list_query = match param {
            BindValue::Text(value) => list_query.bind(value),
            BindValue::Int(value) => list_query.bind(*value),
            BindValue::Float(value) => list_query.bind(*value),
        };
    }
    list_query = list_query.bind(per_page as i64).bind(offset);
    let rows = list_query.fetch_all(pool).await.map_err(internal_error)?;
    let mut items = Vec::new();
    for row in rows {
        items.push(VarListItem {
            var_name: row.try_get(0).map_err(internal_error)?,
            creator_name: row.try_get(1).map_err(internal_error)?,
            package_name: row.try_get(2).map_err(internal_error)?,
            meta_date: row.try_get(3).map_err(internal_error)?,
            var_date: row.try_get(4).map_err(internal_error)?,
            version: row.try_get(5).map_err(internal_error)?,
            description: row.try_get(6).map_err(internal_error)?,
            morph: row.try_get(7).map_err(internal_error)?,
            cloth: row.try_get(8).map_err(internal_error)?,
            hair: row.try_get(9).map_err(internal_error)?,
            skin: row.try_get(10).map_err(internal_error)?,
            pose: row.try_get(11).map_err(internal_error)?,
            scene: row.try_get(12).map_err(internal_error)?,
            script: row.try_get(13).map_err(internal_error)?,
            plugin: row.try_get(14).map_err(internal_error)?,
            asset: row.try_get(15).map_err(internal_error)?,
            texture: row.try_get(16).map_err(internal_error)?,
            look: row.try_get(17).map_err(internal_error)?,
            sub_scene: row.try_get(18).map_err(internal_error)?,
            appearance: row.try_get(19).map_err(internal_error)?,
            dependency_cnt: row.try_get(20).map_err(internal_error)?,
            fsize: row.try_get(21).map_err(internal_error)?,
            installed: row
                .try_get::<i64, _>(22)
                .map_err(internal_error)?
                != 0,
            disabled: row
                .try_get::<i64, _>(23)
                .map_err(internal_error)?
                != 0,
        });
    }

    Ok(Json(VarsListResponse {
        items,
        page,
        per_page,
        total,
    }))
}

pub async fn resolve_vars(
    State(state): State<AppState>,
    Json(req): Json<ResolveVarsRequest>,
) -> ApiResult<Json<ResolveVarsResponse>> {
    let _cfg = read_config(&state).map_err(internal_error)?;
    let pool = &state.db_pool;

    let mut resolved = HashMap::new();
    for name in req.names {
        let value =
            crate::domain::var_logic::resolve_var_exist_name(pool, &name)
                .await
                .unwrap_or_else(|_| "missing".to_string());
        resolved.insert(name, value);
    }
    Ok(Json(ResolveVarsResponse { resolved }))
}

pub async fn validate_output_dir(
    Json(req): Json<ValidateOutputRequest>,
) -> ApiResult<Json<ValidateOutputResponse>> {
    let path_str = req.path.trim();
    if path_str.is_empty() {
        return Err(ApiError::bad_request("path is required"));
    }
    let mut path = PathBuf::from(path_str);
    if !path.is_absolute() {
        path = app_root().join(&path);
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
    let mut entries = std::fs::read_dir(&path).map_err(internal_error)?;
    if entries.next().is_some() {
        return Ok(Json(ValidateOutputResponse {
            ok: false,
            reason: Some("directory not empty".to_string()),
        }));
    }
    Ok(Json(ValidateOutputResponse { ok: true, reason: None }))
}

pub async fn save_missing_map(
    Json(req): Json<MissingMapSaveRequest>,
) -> ApiResult<Json<MissingMapResponse>> {
    let path_str = req.path.trim();
    if path_str.is_empty() {
        return Err(ApiError::bad_request("path is required"));
    }
    let mut path = PathBuf::from(path_str);
    if !path.is_absolute() {
        path = app_root().join(&path);
    }
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(internal_error)?;
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
    std::fs::write(&path, lines.join("\n")).map_err(internal_error)?;
    Ok(Json(MissingMapResponse { links: saved }))
}

pub async fn load_missing_map(
    Json(req): Json<MissingMapLoadRequest>,
) -> ApiResult<Json<MissingMapResponse>> {
    let path_str = req.path.trim();
    if path_str.is_empty() {
        return Err(ApiError::bad_request("path is required"));
    }
    let mut path = PathBuf::from(path_str);
    if !path.is_absolute() {
        path = app_root().join(&path);
    }
    let contents = std::fs::read_to_string(&path).map_err(|err| ApiError::not_found(err.to_string()))?;
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

pub async fn list_missing_links(
    State(state): State<AppState>,
) -> ApiResult<Json<MissingMapResponse>> {
    let cfg = read_config(&state).map_err(internal_error)?;
    let vampath = cfg
        .vampath
        .as_ref()
        .map(PathBuf::from)
        .ok_or_else(|| ApiError::bad_request("vampath is required in config.json"))?;
    let root = crate::infra::paths::missing_links_dir(&vampath);
    if !root.exists() {
        return Ok(Json(MissingMapResponse { links: Vec::new() }));
    }

    let mut map: std::collections::BTreeMap<String, String> = std::collections::BTreeMap::new();
    for entry in WalkDir::new(&root)
        .into_iter()
        .filter_map(Result::ok)
        .filter(|e| e.file_type().is_file() || e.file_type().is_symlink())
    {
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) != Some("var") {
            continue;
        }
        let missing = match path.file_stem().and_then(|s| s.to_str()) {
            Some(value) if !value.is_empty() => value.to_string(),
            _ => continue,
        };
        let dest = match crate::infra::winfs::read_link_target(path) {
            Ok(target) => target
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("")
                .to_string(),
            Err(_) => String::new(),
        };
        map.insert(missing, dest);
    }

    let links = map
        .into_iter()
        .map(|(missing_var, dest_var)| MissingMapItem {
            missing_var,
            dest_var,
        })
        .collect();
    Ok(Json(MissingMapResponse { links }))
}

pub async fn get_var_detail(
    State(state): State<AppState>,
    Path(name): Path<String>,
) -> ApiResult<Json<VarDetailResponse>> {
    let _cfg = read_config(&state).map_err(internal_error)?;
    let pool = &state.db_pool;

    let row = sqlx::query(
        "SELECT v.varName, v.creatorName, v.packageName, v.metaDate, v.varDate, v.version, v.description,
                v.morph, v.cloth, v.hair, v.skin, v.pose, v.scene, v.script, v.plugin, v.asset, v.texture,
                v.look, v.subScene, v.appearance, v.dependencyCnt, v.fsize,
                COALESCE(i.installed, 0), COALESCE(i.disabled, 0)
         FROM vars v
         LEFT JOIN installStatus i ON v.varName = i.varName
         WHERE v.varName = ?1
         LIMIT 1",
    )
    .bind(&name)
    .fetch_optional(pool)
    .await
    .map_err(internal_error)?;

    let row = row.ok_or_else(|| ApiError::not_found("var not found"))?;
    let var_info = VarListItem {
        var_name: row.try_get(0).map_err(internal_error)?,
        creator_name: row.try_get(1).map_err(internal_error)?,
        package_name: row.try_get(2).map_err(internal_error)?,
        meta_date: row.try_get(3).map_err(internal_error)?,
        var_date: row.try_get(4).map_err(internal_error)?,
        version: row.try_get(5).map_err(internal_error)?,
        description: row.try_get(6).map_err(internal_error)?,
        morph: row.try_get(7).map_err(internal_error)?,
        cloth: row.try_get(8).map_err(internal_error)?,
        hair: row.try_get(9).map_err(internal_error)?,
        skin: row.try_get(10).map_err(internal_error)?,
        pose: row.try_get(11).map_err(internal_error)?,
        scene: row.try_get(12).map_err(internal_error)?,
        script: row.try_get(13).map_err(internal_error)?,
        plugin: row.try_get(14).map_err(internal_error)?,
        asset: row.try_get(15).map_err(internal_error)?,
        texture: row.try_get(16).map_err(internal_error)?,
        look: row.try_get(17).map_err(internal_error)?,
        sub_scene: row.try_get(18).map_err(internal_error)?,
        appearance: row.try_get(19).map_err(internal_error)?,
        dependency_cnt: row.try_get(20).map_err(internal_error)?,
        fsize: row.try_get(21).map_err(internal_error)?,
        installed: row
            .try_get::<i64, _>(22)
            .map_err(internal_error)?
            != 0,
        disabled: row
            .try_get::<i64, _>(23)
            .map_err(internal_error)?
            != 0,
    };

    let dependencies =
        list_dependencies_with_status(pool, &name).await.map_err(internal_error)?;
    let dependents =
        list_dependents_conn(pool, &name).await.map_err(internal_error)?;
    let dependent_saves =
        list_dependent_saves(pool, &name).await.map_err(internal_error)?;
    let scenes = list_var_scenes(pool, &name).await.map_err(internal_error)?;

    Ok(Json(VarDetailResponse {
        var_info,
        dependencies,
        dependents,
        dependent_saves,
        scenes,
    }))
}

pub async fn list_scenes(
    State(state): State<AppState>,
    Query(query): Query<ScenesQuery>,
) -> ApiResult<Json<ScenesListResponse>> {
    let _cfg = read_config(&state).map_err(internal_error)?;
    let pool = &state.db_pool;

    let page = query.page.unwrap_or(1).max(1);
    let per_page = query.per_page.unwrap_or(50).clamp(1, 200);

    enum BindValue {
        Text(String),
    }
    let mut conditions = Vec::new();
    let mut params: Vec<BindValue> = Vec::new();

    if let Some(category) = query.category.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty()) {
        conditions.push("s.atomType = ?".to_string());
        params.push(BindValue::Text(category.to_string()));
    }
    if let Some(creator) = query.creator.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty()) {
        conditions.push("v.creatorName = ?".to_string());
        params.push(BindValue::Text(creator.to_string()));
    }
    if let Some(search) = query.search.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty()) {
        conditions.push("(s.scenePath LIKE ? OR v.varName LIKE ?)".to_string());
        let like = format!("%{}%", search);
        params.push(BindValue::Text(like.clone()));
        params.push(BindValue::Text(like));
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
         LEFT JOIN HideFav h ON s.varName = h.varName AND s.scenePath = h.scenePath
         {}",
        where_clause
    );
    let mut list_query = sqlx::query(&sql);
    for param in &params {
        list_query = match param {
            BindValue::Text(value) => list_query.bind(value),
        };
    }
    let rows = list_query.fetch_all(pool).await.map_err(internal_error)?;
    let mut items = Vec::new();
    for row in rows {
        let hide: i64 = row.try_get(13).map_err(internal_error)?;
        let fav: i64 = row.try_get(14).map_err(internal_error)?;
        let hide_fav = if hide != 0 { -1 } else if fav != 0 { 1 } else { 0 };
        let installed = row.try_get::<i64, _>(11).map_err(internal_error)? != 0;
        let location = if installed {
            "installed".to_string()
        } else {
            "not_installed".to_string()
        };
        items.push(SceneListItem {
            var_name: row.try_get(0).map_err(internal_error)?,
            atom_type: row.try_get(1).map_err(internal_error)?,
            preview_pic: row.try_get(2).map_err(internal_error)?,
            scene_path: row.try_get(3).map_err(internal_error)?,
            is_preset: row.try_get::<i64, _>(4).map_err(internal_error)? != 0,
            is_loadable: row.try_get::<i64, _>(5).map_err(internal_error)? != 0,
            creator_name: row.try_get(6).map_err(internal_error)?,
            package_name: row.try_get(7).map_err(internal_error)?,
            meta_date: row.try_get(8).map_err(internal_error)?,
            var_date: row.try_get(9).map_err(internal_error)?,
            version: row.try_get(10).map_err(internal_error)?,
            installed,
            disabled: row.try_get::<i64, _>(12).map_err(internal_error)? != 0,
            hide: hide != 0,
            fav: fav != 0,
            hide_fav,
            location,
        });
    }

    let location_filter = parse_location_filter(query.location.as_deref());
    let include_save = location_filter.contains("save");
    let include_missing = location_filter.contains("missinglink");
    if include_save || include_missing {
        let (_, vampath) = crate::infra::paths::config_paths(&state).map_err(internal_error)?;
        let vampath =
            vampath.ok_or_else(|| ApiError::bad_request("vampath is required in config.json"))?;

        if include_save {
            items.extend(load_save_scenes(&vampath));
        }
        if include_missing {
            items.extend(load_missing_link_scenes(pool, &vampath).await);
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
                if !creator.is_empty()
                    && item
                        .creator_name
                        .as_ref()
                        .map(|c| c != creator)
                        .unwrap_or(true)
                {
                    return false;
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

async fn load_missing_link_scenes(
    pool: &SqlitePool,
    vampath: &StdPath,
) -> Vec<SceneListItem> {
    let mut items = Vec::new();
    let root = crate::infra::paths::missing_links_dir(vampath);
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
        if let Ok(target) = crate::infra::winfs::read_link_target(path) {
            if let Some(stem) = target.file_stem().and_then(|s| s.to_str()) {
                dest = stem.to_string();
            }
        }
        vars.push(dest);
    }
    vars.sort();
    vars.dedup();

    for var_name in vars {
        let rows = match sqlx::query(
        "SELECT s.varName, s.atomType, s.previewPic, s.scenePath, s.isPreset, s.isLoadable,
                v.creatorName, v.packageName, v.metaDate, v.varDate, v.version,
                COALESCE(i.installed, 0), COALESCE(i.disabled, 0)
         FROM scenes s
         LEFT JOIN vars v ON s.varName = v.varName
         LEFT JOIN installStatus i ON s.varName = i.varName
         WHERE s.varName = ?1",
        )
        .bind(&var_name)
        .fetch_all(pool)
        .await
        {
            Ok(rows) => rows,
            Err(_) => continue,
        };
        for row in rows {
            let var_name = match row.try_get::<String, _>(0) {
                Ok(value) => value,
                Err(_) => continue,
            };
            let scene_path: String = match row.try_get(3) {
                Ok(value) => value,
                Err(_) => continue,
            };
            let (hide, fav, hide_fav) =
                read_hide_fav_for_var(vampath, &var_name, &scene_path);
            items.push(SceneListItem {
                var_name,
                atom_type: row.try_get(1).unwrap_or_default(),
                preview_pic: row.try_get(2).ok(),
                scene_path,
                is_preset: row.try_get::<i64, _>(4).unwrap_or(0) != 0,
                is_loadable: row.try_get::<i64, _>(5).unwrap_or(0) != 0,
                creator_name: row.try_get(6).ok(),
                package_name: row.try_get(7).ok(),
                meta_date: row.try_get(8).ok(),
                var_date: row.try_get(9).ok(),
                version: row.try_get(10).ok(),
                installed: row.try_get::<i64, _>(11).unwrap_or(0) != 0,
                disabled: row.try_get::<i64, _>(12).unwrap_or(0) != 0,
                hide,
                fav,
                hide_fav,
                location: "missinglink".to_string(),
            });
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
    let base = crate::infra::paths::prefs_root(vampath)
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

pub async fn list_creators(
    State(state): State<AppState>,
    Query(query): Query<CreatorsQuery>,
) -> ApiResult<Json<CreatorsResponse>> {
    let _cfg = read_config(&state).map_err(internal_error)?;
    let pool = &state.db_pool;

    let q = query.q.unwrap_or_default().trim().to_string();
    let limit = query
        .limit
        .unwrap_or(if q.is_empty() { 0 } else { 10 })
        .clamp(0, 100);
    let offset = query.offset.unwrap_or(0) as i64;

    let mut builder = QueryBuilder::new(
        "SELECT DISTINCT creatorName FROM vars WHERE creatorName IS NOT NULL AND creatorName <> ''",
    );
    if !q.is_empty() {
        builder
            .push(" AND creatorName LIKE ")
            .push_bind(format!("%{}%", q))
            .push(" COLLATE NOCASE");
    }
    if !q.is_empty() {
        builder
            .push(" ORDER BY CASE WHEN creatorName LIKE ")
            .push_bind(format!("{}%", q))
            .push(" COLLATE NOCASE THEN 0 ELSE 1 END, creatorName COLLATE NOCASE");
    } else {
        builder.push(" ORDER BY creatorName");
    }
    if limit > 0 || offset > 0 {
        builder
            .push(" LIMIT ")
            .push_bind(limit as i64)
            .push(" OFFSET ")
            .push_bind(offset);
    }

    let rows = builder
        .build()
        .fetch_all(pool)
        .await
        .map_err(internal_error)?;
    let mut creators = Vec::new();
    for row in rows {
        creators.push(row.try_get::<String, _>(0).map_err(internal_error)?);
    }

    Ok(Json(CreatorsResponse { creators }))
}

pub async fn list_hub_options(
    Query(query): Query<HubOptionsQuery>,
) -> ApiResult<Json<HubOptionsResponse>> {
    let kind = query.kind.trim().to_lowercase();
    if kind.is_empty() {
        return Err(ApiError::bad_request("kind is required"));
    }
    let q = query.q.unwrap_or_default();
    let offset = query.offset.unwrap_or(0) as usize;
    let limit = query.limit.unwrap_or(10).clamp(1, 50) as usize;
    let refresh = query.refresh.unwrap_or(false);

    let (items, total) = tokio::task::spawn_blocking(move || {
        crate::jobs::hub::search_hub_options(&kind, &q, offset, limit, refresh)
    })
    .await
    .map_err(|err| ApiError::internal(err.to_string()))?
    .map_err(ApiError::bad_request)?;

    Ok(Json(HubOptionsResponse { items, total }))
}

pub async fn list_packswitch(
    State(state): State<AppState>,
) -> ApiResult<Json<PackSwitchListResponse>> {
    let (_, vampath) = crate::infra::paths::config_paths(&state).map_err(internal_error)?;
    let vampath =
        vampath.ok_or_else(|| ApiError::bad_request("vampath is required in config.json"))?;
    let root = crate::infra::paths::addon_switch_root(&vampath);
    std::fs::create_dir_all(&root).map_err(internal_error)?;

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
    switches.sort_by_key(|a| a.to_ascii_lowercase());

    let addon_path = crate::infra::paths::addon_packages_dir(&vampath);
    let link_root = addon_path.join(crate::infra::paths::INSTALL_LINK_DIR);
    let current = if let Ok(target) = crate::infra::winfs::read_link_target(&link_root) {
        let resolved = if target.is_absolute() {
            target
        } else {
            link_root
                .parent()
                .unwrap_or(&addon_path)
                .join(target)
        };
        let switch_root = crate::infra::paths::addon_switch_root(&vampath);
        if resolved.starts_with(&switch_root) {
            resolved
                .parent()
                .and_then(|p| p.file_name())
                .and_then(|s| s.to_str())
                .unwrap_or("default")
                .to_string()
        } else {
            "default".to_string()
        }
    } else {
        "default".to_string()
    };

    Ok(Json(PackSwitchListResponse { current, switches }))
}

pub async fn list_var_dependencies(
    State(state): State<AppState>,
    Json(req): Json<VarDependenciesRequest>,
) -> ApiResult<Json<VarDependenciesResponse>> {
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

    let pool = &state.db_pool;

    let mut builder = QueryBuilder::new(
        "SELECT varName, dependency FROM dependencies WHERE varName IN (",
    );
    let mut separated = builder.separated(", ");
    for name in &names {
        separated.push_bind(name);
    }
    separated.push_unseparated(") ORDER BY varName, dependency");
    let rows = builder
        .build()
        .fetch_all(pool)
        .await
        .map_err(internal_error)?;
    let mut items = Vec::new();
    for row in rows {
        items.push(VarDependencyItem {
            var_name: row.try_get(0).map_err(internal_error)?,
            dependency: row.try_get(1).map_err(internal_error)?,
        });
    }
    Ok(Json(VarDependenciesResponse { items }))
}

pub async fn list_var_previews(
    State(state): State<AppState>,
    Json(req): Json<VarPreviewsRequest>,
) -> ApiResult<Json<VarPreviewsResponse>> {
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

    let pool = &state.db_pool;

    let mut builder = QueryBuilder::new(
        "SELECT s.varName, s.atomType, s.previewPic, s.scenePath, s.isPreset, s.isLoadable, \
                COALESCE(i.installed, 0) \
         FROM scenes s \
         LEFT JOIN installStatus i ON s.varName = i.varName \
         WHERE s.varName IN (",
    );
    let mut separated = builder.separated(", ");
    for name in &names {
        separated.push_bind(name);
    }
    separated.push_unseparated(") ORDER BY s.varName, s.atomType, s.scenePath");
    let rows = builder
        .build()
        .fetch_all(pool)
        .await
        .map_err(internal_error)?;
    let mut items = Vec::new();
    for row in rows {
        items.push(VarPreviewItem {
            var_name: row.try_get(0).map_err(internal_error)?,
            atom_type: row.try_get(1).map_err(internal_error)?,
            preview_pic: row.try_get(2).map_err(internal_error)?,
            scene_path: row.try_get(3).map_err(internal_error)?,
            is_preset: row.try_get::<i64, _>(4).map_err(internal_error)? != 0,
            is_loadable: row.try_get::<i64, _>(5).map_err(internal_error)? != 0,
            installed: row.try_get::<i64, _>(6).map_err(internal_error)? != 0,
        });
    }
    Ok(Json(VarPreviewsResponse { items }))
}

pub async fn list_dependents(
    State(state): State<AppState>,
    Query(query): Query<DependentsQuery>,
) -> ApiResult<Json<DependentsResponse>> {
    let pool = &state.db_pool;

    let mut dependents = Vec::new();
    let rows = sqlx::query("SELECT varName FROM dependencies WHERE dependency = ?1")
        .bind(&query.name)
        .fetch_all(pool)
        .await
        .map_err(internal_error)?;
    for row in rows {
        if let Some(value) = row
            .try_get::<Option<String>, _>(0)
            .map_err(internal_error)?
        {
            dependents.push(value);
        }
    }

    let mut dependent_saves = Vec::new();
    let rows = sqlx::query("SELECT SavePath FROM savedepens WHERE dependency = ?1")
        .bind(&query.name)
        .fetch_all(pool)
        .await
        .map_err(internal_error)?;
    for row in rows {
        if let Some(value) = row
            .try_get::<Option<String>, _>(0)
            .map_err(internal_error)?
        {
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

pub async fn list_analysis_atoms(
    State(state): State<AppState>,
    Query(query): Query<AnalysisAtomsQuery>,
) -> ApiResult<Json<AnalysisAtomsResponse>> {
    let (atoms, person_atoms) =
        scenes::list_analysis_atoms(&state, &query.var_name, &query.entry_name)
            .map_err(internal_error)?;
    Ok(Json(AnalysisAtomsResponse {
        atoms,
        person_atoms,
    }))
}

pub async fn get_analysis_summary(
    State(state): State<AppState>,
    Query(query): Query<AnalysisAtomsQuery>,
) -> ApiResult<Json<scenes::AnalysisSummary>> {
    let summary = scenes::analysis_summary(&state, &query.var_name, &query.entry_name)
        .await
        .map_err(internal_error)?;
    Ok(Json(summary))
}

pub async fn list_saves_tree(
    State(state): State<AppState>,
) -> ApiResult<Json<SavesTreeResponse>> {
    let (_, vampath) = crate::infra::paths::config_paths(&state).map_err(internal_error)?;
    let vampath = vampath
        .ok_or_else(|| ApiError::bad_request("vampath is required in config.json"))?;

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

pub async fn get_stats(
    State(state): State<AppState>,
) -> ApiResult<Json<StatsResponse>> {
    let _cfg = read_config(&state).map_err(internal_error)?;
    let pool = &state.db_pool;

    let vars_total: u64 = sqlx::query_scalar::<_, i64>("SELECT COUNT(1) FROM vars")
        .fetch_one(pool)
        .await
        .map_err(internal_error)? as u64;
    let vars_installed: u64 = sqlx::query_scalar::<_, i64>(
        "SELECT COUNT(1) FROM installStatus WHERE installed = 1",
    )
    .fetch_one(pool)
    .await
    .map_err(internal_error)? as u64;
    let vars_disabled: u64 = sqlx::query_scalar::<_, i64>(
        "SELECT COUNT(1) FROM installStatus WHERE disabled = 1",
    )
    .fetch_one(pool)
    .await
    .map_err(internal_error)? as u64;
    let scenes_total: u64 = sqlx::query_scalar::<_, i64>("SELECT COUNT(1) FROM scenes")
        .fetch_one(pool)
        .await
        .map_err(internal_error)? as u64;
    let missing_deps: u64 = sqlx::query_scalar::<_, i64>(
        "SELECT COUNT(DISTINCT d.dependency)
         FROM dependencies d
         LEFT JOIN vars v ON d.dependency = v.varName
         WHERE v.varName IS NULL",
    )
    .fetch_one(pool)
    .await
    .map_err(internal_error)? as u64;

    Ok(Json(StatsResponse {
        vars_total,
        vars_installed,
        vars_disabled,
        scenes_total,
        missing_deps,
    }))
}

pub async fn get_preview(
    State(state): State<AppState>,
    Query(query): Query<PreviewQuery>,
) -> ApiResult<Response> {
    let source = parse_image_source(&state, query).map_err(bad_request_error)?;
    let (bytes, content_type) = state
        .image_cache
        .get_or_fetch(source)
        .await
        .map_err(map_image_cache_error)?;
    let resp = Response::builder()
        .status(StatusCode::OK)
        .header(header::CONTENT_TYPE, content_type)
        .header(header::CACHE_CONTROL, "public, max-age=3600")
        .body(Body::from(bytes))
        .map_err(internal_error)?;
    Ok(resp)
}

fn safe_join(base: &StdPath, relative: &str) -> Result<PathBuf, String> {
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

fn parse_image_source(state: &AppState, query: PreviewQuery) -> Result<ResolvedImageSource, String> {
    if let Some(source) = query
        .source
        .as_ref()
        .map(|s| s.trim().to_lowercase())
        .filter(|s| !s.is_empty())
    {
        match source.as_str() {
            "hub" => {
                let url = query
                    .url
                    .as_ref()
                    .map(|s| s.trim())
                    .filter(|s| !s.is_empty())
                    .ok_or_else(|| "hub url is required".to_string())?;
                return Ok(ResolvedImageSource {
                    source: ImageSource::Hub {
                        url: url.to_string(),
                    },
                    full_path: None,
                });
            }
            "local" => {
                let root = query
                    .root
                    .as_ref()
                    .map(|s| s.trim())
                    .filter(|s| !s.is_empty())
                    .ok_or_else(|| "preview root is required".to_string())?;
                let path = query
                    .path
                    .as_ref()
                    .map(|s| s.trim())
                    .filter(|s| !s.is_empty())
                    .ok_or_else(|| "preview path is required".to_string())?;
                return resolve_local_source(state, root, path);
            }
            _ => return Err("invalid preview source".to_string()),
        }
    }

    let root = query
        .root
        .as_ref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .ok_or_else(|| "preview root is required".to_string())?;
    let path = query
        .path
        .as_ref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .ok_or_else(|| "preview path is required".to_string())?;
    resolve_local_source(state, root, path)
}

fn resolve_local_source(
    state: &AppState,
    root: &str,
    path: &str,
) -> Result<ResolvedImageSource, String> {
    let cfg = read_config(state)?;
    let root_key = root.trim();
    let root_normalized = root_key.to_lowercase();
    let base = match root_normalized.as_str() {
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
        "cache" => Ok(data_dir().join("Cache")),
        _ => Err("invalid preview root".to_string()),
    }?;

    let joined = safe_join(&base, path)?;
    Ok(ResolvedImageSource {
        source: ImageSource::LocalFile {
            root: root_normalized,
            path: path.to_string(),
        },
        full_path: Some(joined),
    })
}

fn map_image_cache_error(err: ImageCacheError) -> ApiError {
    match err {
        ImageCacheError::NotFound(message) => ApiError::not_found(message),
        ImageCacheError::Network(message) => {
            ApiError::new(StatusCode::BAD_GATEWAY, message)
        }
        ImageCacheError::HttpStatus { status, url } => ApiError::new(
            StatusCode::BAD_GATEWAY,
            format!("upstream status {} for {}", status, url),
        ),
        ImageCacheError::DiskFull { context, source } => ApiError::new(
            StatusCode::INSUFFICIENT_STORAGE,
            format!("disk full while {}: {}", context, source),
        ),
        ImageCacheError::Io { context, source } => {
            ApiError::internal(format!("io error while {}: {}", context, source))
        }
        ImageCacheError::Db(message) => ApiError::internal(message),
        ImageCacheError::Invalid(message) => ApiError::bad_request(message),
    }
}

pub async fn get_cache_stats(
    State(state): State<AppState>,
) -> ApiResult<Json<CacheStats>> {
    let stats = state.image_cache.stats().await.map_err(internal_error)?;
    Ok(Json(stats))
}

pub async fn clear_cache(State(state): State<AppState>) -> ApiResult<Json<Value>> {
    state.image_cache.clear().await.map_err(internal_error)?;
    Ok(Json(json!({ "status": "cleared" })))
}

pub async fn delete_cache_entry(
    State(state): State<AppState>,
    Query(query): Query<DeleteCacheEntryQuery>,
) -> ApiResult<Json<Value>> {
    let removed = state
        .image_cache
        .delete_entry(&query.key)
        .await
        .map_err(internal_error)?;
    Ok(Json(json!({ "removed": removed })))
}

async fn list_dependencies_with_status(
    pool: &SqlitePool,
    var_name: &str,
) -> Result<Vec<DependencyStatus>, String> {
    let rows = sqlx::query("SELECT dependency FROM dependencies WHERE varName = ?1")
        .bind(var_name)
        .fetch_all(pool)
        .await
        .map_err(|err| err.to_string())?;
    let mut result = Vec::new();
    for row in rows {
        if let Some(dep) = row
            .try_get::<Option<String>, _>(0)
            .map_err(|err| err.to_string())?
        {
            let mut resolved =
                crate::domain::var_logic::resolve_var_exist_name(pool, &dep).await?;
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

async fn list_dependents_conn(
    pool: &SqlitePool,
    var_name: &str,
) -> Result<Vec<String>, String> {
    let mut names = Vec::new();
    let targets = dependency_targets(pool, var_name).await?;
    for dep in targets {
        let rows = sqlx::query("SELECT varName FROM dependencies WHERE dependency = ?1")
            .bind(&dep)
            .fetch_all(pool)
            .await
            .map_err(|err| err.to_string())?;
        for row in rows {
            if let Some(name) = row
                .try_get::<Option<String>, _>(0)
                .map_err(|err| err.to_string())?
            {
                names.push(name);
            }
        }
    }
    names.sort();
    names.dedup();
    Ok(names)
}

async fn list_dependent_saves(
    pool: &SqlitePool,
    var_name: &str,
) -> Result<Vec<String>, String> {
    let mut names = Vec::new();
    let targets = dependency_targets(pool, var_name).await?;
    for dep in targets {
        let rows = sqlx::query("SELECT SavePath FROM savedepens WHERE dependency = ?1")
            .bind(&dep)
            .fetch_all(pool)
            .await
            .map_err(|err| err.to_string())?;
        for row in rows {
            if let Some(name) = row
                .try_get::<Option<String>, _>(0)
                .map_err(|err| err.to_string())?
            {
                names.push(name);
            }
        }
    }
    names.sort();
    names.dedup();
    Ok(names)
}

async fn list_var_scenes(
    pool: &SqlitePool,
    var_name: &str,
) -> Result<Vec<ScenePreviewItem>, String> {
    let rows = sqlx::query(
        "SELECT atomType, previewPic, scenePath, isPreset, isLoadable FROM scenes WHERE varName = ?1",
    )
    .bind(var_name)
    .fetch_all(pool)
    .await
    .map_err(|err| err.to_string())?;
    let mut items = Vec::new();
    for row in rows {
        items.push(ScenePreviewItem {
            atom_type: row
                .try_get::<String, _>(0)
                .map_err(|err| err.to_string())?,
            preview_pic: row
                .try_get::<Option<String>, _>(1)
                .map_err(|err| err.to_string())?,
            scene_path: row
                .try_get::<String, _>(2)
                .map_err(|err| err.to_string())?,
            is_preset: row
                .try_get::<i64, _>(3)
                .map_err(|err| err.to_string())?
                != 0,
            is_loadable: row
                .try_get::<i64, _>(4)
                .map_err(|err| err.to_string())?
                != 0,
        });
    }
    Ok(items)
}

async fn dependency_targets(
    pool: &SqlitePool,
    var_name: &str,
) -> Result<Vec<String>, String> {
    let parts: Vec<&str> = var_name.split('.').collect();
    if parts.len() != 3 {
        return Ok(vec![var_name.to_string()]);
    }
    let is_latest = is_var_latest(pool, parts[0], parts[1], parts[2]).await?;
    let mut targets = vec![var_name.to_string()];
    if is_latest {
        targets.push(format!("{}.{}.latest", parts[0], parts[1]));
    }
    Ok(targets)
}

async fn is_var_latest(
    pool: &SqlitePool,
    creator: &str,
    package: &str,
    version: &str,
) -> Result<bool, String> {
    let current: i64 = match version.parse() {
        Ok(ver) => ver,
        Err(_) => return Ok(true),
    };
    let rows = db::list_var_versions(pool, creator, package).await?;
    let mut max_ver: Option<i64> = None;
    for (_, ver) in rows {
        if let Ok(parsed) = ver.parse::<i64>() {
            if max_ver.map(|cur| parsed > cur).unwrap_or(true) {
                max_ver = Some(parsed);
            }
        }
    }
    Ok(max_ver.map(|max| current >= max).unwrap_or(true))
}
