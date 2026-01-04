use crate::db::{delete_var_related_conn, upsert_install_status, Db};
use crate::fs_util;
use crate::paths::{config_paths, resolve_var_file_path, DELETED_DIR, INSTALL_LINK_DIR};
use crate::var_logic::{implicated_vars, vars_dependencies};
use crate::{job_log, job_progress, job_set_result, winfs, AppState};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fs;
use std::path::Path;
use tokio::runtime::Handle;

#[derive(Deserialize)]
struct InstallVarsArgs {
    var_names: Vec<String>,
    #[serde(default = "default_true")]
    include_dependencies: bool,
    #[serde(default)]
    temp: bool,
    #[serde(default)]
    disabled: bool,
}

#[derive(Deserialize)]
struct UninstallVarsArgs {
    var_names: Vec<String>,
    #[serde(default = "default_true")]
    include_implicated: bool,
}

#[derive(Deserialize)]
struct DeleteVarsArgs {
    var_names: Vec<String>,
    #[serde(default = "default_true")]
    include_implicated: bool,
}

fn default_true() -> bool {
    true
}

#[derive(Serialize)]
struct InstallVarsResult {
    total: usize,
    installed: Vec<String>,
    already_installed: Vec<String>,
    failed: Vec<String>,
}

#[derive(Serialize)]
struct UninstallVarsResult {
    total: usize,
    removed: Vec<String>,
    skipped: Vec<String>,
}

#[derive(Serialize)]
struct DeleteVarsResult {
    total: usize,
    deleted: Vec<String>,
    failed: Vec<String>,
}

pub async fn run_install_vars_job(
    state: AppState,
    id: u64,
    args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        let args = args.ok_or_else(|| "install_vars args required".to_string())?;
        let args: InstallVarsArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
        install_vars_blocking(&reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_uninstall_vars_job(
    state: AppState,
    id: u64,
    args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        let args = args.ok_or_else(|| "uninstall_vars args required".to_string())?;
        let args: UninstallVarsArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
        uninstall_vars_blocking(&reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_delete_vars_job(
    state: AppState,
    id: u64,
    args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        let args = args.ok_or_else(|| "delete_vars args required".to_string())?;
        let args: DeleteVarsArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
        delete_vars_blocking(&reporter, args)
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
        let _ = self
            .handle
            .block_on(job_set_result(&self.state, self.id, result));
    }
}

fn install_vars_blocking(reporter: &JobReporter, args: InstallVarsArgs) -> Result<(), String> {
    let (varspath, vampath) = config_paths(&reporter.state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    reporter.log("InstallVars start".to_string());
    reporter.progress(1);

    let db_path = crate::exe_dir().join("varManager.db");
    let db = Db::open(&db_path)?;
    db.ensure_schema()?;

    let var_list = if args.include_dependencies {
        vars_dependencies(db.connection(), args.var_names)?
    } else {
        args.var_names
    };

    let total = var_list.len();
    let mut installed = Vec::new();
    let mut already_installed = Vec::new();
    let mut failed = Vec::new();

    for (idx, var_name) in var_list.iter().enumerate() {
        match install_var(
            reporter,
            db.connection(),
            &varspath,
            &vampath,
            var_name,
            args.temp,
            args.disabled,
        ) {
            Ok(InstallOutcome::Installed) => installed.push(var_name.clone()),
            Ok(InstallOutcome::AlreadyInstalled) => already_installed.push(var_name.clone()),
            Err(err) => {
                failed.push(var_name.clone());
                reporter.log(format!("install failed {} ({})", var_name, err));
            }
        }

        if total > 0 && (idx % 50 == 0 || idx + 1 == total) {
            let progress = 5 + ((idx + 1) * 90 / total) as u8;
            reporter.progress(progress.min(95));
        }
    }

    reporter.set_result(
        serde_json::to_value(InstallVarsResult {
            total,
            installed,
            already_installed,
            failed,
        })
        .map_err(|err| err.to_string())?,
    );

    reporter.progress(100);
    reporter.log("InstallVars completed".to_string());
    Ok(())
}

fn uninstall_vars_blocking(reporter: &JobReporter, args: UninstallVarsArgs) -> Result<(), String> {
    let (_, vampath) = config_paths(&reporter.state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    reporter.log("UninstallVars start".to_string());
    reporter.progress(1);

    let db_path = crate::exe_dir().join("varManager.db");
    let db = Db::open(&db_path)?;
    db.ensure_schema()?;

    let var_list = if args.include_implicated {
        implicated_vars(db.connection(), args.var_names)?
    } else {
        args.var_names
    };

    let installed_links = fs_util::collect_installed_links(&vampath);
    let total = var_list.len();
    let mut removed = Vec::new();
    let mut skipped = Vec::new();

    for (idx, var_name) in var_list.iter().enumerate() {
        if let Some(link_path) = installed_links.get(var_name) {
            if let Err(err) = fs::remove_file(link_path) {
                reporter.log(format!("remove link failed {} ({})", var_name, err));
                skipped.push(var_name.clone());
            } else {
                removed.push(var_name.clone());
                let _ = remove_install_status(db.connection(), var_name);
            }
        } else {
            skipped.push(var_name.clone());
        }

        if total > 0 && (idx % 50 == 0 || idx + 1 == total) {
            let progress = 5 + ((idx + 1) * 90 / total) as u8;
            reporter.progress(progress.min(95));
        }
    }

    reporter.set_result(
        serde_json::to_value(UninstallVarsResult { total, removed, skipped })
            .map_err(|err| err.to_string())?,
    );

    reporter.progress(100);
    reporter.log("UninstallVars completed".to_string());
    Ok(())
}

fn delete_vars_blocking(reporter: &JobReporter, args: DeleteVarsArgs) -> Result<(), String> {
    let (varspath, vampath) = config_paths(&reporter.state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    reporter.log("DeleteVars start".to_string());
    reporter.progress(1);

    let db_path = crate::exe_dir().join("varManager.db");
    let db = Db::open(&db_path)?;
    db.ensure_schema()?;

    let var_list = if args.include_implicated {
        implicated_vars(db.connection(), args.var_names)?
    } else {
        args.var_names
    };

    let installed_links = fs_util::collect_installed_links(&vampath);
    let total = var_list.len();
    let mut deleted = Vec::new();
    let mut failed = Vec::new();

    let deleted_dir = varspath.join(DELETED_DIR);
    fs::create_dir_all(&deleted_dir).map_err(|err| err.to_string())?;

    for (idx, var_name) in var_list.iter().enumerate() {
        if let Some(link_path) = installed_links.get(var_name) {
            let _ = fs::remove_file(link_path);
        }
        let _ = remove_install_status(db.connection(), var_name);

        let src = match resolve_var_file_path(&varspath, var_name) {
            Ok(path) => path,
            Err(err) => {
                reporter.log(format!("skip {} ({})", var_name, err));
                failed.push(var_name.clone());
                continue;
            }
        };
        let dest = deleted_dir.join(format!("{}.var", var_name));
        match fs::rename(&src, &dest) {
            Ok(_) => {
                delete_var_related_conn(db.connection(), var_name)?;
                delete_preview_pics(&varspath, var_name)?;
                deleted.push(var_name.clone());
            }
            Err(err) => {
                reporter.log(format!("delete failed {} ({})", var_name, err));
                failed.push(var_name.clone());
            }
        }

        if total > 0 && (idx % 20 == 0 || idx + 1 == total) {
            let progress = 5 + ((idx + 1) * 90 / total) as u8;
            reporter.progress(progress.min(95));
        }
    }

    reporter.set_result(
        serde_json::to_value(DeleteVarsResult { total, deleted, failed })
            .map_err(|err| err.to_string())?,
    );

    reporter.progress(100);
    reporter.log("DeleteVars completed".to_string());
    Ok(())
}

fn install_var(
    reporter: &JobReporter,
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
    reporter.log(format!("{} installed", var_name));
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

fn delete_preview_pics(varspath: &Path, var_name: &str) -> Result<(), String> {
    let types = [
        "scenes", "looks", "hairstyle", "clothing", "assets", "morphs", "skin", "pose",
    ];
    for typename in types {
        let dir = varspath.join(crate::paths::PREVIEW_DIR).join(typename).join(var_name);
        if dir.exists() {
            fs::remove_dir_all(&dir).map_err(|err| err.to_string())?;
        }
    }
    Ok(())
}

enum InstallOutcome {
    Installed,
    AlreadyInstalled,
}
