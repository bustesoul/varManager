//! Job event channel for decoupling job execution from state updates.
//!
//! Architecture:
//! - Job execution (spawn_blocking): sends events via channel (non-blocking)
//! - JobManager (single async task): consumes events and updates state.jobs
//! - HTTP handlers: read state.jobs (no contention with job execution)

use chrono::{Local, SecondsFormat};
use serde_json::Value;
use std::collections::{HashMap, VecDeque};
use std::sync::Arc;
use tokio::sync::mpsc;

/// Channel capacity for job events
const EVENT_CHANNEL_CAPACITY: usize = 10_000;

/// Maximum log lines per job
const MAX_LOG_LINES: usize = 1000;

#[derive(Clone, Copy, Debug, serde::Deserialize, serde::Serialize)]
#[serde(rename_all = "lowercase")]
pub enum JobLogLevel {
    Info,
    Warn,
    Error,
    Debug,
}

#[derive(Clone, Debug, serde::Serialize)]
pub struct JobLogEntry {
    pub timestamp: String,
    pub level: JobLogLevel,
    pub message: String,
}

impl JobLogEntry {
    pub fn new(level: JobLogLevel, message: String) -> Self {
        let timestamp = Local::now().to_rfc3339_opts(SecondsFormat::Micros, true);
        Self {
            timestamp,
            level,
            message,
        }
    }
}

impl JobLogLevel {
    pub fn severity(self) -> u8 {
        match self {
            JobLogLevel::Debug => 0,
            JobLogLevel::Info => 1,
            JobLogLevel::Warn => 2,
            JobLogLevel::Error => 3,
        }
    }
}

pub fn min_job_log_level(raw: &str) -> JobLogLevel {
    match raw.trim().to_ascii_lowercase().as_str() {
        "error" => JobLogLevel::Error,
        "warn" | "warning" => JobLogLevel::Warn,
        "debug" => JobLogLevel::Debug,
        "trace" => JobLogLevel::Debug,
        _ => JobLogLevel::Info,
    }
}

fn infer_log_level(message: &str) -> JobLogLevel {
    let trimmed = message.trim_start();
    if let Some(level) = trimmed
        .strip_prefix('[')
        .and_then(|rest| rest.split_once(']'))
        .map(|(label, _)| label.trim().to_ascii_lowercase())
    {
        return match level.as_str() {
            "error" => JobLogLevel::Error,
            "warn" | "warning" => JobLogLevel::Warn,
            "debug" => JobLogLevel::Debug,
            "info" => JobLogLevel::Info,
            _ => JobLogLevel::Info,
        };
    }

    let lower = trimmed.to_ascii_lowercase();
    if lower.starts_with("error:") || lower.starts_with("err:") {
        return JobLogLevel::Error;
    }
    if lower.starts_with("warn:") || lower.starts_with("warning:") {
        return JobLogLevel::Warn;
    }
    if lower.starts_with("debug:") {
        return JobLogLevel::Debug;
    }
    if lower.starts_with("info:") {
        return JobLogLevel::Info;
    }
    JobLogLevel::Info
}

/// Events sent from job execution threads to the JobManager
#[derive(Debug)]
pub enum JobEvent {
    /// Job started running
    Started { id: u64, message: String },
    /// Log line from job
    Log {
        id: u64,
        level: JobLogLevel,
        message: String,
    },
    /// Progress update (0-100)
    Progress { id: u64, value: u8 },
    /// Job result data
    Result { id: u64, result: Value },
    /// Job completed successfully
    Finished { id: u64, message: String },
    /// Job failed with error
    Failed { id: u64, error: String },
}

/// Sender for job events (cloneable, used by JobReporter)
pub type JobEventSender = mpsc::Sender<JobEvent>;

/// Receiver for job events (used by JobManager)
pub type JobEventReceiver = mpsc::Receiver<JobEvent>;

/// Create a new job event channel
pub fn create_job_channel() -> (JobEventSender, JobEventReceiver) {
    mpsc::channel(EVENT_CHANNEL_CAPACITY)
}

/// Reporter used by job execution code to send events.
/// This is the ONLY JobReporter - all job files should use this.
#[derive(Clone)]
pub struct JobReporter {
    id: u64,
    tx: JobEventSender,
}

impl JobReporter {
    pub fn new(id: u64, tx: JobEventSender) -> Self {
        Self { id, tx }
    }

    /// Send a log line. Uses try_send - drops if channel is full.
    pub fn log(&self, msg: impl Into<String>) {
        let message = msg.into();
        let level = infer_log_level(&message);
        let _ = self.tx.try_send(JobEvent::Log {
            id: self.id,
            level,
            message,
        });
    }

    /// Send progress update. Uses try_send - drops if channel is full (next update will arrive anyway).
    pub fn progress(&self, value: u8) {
        let _ = self.tx.try_send(JobEvent::Progress {
            id: self.id,
            value: value.min(100),
        });
    }

    /// Set job result. Uses blocking_send - must succeed.
    pub fn set_result(&self, result: Value) {
        let _ = self.tx.blocking_send(JobEvent::Result {
            id: self.id,
            result,
        });
    }

    /// Set job result from async contexts without blocking the runtime.
    pub async fn set_result_async(&self, result: Value) {
        let _ = self
            .tx
            .send(JobEvent::Result {
                id: self.id,
                result,
            })
            .await;
    }
}

/// Job status enum
#[derive(Clone, Debug, serde::Serialize)]
#[serde(rename_all = "snake_case")]
pub enum JobStatus {
    Queued,
    Running,
    Succeeded,
    Failed,
}

/// Internal job state
#[derive(Clone, Debug)]
pub struct JobState {
    pub id: u64,
    pub kind: String,
    pub status: JobStatus,
    pub progress: u8,
    pub message: String,
    pub error: Option<String>,
    pub logs: VecDeque<JobLogEntry>,
    pub log_offset: usize,
    pub result: Option<Value>,
}

impl JobState {
    pub fn new(id: u64, kind: String) -> Self {
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

    fn push_log(&mut self, level: JobLogLevel, message: String) {
        let entry = JobLogEntry::new(level, message);
        if self.logs.len() >= MAX_LOG_LINES {
            self.logs.pop_front();
            self.log_offset += 1;
        }
        self.logs.push_back(entry);
    }
}

/// Job view for API responses
#[derive(serde::Serialize)]
pub struct JobView {
    pub id: u64,
    pub kind: String,
    pub status: JobStatus,
    pub progress: u8,
    pub message: String,
    pub error: Option<String>,
    pub log_offset: usize,
    pub log_count: usize,
    pub result_available: bool,
}

impl From<&JobState> for JobView {
    fn from(job: &JobState) -> Self {
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

/// Job logs response
#[derive(serde::Serialize)]
pub struct JobLogsResponse {
    pub id: u64,
    pub from: usize,
    pub next: usize,
    pub dropped: bool,
    pub entries: Vec<JobLogEntry>,
}

/// Job result response
#[derive(serde::Serialize)]
pub struct JobResultResponse {
    pub id: u64,
    pub result: Value,
}

/// Shared job state map (used by HTTP handlers and JobManager)
pub type JobMap = Arc<tokio::sync::RwLock<HashMap<u64, JobState>>>;

/// Create a new job map
pub fn create_job_map() -> JobMap {
    Arc::new(tokio::sync::RwLock::new(HashMap::new()))
}

/// JobManager - single async task that consumes events and updates job state.
/// This is the ONLY writer to JobMap (except for initial job creation).
pub struct JobManager {
    rx: JobEventReceiver,
    jobs: JobMap,
    state: crate::app::AppState,
}

impl JobManager {
    pub fn new(rx: JobEventReceiver, jobs: JobMap, state: crate::app::AppState) -> Self {
        Self { rx, jobs, state }
    }

    /// Run the job manager. Call this in a spawned task.
    pub async fn run(mut self) {
        tracing::info!("JobManager started");
        let mut shutdown_rx = self.state.shutdown_broadcast.subscribe();
        loop {
            tokio::select! {
                Some(event) = self.rx.recv() => {
                    self.handle_event(event).await;
                }
                _ = shutdown_rx.recv() => {
                    tracing::info!("JobManager received shutdown signal");
                    break;
                }
            }
        }
        tracing::info!("JobManager stopped");
    }

    async fn handle_event(&self, event: JobEvent) {
        match event {
            JobEvent::Started { id, message } => {
                let mut jobs = self.jobs.write().await;
                if let Some(job) = jobs.get_mut(&id) {
                    job.status = JobStatus::Running;
                    job.message = message.clone();
                    job.push_log(JobLogLevel::Info, message.clone());
                    job.result = None;
                    tracing::info!(job_id = id, job_kind = %job.kind, msg = %message, "job started");
                }
            }
            JobEvent::Log { id, level, message } => {
                let mut jobs = self.jobs.write().await;
                if let Some(job) = jobs.get_mut(&id) {
                    job.push_log(level, message);
                }
            }
            JobEvent::Progress { id, value } => {
                let mut jobs = self.jobs.write().await;
                if let Some(job) = jobs.get_mut(&id) {
                    job.progress = value.min(100);
                }
            }
            JobEvent::Result { id, result } => {
                let mut jobs = self.jobs.write().await;
                if let Some(job) = jobs.get_mut(&id) {
                    job.result = Some(result);
                }
            }
            JobEvent::Finished { id, message } => {
                let mut jobs = self.jobs.write().await;
                if let Some(job) = jobs.get_mut(&id) {
                    job.status = JobStatus::Succeeded;
                    job.progress = 100;
                    job.message = message.clone();
                    job.error = None;
                    job.push_log(JobLogLevel::Info, message.clone());
                    tracing::info!(job_id = id, job_kind = %job.kind, msg = %message, "job completed");
                }
            }
            JobEvent::Failed { id, error } => {
                let mut jobs = self.jobs.write().await;
                if let Some(job) = jobs.get_mut(&id) {
                    job.status = JobStatus::Failed;
                    job.message = "job failed".to_string();
                    job.error = Some(error.clone());
                    job.push_log(JobLogLevel::Error, error.clone());
                    tracing::error!(job_id = id, job_kind = %job.kind, error = %error, "job failed");
                }
            }
        }
    }
}

/// Helper functions for sending events from main.rs (for job lifecycle management)
pub async fn send_job_started(tx: &JobEventSender, id: u64, message: String) {
    let _ = tx.send(JobEvent::Started { id, message }).await;
}

pub async fn send_job_finished(tx: &JobEventSender, id: u64, message: String) {
    let _ = tx.send(JobEvent::Finished { id, message }).await;
}

pub async fn send_job_failed(tx: &JobEventSender, id: u64, error: String) {
    let _ = tx.send(JobEvent::Failed { id, error }).await;
}
