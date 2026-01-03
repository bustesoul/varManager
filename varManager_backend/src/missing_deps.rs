use crate::db::{
    list_dependencies_all, list_dependencies_for_installed, list_dependencies_for_vars,
    list_var_versions, upsert_install_status, var_exists_conn, Db,
};
use crate::paths::{config_paths, resolve_var_file_path, INSTALL_LINK_DIR};
use crate::{job_log, job_progress, job_set_result, winfs, AppState};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fs;
use std::path::Path;
use tokio::runtime::Handle;

#[derive(Deserialize)]
struct MissingDepsArgs {
    scope: String,
    #[serde(default)]
    var_names: Vec<String>,
}

#[derive(Serialize)]
struct MissingDepsResult {
    scope: String,
    missing: Vec<String>,
    installed: Vec<String>,
    install_failed: Vec<String>,
    dependency_count: usize,
}

pub async fn run_missing_deps_job(
    state: AppState,
    id: u64,
    args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        let args = args.ok_or_else(|| "missing_deps args required".to_string())?;
        let args: MissingDepsArgs =
            serde_json::from_value(args).map_err(|err| err.to_string())?;
        missing_deps_blocking(&reporter, args)
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

fn missing_deps_blocking(reporter: &JobReporter, args: MissingDepsArgs) -> Result<(), String> {
    reporter.log(format!("MissingDeps start: scope={}", args.scope));
    reporter.progress(1);

    let db_path = crate::exe_dir().join("varManager.db");
    let db = Db::open(&db_path)?;
    db.ensure_schema()?;

    let deps = match args.scope.as_str() {
        "installed" => list_dependencies_for_installed(db.connection())?,
        "all" => list_dependencies_all(db.connection())?,
        "filtered" => list_dependencies_for_vars(db.connection(), &args.var_names)?,
        _ => return Err(format!("unsupported scope: {}", args.scope)),
    };

    let mut dependencies: Vec<String> = deps
        .into_iter()
        .map(|d| d.trim().to_string())
        .filter(|d| !d.is_empty())
        .collect();
    dependencies.sort();
    dependencies.dedup();

    let auto_install = args.scope == "installed";
    let (varspath, vampath) = if auto_install {
        let (varspath, vampath) = config_paths(&reporter.state)?;
        let vampath = vampath.ok_or_else(|| "vampath is required for install".to_string())?;
        (Some(varspath), Some(vampath))
    } else {
        (None, None)
    };

    let mut missing = Vec::new();
    let mut installed = Vec::new();
    let mut install_failed = Vec::new();

    let total = dependencies.len();
    for (idx, dep) in dependencies.iter().enumerate() {
        let resolved = resolve_dependency(db.connection(), dep)?;
        match resolved {
            ResolvedDep::Found(var_name) => {
                if auto_install {
                    match install_var(
                        reporter,
                        db.connection(),
                        varspath.as_ref().unwrap(),
                        vampath.as_ref().unwrap(),
                        &var_name,
                    ) {
                        Ok(InstallOutcome::Installed) => installed.push(var_name),
                        Ok(InstallOutcome::AlreadyInstalled) => {}
                        Err(err) => {
                            install_failed.push(var_name);
                            reporter.log(format!("install failed: {} ({})", dep, err));
                        }
                    }
                }
            }
            ResolvedDep::MissingVersion { resolved } => {
                missing.push(format!("{}$", dep));
                if auto_install {
                    match install_var(
                        reporter,
                        db.connection(),
                        varspath.as_ref().unwrap(),
                        vampath.as_ref().unwrap(),
                        &resolved,
                    ) {
                        Ok(InstallOutcome::Installed) => installed.push(resolved),
                        Ok(InstallOutcome::AlreadyInstalled) => {}
                        Err(err) => {
                            install_failed.push(resolved);
                            reporter.log(format!("install failed: {} ({})", dep, err));
                        }
                    }
                }
            }
            ResolvedDep::Missing => {
                missing.push(dep.to_string());
            }
        }

        if total > 0 {
            let progress = 5 + ((idx + 1) * 90 / total) as u8;
            if idx % 100 == 0 || idx + 1 == total {
                reporter.progress(progress.min(95));
            }
        }
    }

    missing.sort();
    missing.dedup();
    installed.sort();
    installed.dedup();
    install_failed.sort();
    install_failed.dedup();

    reporter.set_result(serde_json::to_value(MissingDepsResult {
        scope: args.scope,
        missing,
        installed,
        install_failed,
        dependency_count: total,
    })
    .map_err(|err| err.to_string())?);

    reporter.progress(100);
    reporter.log("MissingDeps completed".to_string());
    Ok(())
}

enum ResolvedDep {
    Found(String),
    MissingVersion { resolved: String },
    Missing,
}

fn resolve_dependency(conn: &rusqlite::Connection, dep: &str) -> Result<ResolvedDep, String> {
    let parts: Vec<&str> = dep.split('.').collect();
    if parts.len() != 3 {
        return Ok(ResolvedDep::Missing);
    }
    let creator = parts[0];
    let package = parts[1];
    let version = parts[2];

    if version.eq_ignore_ascii_case("latest") {
        let latest = find_latest_version(conn, creator, package)?;
        return Ok(match latest {
            Some(name) => ResolvedDep::Found(name),
            None => ResolvedDep::Missing,
        });
    }

    if var_exists_conn(conn, dep)? {
        return Ok(ResolvedDep::Found(dep.to_string()));
    }

    if let Ok(requested) = version.parse::<i64>() {
        if let Some(closest) = find_closest_version(conn, creator, package, requested)? {
            return Ok(ResolvedDep::MissingVersion { resolved: closest });
        }
    }

    Ok(ResolvedDep::Missing)
}

fn find_latest_version(
    conn: &rusqlite::Connection,
    creator: &str,
    package: &str,
) -> Result<Option<String>, String> {
    let rows = list_var_versions(conn, creator, package)?;
    let mut best: Option<(i64, String)> = None;
    for (name, version) in rows {
        if let Ok(ver) = version.parse::<i64>() {
            let should_replace = best.as_ref().map(|(cur, _)| ver > *cur).unwrap_or(true);
            if should_replace {
                best = Some((ver, name));
            }
        }
    }
    Ok(best.map(|(_, name)| name))
}

fn find_closest_version(
    conn: &rusqlite::Connection,
    creator: &str,
    package: &str,
    requested: i64,
) -> Result<Option<String>, String> {
    let rows = list_var_versions(conn, creator, package)?;
    let mut versions: Vec<(i64, String)> = rows
        .into_iter()
        .filter_map(|(name, version)| version.parse::<i64>().ok().map(|ver| (ver, name)))
        .collect();
    if versions.is_empty() {
        return Ok(None);
    }
    versions.sort_by_key(|(ver, _)| *ver);
    for (ver, name) in versions.iter() {
        if *ver >= requested {
            return Ok(Some(name.clone()));
        }
    }
    Ok(versions.last().map(|(_, name)| name.clone()))
}

enum InstallOutcome {
    Installed,
    AlreadyInstalled,
}

fn install_var(
    reporter: &JobReporter,
    conn: &rusqlite::Connection,
    varspath: &Path,
    vampath: &Path,
    var_name: &str,
) -> Result<InstallOutcome, String> {
    let link_dir = vampath.join("AddonPackages").join(INSTALL_LINK_DIR);
    fs::create_dir_all(&link_dir).map_err(|err| err.to_string())?;
    let link_path = link_dir.join(format!("{}.var", var_name));

    let disabled_path = link_path.with_extension("var.disabled");
    if disabled_path.exists() {
        fs::remove_file(&disabled_path).map_err(|err| err.to_string())?;
    }

    if link_path.exists() {
        return Ok(InstallOutcome::AlreadyInstalled);
    }

    let dest = resolve_var_file_path(varspath, var_name)?;
    winfs::create_symlink_file(&link_path, &dest)?;
    set_link_times(&link_path, &dest)?;

    upsert_install_status(conn, var_name, true, false)?;
    reporter.log(format!("{} installed", var_name));
    Ok(InstallOutcome::Installed)
}

fn set_link_times(link: &Path, target: &Path) -> Result<(), String> {
    let meta = fs::metadata(target).map_err(|err| err.to_string())?;
    let modified = meta.modified().map_err(|err| err.to_string())?;
    let created = meta.created().unwrap_or(modified);
    winfs::set_symlink_file_times(link, created, modified)
}
