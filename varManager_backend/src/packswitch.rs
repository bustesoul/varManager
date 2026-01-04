use crate::db::{upsert_install_status, var_exists_conn, Db};
use crate::fs_util;
use crate::paths::{addon_packages_dir, addon_switch_root, config_paths};
use crate::{job_log, job_set_result, system_ops, winfs, AppState};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fs;
use std::path::Path;
use tokio::runtime::Handle;

#[derive(Deserialize)]
struct PackSwitchArgs {
    name: String,
}

#[derive(Deserialize)]
struct PackSwitchRenameArgs {
    old_name: String,
    new_name: String,
}

#[derive(Serialize)]
struct PackSwitchResult {
    name: String,
}

pub async fn run_packswitch_add_job(
    state: AppState,
    id: u64,
    args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        let args = args.ok_or_else(|| "packswitch_add args required".to_string())?;
        let args: PackSwitchArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
        add_switch_blocking(&reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_packswitch_delete_job(
    state: AppState,
    id: u64,
    args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        let args = args.ok_or_else(|| "packswitch_delete args required".to_string())?;
        let args: PackSwitchArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
        delete_switch_blocking(&reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_packswitch_rename_job(
    state: AppState,
    id: u64,
    args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        let args = args.ok_or_else(|| "packswitch_rename args required".to_string())?;
        let args: PackSwitchRenameArgs =
            serde_json::from_value(args).map_err(|err| err.to_string())?;
        rename_switch_blocking(&reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_packswitch_set_job(
    state: AppState,
    id: u64,
    args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        let args = args.ok_or_else(|| "packswitch_set args required".to_string())?;
        let args: PackSwitchArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
        set_switch_blocking(&reporter, &args.name)?;
        reporter.set_result(
            serde_json::to_value(PackSwitchResult { name: args.name })
                .map_err(|err| err.to_string())?,
        );
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

fn add_switch_blocking(reporter: &JobReporter, args: PackSwitchArgs) -> Result<(), String> {
    let (_, vampath) = config_paths(&reporter.state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    let name = args.name.trim();
    if name.is_empty() {
        return Err("switch name is required".to_string());
    }
    let root = addon_switch_root(&vampath);
    fs::create_dir_all(&root).map_err(|err| err.to_string())?;
    let target = root.join(name);
    if target.exists() {
        return Err(format!("switch already exists: {}", name));
    }
    fs::create_dir_all(&target).map_err(|err| err.to_string())?;
    reporter.set_result(
        serde_json::to_value(PackSwitchResult {
            name: name.to_string(),
        })
        .map_err(|err| err.to_string())?,
    );
    Ok(())
}

fn delete_switch_blocking(reporter: &JobReporter, args: PackSwitchArgs) -> Result<(), String> {
    let (_, vampath) = config_paths(&reporter.state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    let name = args.name.trim();
    if name.is_empty() {
        return Err("switch name is required".to_string());
    }
    if name.eq_ignore_ascii_case("default") {
        return Err("cannot delete default switch".to_string());
    }
    let root = addon_switch_root(&vampath);
    let target = root.join(name);
    if target.exists() {
        fs::remove_dir_all(&target).map_err(|err| err.to_string())?;
    }
    reporter.set_result(
        serde_json::to_value(PackSwitchResult {
            name: name.to_string(),
        })
        .map_err(|err| err.to_string())?,
    );
    Ok(())
}

fn rename_switch_blocking(
    reporter: &JobReporter,
    args: PackSwitchRenameArgs,
) -> Result<(), String> {
    let (_, vampath) = config_paths(&reporter.state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    let old_name = args.old_name.trim();
    let new_name = args.new_name.trim();
    if old_name.is_empty() || new_name.is_empty() {
        return Err("old_name and new_name are required".to_string());
    }
    if old_name.eq_ignore_ascii_case("default") {
        return Err("cannot rename default switch".to_string());
    }
    let root = addon_switch_root(&vampath);
    let src = root.join(old_name);
    let dest = root.join(new_name);
    if !src.exists() {
        return Err(format!("switch not found: {}", old_name));
    }
    if dest.exists() {
        return Err(format!("switch already exists: {}", new_name));
    }
    fs::rename(&src, &dest).map_err(|err| err.to_string())?;
    set_switch_blocking(reporter, new_name)?;
    reporter.set_result(
        serde_json::to_value(PackSwitchResult {
            name: new_name.to_string(),
        })
        .map_err(|err| err.to_string())?,
    );
    Ok(())
}

fn set_switch_blocking(reporter: &JobReporter, name: &str) -> Result<(), String> {
    let (_, vampath) = config_paths(&reporter.state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    let switch_root = addon_switch_root(&vampath);
    let target = switch_root.join(name);
    fs::create_dir_all(&target).map_err(|err| err.to_string())?;

    let addon_path = addon_packages_dir(&vampath);
    if addon_path.exists() {
        if let Ok(current_target) = winfs::read_link_target(&addon_path) {
            let cur = current_target.to_string_lossy().to_ascii_lowercase();
            let want = target.to_string_lossy().to_ascii_lowercase();
            if cur == want {
                return Ok(());
            }
        }

        let meta = fs::symlink_metadata(&addon_path).map_err(|err| err.to_string())?;
        if meta.file_type().is_symlink() {
            if fs::remove_file(&addon_path).is_err() {
                fs::remove_dir_all(&addon_path).map_err(|err| err.to_string())?;
            }
        } else {
            fs::remove_dir_all(&addon_path).map_err(|err| err.to_string())?;
        }
    }

    winfs::create_symlink_dir(&addon_path, &target)?;
    let _ = refresh_install_status(&vampath);
    let _ = system_ops::rescan_packages(&reporter.state);
    reporter.log(format!("switch to {}", name));
    Ok(())
}

fn refresh_install_status(vampath: &Path) -> Result<usize, String> {
    let db_path = crate::exe_dir().join("varManager.db");
    let db = Db::open(&db_path)?;
    db.ensure_schema()?;
    db.connection()
        .execute("DELETE FROM installStatus", [])
        .map_err(|err| err.to_string())?;

    let installed_links = fs_util::collect_installed_links(vampath);
    let mut installed = 0;
    for (var_name, link_path) in installed_links {
        if !var_exists_conn(db.connection(), &var_name)? {
            continue;
        }
        let disabled = link_path.with_extension("var.disabled").exists();
        upsert_install_status(db.connection(), &var_name, true, disabled)?;
        installed += 1;
    }
    Ok(installed)
}
