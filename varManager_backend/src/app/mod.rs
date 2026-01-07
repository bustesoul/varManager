use crate::jobs::job_channel::{JobEventSender, JobMap};
use serde::{Deserialize, Serialize};
use std::{
    env,
    path::PathBuf,
    sync::{
        atomic::AtomicU64,
        Arc, RwLock,
    },
};
use sysinfo::{Pid, ProcessesToUpdate, System};
use tokio::{
    sync::{oneshot, Semaphore},
    time::{interval, Duration},
};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter, Layer};

pub const PARENT_PID_ENV: &str = "VARMANAGER_PARENT_PID";
pub const APP_VERSION: &str = match option_env!("APP_VERSION") {
    Some(value) => value,
    None => env!("CARGO_PKG_VERSION"),
};

#[derive(Clone, Serialize, Deserialize)]
pub struct Config {
    pub(crate) listen_host: String,
    pub(crate) listen_port: u16,
    pub(crate) log_level: String,
    pub(crate) job_concurrency: usize,
    #[serde(default)]
    pub(crate) varspath: Option<String>,
    #[serde(default)]
    pub(crate) vampath: Option<String>,
    #[serde(default)]
    pub(crate) vam_exec: Option<String>,
    #[serde(default)]
    pub(crate) downloader_save_path: Option<String>,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            listen_host: "127.0.0.1".to_string(),
            listen_port: 57123,
            log_level: "info".to_string(),
            job_concurrency: 10,
            varspath: None,
            vampath: None,
            vam_exec: Some("VaM (Desktop Mode).bat".to_string()),
            downloader_save_path: None,
        }
    }
}

#[derive(Clone)]
pub struct AppState {
    pub(crate) config: Arc<RwLock<Config>>,
    pub(crate) shutdown_tx: Arc<tokio::sync::Mutex<Option<oneshot::Sender<()>>>>,
    pub(crate) jobs: JobMap,
    pub(crate) job_counter: Arc<AtomicU64>,
    pub(crate) job_semaphore: Arc<RwLock<Arc<Semaphore>>>,
    pub(crate) job_tx: JobEventSender,
}

pub fn init_logging(
    config: &Config,
) -> (
    tracing_appender::non_blocking::WorkerGuard,
    tracing_appender::non_blocking::WorkerGuard,
) {
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
    let file_filter =
        EnvFilter::new("varManager_backend=debug,h2=info,reqwest=info,hyper=info,hyper_util=info");
    let file_layer = tracing_subscriber::fmt::layer()
        .with_ansi(false)
        .with_writer(file_writer)
        .with_filter(file_filter);

    tracing_subscriber::registry()
        .with(stdout_layer)
        .with(file_layer)
        .init();

    (file_guard, stdout_guard)
}

pub fn read_parent_pid() -> Option<u32> {
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

pub async fn parent_watchdog(parent_pid: u32, state: AppState) {
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

pub async fn trigger_shutdown(state: &AppState) {
    let mut guard = state.shutdown_tx.lock().await;
    if let Some(tx) = guard.take() {
        let _ = tx.send(());
    }
}

pub async fn shutdown_signal(mut rx: oneshot::Receiver<()>) {
    let ctrl_c = tokio::signal::ctrl_c();
    tokio::select! {
        _ = &mut rx => {},
        _ = ctrl_c => {},
    }
}

pub fn load_or_write_config() -> Result<Config, Box<dyn std::error::Error>> {
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

pub fn exe_dir() -> PathBuf {
    if let Ok(exe) = std::env::current_exe() {
        if let Some(parent) = exe.parent() {
            return parent.to_path_buf();
        }
    }
    std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."))
}
