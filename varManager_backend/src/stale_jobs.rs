use crate::db::{delete_var_related_conn, upsert_install_status, Db};
use crate::fs_util;
use crate::job_channel::JobReporter;
use crate::paths::{config_paths, resolve_var_file_path, OLD_VERSION_DIR, STALE_DIR};
use crate::{system_ops, winfs, AppState};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;
use std::fs;
use std::path::Path;

#[derive(Deserialize)]
struct StaleVarsArgs {
    #[serde(default)]
    include_old_versions: bool,
}

#[derive(Serialize)]
struct StaleVarsResult {
    total: usize,
    moved: usize,
    skipped: usize,
    failed: usize,
}

#[derive(Serialize)]
struct CombinedStaleResult {
    stale: StaleVarsResult,
    #[serde(skip_serializing_if = "Option::is_none")]
    old_version: Option<StaleVarsResult>,
}

pub async fn run_stale_vars_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args
            .map(|value| serde_json::from_value::<StaleVarsArgs>(value).map_err(|e| e.to_string()))
            .transpose()?
            .unwrap_or(StaleVarsArgs {
                include_old_versions: false,
            });
        let stale = stale_vars_blocking(&state, &reporter)?;
        let old_version = if args.include_old_versions {
            Some(old_version_vars_blocking(&state, &reporter)?)
        } else {
            None
        };
        reporter.set_result(
            serde_json::to_value(CombinedStaleResult { stale, old_version })
                .map_err(|e| e.to_string())?,
        );
        Ok(())
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_old_version_vars_job(
    state: AppState,
    reporter: JobReporter,
    _args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let stale = stale_vars_blocking(&state, &reporter)?;
        let old_version = Some(old_version_vars_blocking(&state, &reporter)?);
        reporter.set_result(
            serde_json::to_value(CombinedStaleResult { stale, old_version })
                .map_err(|e| e.to_string())?,
        );
        Ok(())
    })
    .await
    .map_err(|err| err.to_string())?
}

#[derive(Clone)]
struct VarInfo {
    var_name: String,
    creator: String,
    package: String,
    version: i64,
    plugin: i64,
    scene: i64,
    look: i64,
}

fn stale_vars_blocking(state: &AppState, reporter: &JobReporter) -> Result<StaleVarsResult, String> {
    reporter.log("StaleVars start".to_string());
    reporter.progress(1);
    let (varspath, vampath) = config_paths(state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;

    let db_path = crate::exe_dir().join("varManager.db");
    let db = Db::open(&db_path)?;
    db.ensure_schema()?;

    let vars = load_vars(db.connection(), false)?;
    let (old_vars, _latest) = find_old_versions(&vars);

    let stale_dir = varspath.join(STALE_DIR);
    fs::create_dir_all(&stale_dir).map_err(|err| err.to_string())?;

    let installed_links = fs_util::collect_installed_links_ci(&vampath);
    let mut moved = 0;
    let mut skipped = 0;
    let mut failed = 0;
    let total = old_vars.len();

    for (idx, oldvar) in old_vars.iter().enumerate() {
        if has_dependents(db.connection(), oldvar)? {
            skipped += 1;
            continue;
        }
        if let Some(path) = installed_links.get(&oldvar.to_ascii_lowercase()) {
            let _ = fs::remove_file(path);
        }
        let src = match resolve_var_file_path(&varspath, oldvar) {
            Ok(path) => path,
            Err(err) => {
                reporter.log(format!("skip {} ({})", oldvar, err));
                failed += 1;
                continue;
            }
        };
        let dest = stale_dir.join(format!("{}.var", oldvar));
        match fs::rename(&src, &dest) {
            Ok(_) => {
                cleanup_var(db.connection(), &varspath, oldvar)?;
                moved += 1;
            }
            Err(err) => {
                reporter.log(format!("move failed {} ({})", oldvar, err));
                failed += 1;
            }
        }
        if total > 0 && (idx % 50 == 0 || idx + 1 == total) {
            let progress = 5 + ((idx + 1) * 90 / total) as u8;
            reporter.progress(progress.min(95));
        }
    }

    let _ = system_ops::open_folder(&stale_dir);
    reporter.log("StaleVars completed".to_string());
    Ok(StaleVarsResult {
        total,
        moved,
        skipped,
        failed,
    })
}

fn old_version_vars_blocking(state: &AppState, reporter: &JobReporter) -> Result<StaleVarsResult, String> {
    reporter.log("OldVersionVars start".to_string());
    reporter.progress(1);
    let (varspath, vampath) = config_paths(state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;

    let db_path = crate::exe_dir().join("varManager.db");
    let db = Db::open(&db_path)?;
    db.ensure_schema()?;

    let vars = load_vars(db.connection(), true)?;
    let (old_vars, latest_by_base) = find_old_versions(&vars);

    let old_dir = varspath.join(OLD_VERSION_DIR);
    fs::create_dir_all(&old_dir).map_err(|err| err.to_string())?;

    let installed_links = fs_util::collect_installed_links_ci(&vampath);
    let mut moved = 0;
    let mut skipped = 0;
    let mut failed = 0;
    let total = old_vars.len();

    for (idx, oldvar) in old_vars.iter().enumerate() {
        if let Some(path) = installed_links.get(&oldvar.to_ascii_lowercase()) {
            let _ = fs::remove_file(path);
            if let Some(base) = base_without_version(oldvar) {
                if let Some(latest_ver) = latest_by_base.get(&base) {
                    let latest_name = format!("{}.{}", base, latest_ver);
                    let _ = install_var(db.connection(), &varspath, &vampath, &latest_name);
                }
            }
        }

        let src = match resolve_var_file_path(&varspath, oldvar) {
            Ok(path) => path,
            Err(err) => {
                reporter.log(format!("skip {} ({})", oldvar, err));
                failed += 1;
                continue;
            }
        };
        let dest = old_dir.join(format!("{}.var", oldvar));
        match fs::rename(&src, &dest) {
            Ok(_) => {
                cleanup_var(db.connection(), &varspath, oldvar)?;
                moved += 1;
            }
            Err(err) => {
                reporter.log(format!("move failed {} ({})", oldvar, err));
                failed += 1;
            }
        }

        if total > 0 && (idx % 50 == 0 || idx + 1 == total) {
            let progress = 5 + ((idx + 1) * 90 / total) as u8;
            reporter.progress(progress.min(95));
        }
    }

    let _ = system_ops::open_folder(&old_dir);
    reporter.log("OldVersionVars completed".to_string());
    Ok(StaleVarsResult {
        total,
        moved,
        skipped,
        failed,
    })
}

fn load_vars(conn: &rusqlite::Connection, filter_old: bool) -> Result<Vec<VarInfo>, String> {
    let mut vars = Vec::new();
    let mut stmt = conn
        .prepare(
            "SELECT varName, creatorName, packageName, version, plugin, scene, look FROM vars",
        )
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map([], |row| {
            let var_name = row.get::<_, String>(0)?;
            let creator = row.get::<_, Option<String>>(1)?.unwrap_or_default();
            let package = row.get::<_, Option<String>>(2)?.unwrap_or_default();
            let version = row.get::<_, Option<String>>(3)?.unwrap_or_default();
            let plugin = row.get::<_, Option<i64>>(4)?.unwrap_or(0);
            let scene = row.get::<_, Option<i64>>(5)?.unwrap_or(0);
            let look = row.get::<_, Option<i64>>(6)?.unwrap_or(0);
            Ok((var_name, creator, package, version, plugin, scene, look))
        })
        .map_err(|err| err.to_string())?;

    for row in rows {
        let (var_name, creator, package, version, plugin, scene, look) =
            row.map_err(|err| err.to_string())?;
        if creator.is_empty() || package.is_empty() {
            continue;
        }
        let version_num = version.parse::<i64>().unwrap_or(0);
        let info = VarInfo {
            var_name,
            creator,
            package,
            version: version_num,
            plugin,
            scene,
            look,
        };
        if filter_old {
            if info.plugin <= 0 || info.scene > 0 || info.look > 0 {
                vars.push(info);
            }
        } else {
            vars.push(info);
        }
    }
    Ok(vars)
}

fn find_old_versions(
    vars: &[VarInfo],
) -> (Vec<String>, HashMap<String, i64>) {
    let mut grouped: HashMap<String, Vec<&VarInfo>> = HashMap::new();
    for info in vars {
        let key = format!("{}.{}", info.creator, info.package);
        grouped.entry(key).or_default().push(info);
    }
    let mut old_vars = Vec::new();
    let mut latest_map = HashMap::new();
    for (base, list) in grouped.iter() {
        if list.len() <= 1 {
            continue;
        }
        let max_ver = list.iter().map(|v| v.version).max().unwrap_or(0);
        latest_map.insert(base.clone(), max_ver);
        for info in list {
            if info.version != max_ver {
                old_vars.push(info.var_name.clone());
            }
        }
    }
    (old_vars, latest_map)
}

fn has_dependents(conn: &rusqlite::Connection, var_name: &str) -> Result<bool, String> {
    let mut stmt = conn
        .prepare("SELECT COUNT(1) FROM dependencies WHERE dependency = ?1")
        .map_err(|err| err.to_string())?;
    let count: i64 = stmt
        .query_row([var_name], |row| row.get(0))
        .map_err(|err| err.to_string())?;
    Ok(count > 0)
}

fn cleanup_var(
    conn: &rusqlite::Connection,
    varspath: &Path,
    var_name: &str,
) -> Result<(), String> {
    delete_var_related_conn(conn, var_name)?;
    conn.execute("DELETE FROM installStatus WHERE varName = ?1", [var_name])
        .map_err(|err| err.to_string())?;
    delete_preview_pics(varspath, var_name)?;
    Ok(())
}

fn delete_preview_pics(varspath: &Path, var_name: &str) -> Result<(), String> {
    let types = [
        "scenes", "looks", "hairstyle", "clothing", "assets", "morphs", "skin", "pose",
    ];
    for typename in types {
        let dir = varspath
            .join(crate::paths::PREVIEW_DIR)
            .join(typename)
            .join(var_name);
        if dir.exists() {
            fs::remove_dir_all(&dir).map_err(|err| err.to_string())?;
        }
    }
    Ok(())
}

fn base_without_version(var_name: &str) -> Option<String> {
    var_name.rsplit_once('.').map(|(base, _)| base.to_string())
}

fn install_var(
    conn: &rusqlite::Connection,
    varspath: &Path,
    vampath: &Path,
    var_name: &str,
) -> Result<(), String> {
    let link_dir = vampath.join("AddonPackages").join(crate::paths::INSTALL_LINK_DIR);
    fs::create_dir_all(&link_dir).map_err(|err| err.to_string())?;
    let link_path = link_dir.join(format!("{}.var", var_name));
    if link_path.exists() {
        return Ok(());
    }
    let dest = resolve_var_file_path(varspath, var_name)?;
    winfs::create_symlink_file(&link_path, &dest)?;
    set_link_times(&link_path, &dest)?;
    upsert_install_status(conn, var_name, true, false)?;
    Ok(())
}

fn set_link_times(link: &Path, target: &Path) -> Result<(), String> {
    let meta = fs::metadata(target).map_err(|err| err.to_string())?;
    let modified = meta.modified().map_err(|err| err.to_string())?;
    let created = meta.created().unwrap_or(modified);
    winfs::set_symlink_file_times(link, created, modified)
}
