use axum::{
    routing::{get, post, put},
    Router,
};
use std::{
    net::SocketAddr,
    sync::{
        atomic::AtomicU64,
        Arc, RwLock,
    },
};
use tokio::sync::{oneshot, Semaphore};

mod app;
mod api;
mod domain;
mod infra;
mod jobs;
mod scenes;
mod services;
mod util;

use crate::app::{AppState, APP_VERSION};
use crate::infra::db;
use crate::jobs::job_channel::{create_job_channel, create_job_map, JobManager};
use crate::services::image_cache::ImageCacheService;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = app::load_or_write_config()?;
    let (_file_guard, _stdout_guard) = app::init_logging(&config);
    app::init_panic_hook();

    let db_pool = db::open_default_pool()
        .await
        .map_err(std::io::Error::other)?;
    let (shutdown_tx, shutdown_rx) = oneshot::channel();
    let (job_tx, job_rx) = create_job_channel();
    let jobs = create_job_map();
    let image_cache = Arc::new(
        ImageCacheService::new(config.image_cache.clone(), db_pool.clone())
            .await
            .map_err(std::io::Error::other)?,
    );
    image_cache.clone().start_maintenance();
    let state = AppState {
        config: Arc::new(RwLock::new(config.clone())),
        shutdown_tx: Arc::new(tokio::sync::Mutex::new(Some(shutdown_tx))),
        jobs: jobs.clone(),
        job_counter: Arc::new(AtomicU64::new(1)),
        job_semaphore: Arc::new(RwLock::new(Arc::new(Semaphore::new(
            config.job_concurrency,
        )))),
        job_tx,
        db_pool,
        image_cache,
    };

    // Start JobManager to consume job events and update state
    let job_manager = JobManager::new(job_rx, jobs);
    tokio::spawn(async move {
        job_manager.run().await;
    });

    if let Some(parent_pid) = app::read_parent_pid() {
        tracing::info!(parent_pid, "parent watchdog enabled");
        let state_clone = state.clone();
        tokio::spawn(async move {
            app::parent_watchdog(parent_pid, state_clone).await;
        });
    }

    let app = Router::new()
        .route("/health", get(api::health))
        .route("/config", get(api::get_config))
        .route("/config", put(api::update_config))
        .route("/vars", get(api::list_vars))
        .route("/vars/{name}", get(api::get_var_detail))
        .route("/vars/resolve", post(api::resolve_vars))
        .route("/vars/dependencies", post(api::list_var_dependencies))
        .route("/vars/previews", post(api::list_var_previews))
        .route("/scenes", get(api::list_scenes))
        .route("/creators", get(api::list_creators))
        .route("/stats", get(api::get_stats))
        .route("/preview", get(api::get_preview))
        .route("/cache/stats", get(api::get_cache_stats))
        .route("/cache/clear", post(api::clear_cache))
        .route("/cache/entry", axum::routing::delete(api::delete_cache_entry))
        .route("/packswitch", get(api::list_packswitch))
        .route("/hub/options", get(api::list_hub_options))
        .route("/dependents", get(api::list_dependents))
        .route("/analysis/atoms", get(api::list_analysis_atoms))
        .route("/analysis/summary", get(api::get_analysis_summary))
        .route("/saves/tree", get(api::list_saves_tree))
        .route("/saves/validate_output", post(api::validate_output_dir))
        .route("/missing/map/save", post(api::save_missing_map))
        .route("/missing/map/load", post(api::load_missing_map))
        .route("/missing/map/current", get(api::list_missing_links))
        .route("/jobs", post(api::start_job))
        .route("/jobs/{id}", get(api::get_job))
        .route("/jobs/{id}/logs", get(api::get_job_logs))
        .route("/jobs/{id}/result", get(api::get_job_result))
        .route("/shutdown", post(api::shutdown))
        .with_state(state);

    let addr: SocketAddr =
        format!("{}:{}", config.listen_host, config.listen_port).parse()?;
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    tracing::info!(%addr, version = APP_VERSION, "backend listening");

    axum::serve(listener, app)
        .with_graceful_shutdown(app::shutdown_signal(shutdown_rx))
        .await?;

    Ok(())
}
