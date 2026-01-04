use crate::db::{upsert_install_status, var_exists_conn, Db};
use crate::fs_util;
use crate::paths::{config_paths, resolve_var_file_path, INSTALL_LINK_DIR};
use crate::var_logic::{implicated_vars, vars_dependencies};
use crate::{job_log, job_progress, job_set_result, util, winfs, AppState};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fs;
use std::path::{Path, PathBuf};
use tokio::runtime::Handle;

#[derive(Deserialize)]
struct ExportInstalledArgs {
    path: String,
}

#[derive(Serialize)]
struct ExportInstalledResult {
    count: usize,
}

#[derive(Deserialize)]
struct InstallBatchArgs {
    path: String,
}

#[derive(Serialize)]
struct InstallBatchResult {
    total: usize,
    installed: Vec<String>,
    already_installed: Vec<String>,
    failed: Vec<String>,
}

#[derive(Deserialize)]
struct ToggleInstallArgs {
    var_name: String,
    #[serde(default = "default_true")]
    include_dependencies: bool,
    #[serde(default = "default_true")]
    include_implicated: bool,
}

#[derive(Serialize)]
struct ToggleInstallResult {
    action: String,
    installed: Vec<String>,
    removed: Vec<String>,
    failed: Vec<String>,
}

#[derive(Deserialize)]
struct LocateArgs {
    var_name: Option<String>,
    path: Option<String>,
}

#[derive(Serialize)]
struct RefreshInstalledResult {
    installed: usize,
}

fn default_true() -> bool {
    true
}

pub async fn run_export_installed_job(
    state: AppState,
    id: u64,
    args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        let args = args.ok_or_else(|| "vars_export_installed args required".to_string())?;
        let args: ExportInstalledArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
        export_installed_blocking(&reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_install_batch_job(
    state: AppState,
    id: u64,
    args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        let args = args.ok_or_else(|| "vars_install_batch args required".to_string())?;
        let args: InstallBatchArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
        install_batch_blocking(&reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_toggle_install_job(
    state: AppState,
    id: u64,
    args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        let args = args.ok_or_else(|| "vars_toggle_install args required".to_string())?;
        let args: ToggleInstallArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
        toggle_install_blocking(&reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_locate_job(
    state: AppState,
    id: u64,
    args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        let args = args.ok_or_else(|| "vars_locate args required".to_string())?;
        let args: LocateArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
        locate_blocking(&reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_refresh_install_status_job(
    state: AppState,
    id: u64,
    _args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        refresh_install_status_blocking(&reporter)
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

    fn progress(&self, value: u8) {
        let _ = self
            .handle
            .block_on(job_progress(&self.state, self.id, value));
    }

    fn set_result(&self, result: Value) {
        let _ = self.handle.block_on(job_set_result(&self.state, self.id, result));
    }
}

fn export_installed_blocking(
    reporter: &JobReporter,
    args: ExportInstalledArgs,
) -> Result<(), String> {
    let db_path = crate::exe_dir().join("varManager.db");
    let db = Db::open(&db_path)?;
    db.ensure_schema()?;

    let mut stmt = db
        .connection()
        .prepare("SELECT varName FROM installStatus WHERE installed = 1")
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map([], |row| row.get::<_, String>(0))
        .map_err(|err| err.to_string())?;
    let mut vars = Vec::new();
    for row in rows {
        vars.push(row.map_err(|err| err.to_string())?);
    }

    if let Some(parent) = Path::new(&args.path).parent() {
        if !parent.as_os_str().is_empty() {
            fs::create_dir_all(parent).map_err(|err| err.to_string())?;
        }
    }
    fs::write(&args.path, vars.join("\n")).map_err(|err| err.to_string())?;

    reporter.set_result(
        serde_json::to_value(ExportInstalledResult { count: vars.len() })
            .map_err(|err| err.to_string())?,
    );
    Ok(())
}

fn install_batch_blocking(
    reporter: &JobReporter,
    args: InstallBatchArgs,
) -> Result<(), String> {
    let (varspath, vampath) = config_paths(&reporter.state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;

    let contents = fs::read_to_string(&args.path).map_err(|err| err.to_string())?;
    let mut targets: Vec<String> = contents
        .lines()
        .map(|line| line.trim())
        .filter(|line| !line.is_empty())
        .map(|line| line.to_string())
        .collect();
    targets.sort();
    targets.dedup();

    let db_path = crate::exe_dir().join("varManager.db");
    let db = Db::open(&db_path)?;
    db.ensure_schema()?;

    let installed_links = fs_util::collect_installed_links_ci(&vampath);
    let total = targets.len();
    let mut installed = Vec::new();
    let mut already_installed = Vec::new();
    let mut failed = Vec::new();

    for (idx, var_name) in targets.iter().enumerate() {
        if installed_links.contains_key(&var_name.to_ascii_lowercase()) {
            already_installed.push(var_name.clone());
            continue;
        }
        match install_var(db.connection(), &varspath, &vampath, var_name, false, false) {
            Ok(InstallOutcome::Installed) => installed.push(var_name.clone()),
            Ok(InstallOutcome::AlreadyInstalled) => already_installed.push(var_name.clone()),
            Err(err) => {
                reporter.log(format!("install failed {} ({})", var_name, err));
                failed.push(var_name.clone());
            }
        }
        if total > 0 && (idx % 50 == 0 || idx + 1 == total) {
            let progress = 5 + ((idx + 1) * 90 / total) as u8;
            reporter.progress(progress.min(95));
        }
    }

    reporter.set_result(
        serde_json::to_value(InstallBatchResult {
            total,
            installed,
            already_installed,
            failed,
        })
        .map_err(|err| err.to_string())?,
    );
    Ok(())
}

fn toggle_install_blocking(
    reporter: &JobReporter,
    args: ToggleInstallArgs,
) -> Result<(), String> {
    let (varspath, vampath) = config_paths(&reporter.state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;

    let db_path = crate::exe_dir().join("varManager.db");
    let db = Db::open(&db_path)?;
    db.ensure_schema()?;

    let installed_links = fs_util::collect_installed_links_ci(&vampath);
    let key = args.var_name.to_ascii_lowercase();
    if installed_links.contains_key(&key) {
        let mut var_list = if args.include_implicated {
            implicated_vars(db.connection(), vec![args.var_name.clone()])?
        } else {
            vec![args.var_name.clone()]
        };
        var_list.sort();
        var_list.dedup();

        let mut removed = Vec::new();
        let mut failed = Vec::new();
        for var_name in &var_list {
            if let Some(path) = installed_links.get(&var_name.to_ascii_lowercase()) {
                if let Err(err) = fs::remove_file(path) {
                    reporter.log(format!("remove failed {} ({})", var_name, err));
                    failed.push(var_name.clone());
                } else {
                    let _ = remove_install_status(db.connection(), var_name);
                    removed.push(var_name.clone());
                }
            }
        }

        reporter.set_result(
            serde_json::to_value(ToggleInstallResult {
                action: "uninstall".to_string(),
                installed: Vec::new(),
                removed,
                failed,
            })
            .map_err(|err| err.to_string())?,
        );
        return Ok(());
    }

    let mut var_list = if args.include_dependencies {
        vars_dependencies(db.connection(), vec![args.var_name.clone()])?
    } else {
        vec![args.var_name.clone()]
    };
    var_list.sort();
    var_list.dedup();

    let total = var_list.len();
    let mut installed = Vec::new();
    let mut failed = Vec::new();
    for (idx, var_name) in var_list.iter().enumerate() {
        match install_var(db.connection(), &varspath, &vampath, var_name, false, false) {
            Ok(InstallOutcome::Installed) => installed.push(var_name.clone()),
            Ok(InstallOutcome::AlreadyInstalled) => {}
            Err(err) => {
                reporter.log(format!("install failed {} ({})", var_name, err));
                failed.push(var_name.clone());
            }
        }
        if total > 0 && (idx % 50 == 0 || idx + 1 == total) {
            let progress = 5 + ((idx + 1) * 90 / total) as u8;
            reporter.progress(progress.min(95));
        }
    }

    reporter.set_result(
        serde_json::to_value(ToggleInstallResult {
            action: "install".to_string(),
            installed,
            removed: Vec::new(),
            failed,
        })
        .map_err(|err| err.to_string())?,
    );
    Ok(())
}

fn locate_blocking(reporter: &JobReporter, args: LocateArgs) -> Result<(), String> {
    let (varspath, vampath) = config_paths(&reporter.state)?;

    if let Some(var_name) = args.var_name.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty()) {
        let path = resolve_var_file_path(&varspath, var_name)?;
        util::open_explorer_select(&path)?;
        reporter.log(format!("locate {}", var_name));
        return Ok(());
    }

    if let Some(path) = args.path.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty()) {
        let p = PathBuf::from(path);
        let final_path = if p.is_absolute() {
            p
        } else {
            let vampath = vampath.ok_or_else(|| "vampath is required to resolve path".to_string())?;
            vampath.join(p)
        };
        util::open_explorer_select(&final_path)?;
        reporter.log(format!("locate {}", final_path.display()));
        return Ok(());
    }

    Err("vars_locate requires var_name or path".to_string())
}

fn refresh_install_status_blocking(reporter: &JobReporter) -> Result<(), String> {
    let (_, vampath) = config_paths(&reporter.state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;

    let db_path = crate::exe_dir().join("varManager.db");
    let db = Db::open(&db_path)?;
    db.ensure_schema()?;
    db.connection()
        .execute("DELETE FROM installStatus", [])
        .map_err(|err| err.to_string())?;

    let installed_links = fs_util::collect_installed_links(&vampath);
    tracing::debug!(
        vampath = %vampath.display(),
        link_count = installed_links.len(),
        "refresh_install_status: collected links"
    );
    let mut installed = 0;
    for (var_name, link_path) in installed_links {
        if !var_exists_conn(db.connection(), &var_name)? {
            continue;
        }
        let disabled = link_path.with_extension("var.disabled").exists();
        upsert_install_status(db.connection(), &var_name, true, disabled)?;
        installed += 1;
    }

    reporter.set_result(
        serde_json::to_value(RefreshInstalledResult { installed })
            .map_err(|err| err.to_string())?,
    );
    Ok(())
}

fn install_var(
    conn: &rusqlite::Connection,
    varspath: &Path,
    vampath: &Path,
    var_name: &str,
    temp: bool,
    disabled: bool,
) -> Result<InstallOutcome, String> {
    let link_dir = vampath.join("AddonPackages").join(INSTALL_LINK_DIR);
    fs::create_dir_all(&link_dir).map_err(|err| err.to_string())?;
    let link_path = if temp {
        vampath
            .join("AddonPackages")
            .join(crate::paths::TEMP_LINK_DIR)
            .join(format!("{}.var", var_name))
    } else {
        link_dir.join(format!("{}.var", var_name))
    };

    let disabled_path = link_path.with_extension("var.disabled");
    if !disabled && disabled_path.exists() {
        fs::remove_file(&disabled_path).map_err(|err| err.to_string())?;
    }

    if link_path.exists() {
        tracing::debug!(
            var_name = %var_name,
            link_path = %link_path.display(),
            "install_var: link already exists"
        );
        return Ok(InstallOutcome::AlreadyInstalled);
    }

    let dest = resolve_var_file_path(varspath, var_name)?;
    winfs::create_symlink_file(&link_path, &dest)?;
    set_link_times(&link_path, &dest)?;

    if disabled {
        let _ = fs::File::create(&disabled_path);
    }

    upsert_install_status(conn, var_name, true, disabled)?;
    tracing::debug!(
        var_name = %var_name,
        link_path = %link_path.display(),
        dest = %dest.display(),
        disabled,
        "install_var: link created"
    );
    Ok(InstallOutcome::Installed)
}

fn set_link_times(link: &Path, target: &Path) -> Result<(), String> {
    let meta = fs::metadata(target).map_err(|err| err.to_string())?;
    let modified = meta.modified().map_err(|err| err.to_string())?;
    let created = meta.created().unwrap_or(modified);
    winfs::set_symlink_file_times(link, created, modified)
}

fn remove_install_status(conn: &rusqlite::Connection, var_name: &str) -> Result<(), String> {
    conn.execute("DELETE FROM installStatus WHERE varName = ?1", [var_name])
        .map_err(|err| err.to_string())?;
    Ok(())
}

enum InstallOutcome {
    Installed,
    AlreadyInstalled,
}
