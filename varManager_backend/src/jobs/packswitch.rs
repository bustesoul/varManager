use crate::infra::db::{upsert_install_status, var_exists_conn};
use crate::infra::fs_util;
use crate::jobs::job_channel::JobReporter;
use crate::infra::paths::{addon_packages_dir, addon_switch_root, config_paths};
use crate::app::AppState;
use crate::infra::{system_ops, winfs};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fs;
use std::path::Path;
use sqlx::SqlitePool;

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
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "packswitch_add args required".to_string())?;
        let args: PackSwitchArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
        add_switch_blocking(&state, &reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_packswitch_delete_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "packswitch_delete args required".to_string())?;
        let args: PackSwitchArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
        delete_switch_blocking(&state, &reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_packswitch_rename_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "packswitch_rename args required".to_string())?;
        let args: PackSwitchRenameArgs =
            serde_json::from_value(args).map_err(|err| err.to_string())?;
        rename_switch_blocking(&state, &reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_packswitch_set_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "packswitch_set args required".to_string())?;
        let args: PackSwitchArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
        set_switch_blocking(&state, &reporter, &args.name)?;
        reporter.set_result(
            serde_json::to_value(PackSwitchResult { name: args.name })
                .map_err(|err| err.to_string())?,
        );
        Ok(())
    })
    .await
    .map_err(|err| err.to_string())?
}

fn add_switch_blocking(state: &AppState, reporter: &JobReporter, args: PackSwitchArgs) -> Result<(), String> {
    let (_, vampath) = config_paths(state)?;
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

fn delete_switch_blocking(state: &AppState, reporter: &JobReporter, args: PackSwitchArgs) -> Result<(), String> {
    let (_, vampath) = config_paths(state)?;
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
    state: &AppState,
    reporter: &JobReporter,
    args: PackSwitchRenameArgs,
) -> Result<(), String> {
    let (_, vampath) = config_paths(state)?;
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
    set_switch_blocking(state, reporter, new_name)?;
    reporter.set_result(
        serde_json::to_value(PackSwitchResult {
            name: new_name.to_string(),
        })
        .map_err(|err| err.to_string())?,
    );
    Ok(())
}

fn set_switch_blocking(state: &AppState, reporter: &JobReporter, name: &str) -> Result<(), String> {
    let (_, vampath) = config_paths(state)?;
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
    let pool = &state.db_pool;
    let handle = tokio::runtime::Handle::current();
    let _ = handle.block_on(refresh_install_status(pool, &vampath));
    let _ = system_ops::rescan_packages(state);
    reporter.log(format!("switch to {}", name));
    Ok(())
}

async fn refresh_install_status(pool: &SqlitePool, vampath: &Path) -> Result<usize, String> {
    sqlx::query("DELETE FROM installStatus")
        .execute(pool)
        .await
        .map_err(|err| err.to_string())?;

    let installed_links = fs_util::collect_installed_links(vampath);
    let mut installed = 0;
    for (var_name, link_path) in installed_links {
        if !var_exists_conn(pool, &var_name).await? {
            continue;
        }
        let disabled = link_path.with_extension("var.disabled").exists();
        upsert_install_status(pool, &var_name, true, disabled).await?;
        installed += 1;
    }
    Ok(installed)
}
