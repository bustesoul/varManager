use crate::jobs::job_channel::{JobEventSender, JobMap};
use chrono::Local;
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;
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
use tracing::{Event, Subscriber};
use tracing_subscriber::fmt::{format::Writer, FmtContext, FormatEvent, FormatFields};
use tracing_subscriber::registry::LookupSpan;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter, Layer};

pub const PARENT_PID_ENV: &str = "VARMANAGER_PARENT_PID";
pub const APP_VERSION: &str = match option_env!("APP_VERSION") {
    Some(value) => value,
    None => env!("CARGO_PKG_VERSION"),
};

#[derive(Clone, Serialize, Deserialize)]
pub struct ImageCacheConfig {
    pub disk_cache_size_mb: u32,
    pub memory_cache_size_mb: u32,
    pub cache_ttl_hours: u32,
    pub enabled: bool,
}

impl Default for ImageCacheConfig {
    fn default() -> Self {
        Self {
            disk_cache_size_mb: 500,
            memory_cache_size_mb: 100,
            cache_ttl_hours: 24,
            enabled: true,
        }
    }
}

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
    #[serde(default)]
    pub(crate) image_cache: ImageCacheConfig,
    #[serde(default)]
    pub(crate) ui_theme: Option<String>,
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
            image_cache: ImageCacheConfig::default(),
            ui_theme: None,
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
    pub(crate) db_pool: SqlitePool,
    pub(crate) image_cache: Arc<crate::services::image_cache::ImageCacheService>,
}

pub fn init_logging(
    config: &Config,
) -> (
    tracing_appender::non_blocking::WorkerGuard,
    tracing_appender::non_blocking::WorkerGuard,
) {
    let base_level = config.log_level.as_str();

    let log_dir = exe_dir();
    let file_appender = tracing_appender::rolling::never(&log_dir, "backend.log");
    let (file_writer, file_guard) = tracing_appender::non_blocking(file_appender);

    // IMPORTANT: Also use non_blocking for stdout to prevent blocking tokio threads
    // when Flutter frontend doesn't read stdout pipe fast enough
    let (stdout_writer, stdout_guard) = tracing_appender::non_blocking(std::io::stdout());
    let stdout_layer = tracing_subscriber::fmt::layer()
        .with_ansi(false)
        .event_format(SimpleEventFormat::new("Backend"))
        .with_writer(stdout_writer)
        .with_filter(build_env_filter(base_level));

    let file_layer = tracing_subscriber::fmt::layer()
        .with_ansi(false)
        .event_format(SimpleEventFormat::new("File"))
        .with_writer(file_writer)
        .with_filter(build_env_filter(base_level));

    tracing_subscriber::registry()
        .with(stdout_layer)
        .with(file_layer)
        .init();

    (file_guard, stdout_guard)
}

struct SimpleEventFormat {
    tag: &'static str,
}

impl SimpleEventFormat {
    const fn new(tag: &'static str) -> Self {
        Self { tag }
    }
}

impl<S, N> FormatEvent<S, N> for SimpleEventFormat
where
    S: Subscriber + for<'a> LookupSpan<'a>,
    N: for<'writer> FormatFields<'writer> + 'static,
{
    fn format_event(
        &self,
        _ctx: &FmtContext<'_, S, N>,
        mut writer: Writer<'_>,
        event: &Event<'_>,
    ) -> std::fmt::Result {
        let now = Local::now();
        write!(writer, "{} ", now.format("%Y-%m-%d %H:%M:%S"))?;

        let level = event.metadata().level();
        write!(writer, "[{}][{}] ", level.as_str(), self.tag)?;

        let mut visitor = MessageVisitor::default();
        event.record(&mut visitor);

        if let Some(message) = visitor.msg {
            return writeln!(writer, "{}", message);
        }

        let message = visitor.message.unwrap_or_default();
        if !message.is_empty() {
            write!(writer, "{}", message)?;
            if !visitor.fields.is_empty() {
                write!(writer, " {}", visitor.fields.join(" "))?;
            }
            return writeln!(writer);
        }

        if !visitor.fields.is_empty() {
            return writeln!(writer, "{}", visitor.fields.join(" "));
        }
        writeln!(writer)
    }
}

#[derive(Default)]
struct MessageVisitor {
    message: Option<String>,
    msg: Option<String>,
    fields: Vec<String>,
}

impl MessageVisitor {
    fn set_field(&mut self, field: &tracing::field::Field, value: String) {
        match field.name() {
            "msg" => self.msg = Some(value),
            "message" => self.message = Some(value),
            _ => self.fields.push(format!("{}={}", field.name(), value)),
        }
    }

    fn set_debug_field(&mut self, field: &tracing::field::Field, value: &dyn std::fmt::Debug) {
        let raw = format!("{value:?}");
        let trimmed = raw
            .strip_prefix('"')
            .and_then(|s| s.strip_suffix('"'))
            .unwrap_or(&raw);
        self.set_field(field, trimmed.to_string());
    }
}

impl tracing::field::Visit for MessageVisitor {
    fn record_str(&mut self, field: &tracing::field::Field, value: &str) {
        self.set_field(field, value.to_string());
    }

    fn record_debug(&mut self, field: &tracing::field::Field, value: &dyn std::fmt::Debug) {
        self.set_debug_field(field, value);
    }

    fn record_i64(&mut self, field: &tracing::field::Field, value: i64) {
        self.set_field(field, value.to_string());
    }

    fn record_u64(&mut self, field: &tracing::field::Field, value: u64) {
        self.set_field(field, value.to_string());
    }

    fn record_bool(&mut self, field: &tracing::field::Field, value: bool) {
        self.set_field(field, value.to_string());
    }

    fn record_f64(&mut self, field: &tracing::field::Field, value: f64) {
        self.set_field(field, value.to_string());
    }

    fn record_error(
        &mut self,
        field: &tracing::field::Field,
        value: &(dyn std::error::Error + 'static),
    ) {
        self.set_field(field, value.to_string());
    }
}

fn build_env_filter(base_level: &str) -> EnvFilter {
    let level = base_level.trim().to_ascii_lowercase();
    if level == "debug" {
        EnvFilter::new("varManager_backend=debug,h2=info,reqwest=info,hyper=info,hyper_util=info")
    } else {
        EnvFilter::try_new(level).unwrap_or_else(|_| EnvFilter::new("info"))
    }
}

pub fn init_panic_hook() {
    let default_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        let payload = if let Some(payload) = info.payload().downcast_ref::<&str>() {
            (*payload).to_string()
        } else if let Some(payload) = info.payload().downcast_ref::<String>() {
            payload.clone()
        } else {
            "non-string panic payload".to_string()
        };
        let location = info
            .location()
            .map(|loc| format!("{}:{}", loc.file(), loc.line()))
            .unwrap_or_else(|| "<unknown>".to_string());
        let backtrace = std::backtrace::Backtrace::force_capture();
        tracing::error!(
            panic_payload = %payload,
            panic_location = %location,
            panic_backtrace = %backtrace,
            "panic occurred"
        );
        default_hook(info);
    }));
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
