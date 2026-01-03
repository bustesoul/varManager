use crate::db::{upsert_install_status, Db};
use crate::paths::{config_paths, resolve_var_file_path, INSTALL_LINK_DIR};
use crate::var_logic::{resolve_var_exist_name, vars_dependencies};
use crate::{job_log, job_progress, job_set_result, winfs, AppState};
use chrono::{DateTime, Local};
use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashSet;
use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};
use tokio::runtime::Handle;
use walkdir::WalkDir;

#[derive(Deserialize)]
struct SavesDepsArgs {}

#[derive(Deserialize)]
struct LogDepsArgs {}

#[derive(Serialize)]
struct DepsJobResult {
    missing: Vec<String>,
    installed: Vec<String>,
    dependency_count: usize,
}

enum InstallOutcome {
    Installed,
    AlreadyInstalled,
}

pub async fn run_saves_deps_job(
    state: AppState,
    id: u64,
    _args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        let args = SavesDepsArgs {};
        saves_deps_blocking(&reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_log_deps_job(
    state: AppState,
    id: u64,
    _args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        let args = LogDepsArgs {};
        log_deps_blocking(&reporter, args)
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

fn saves_deps_blocking(reporter: &JobReporter, _args: SavesDepsArgs) -> Result<(), String> {
    let (varspath, vampath) = config_paths(&reporter.state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    reporter.log("SavesDeps start".to_string());
    reporter.progress(1);

    let db_path = crate::exe_dir().join("varManager.db");
    let db = Db::open(&db_path)?;
    db.ensure_schema()?;

    db.connection()
        .execute("DELETE FROM savedepens", [])
        .map_err(|err| err.to_string())?;

    let mut files = collect_files(&vampath.join("Saves"), "json");
    files.extend(collect_files(&vampath.join("Custom"), "vap"));

    let regex = dependency_regex()?;
    let total = files.len();
    for (idx, path) in files.iter().enumerate() {
        let save_path = normalize_save_path(&vampath, path);
        let contents = fs::read_to_string(path).map_err(|err| err.to_string())?;
        let deps = extract_dependencies(&regex, &contents);
        let mod_time = format_system_time(
            fs::metadata(path)
                .and_then(|m| m.modified())
                .unwrap_or_else(|_| std::time::SystemTime::now()),
        );
        for dep in deps {
            db.connection()
                .execute(
                    "INSERT INTO savedepens (varName, dependency, SavePath, ModiDate) VALUES (?1, ?2, ?3, ?4)",
                    rusqlite::params![Option::<String>::None, dep, &save_path, &mod_time],
                )
                .map_err(|err| err.to_string())?;
        }

        if total > 0 && (idx % 200 == 0 || idx + 1 == total) {
            let progress = 5 + ((idx + 1) * 60 / total) as u8;
            reporter.progress(progress.min(80));
        }
    }

    let mut dependencies = list_saved_dependencies(db.connection())?;
    let dependencies2 = vars_dependencies(db.connection(), dependencies.clone())?;
    dependencies.extend(dependencies2);
    dependencies = distinct(dependencies);

    let installed = collect_installed_names(&vampath);
    dependencies.retain(|dep| !installed.contains(dep));

    let (missing, installed_now) =
        install_missing_dependencies(reporter, db.connection(), &varspath, &vampath, &dependencies)?;

    reporter.set_result(
        serde_json::to_value(DepsJobResult {
            missing,
            installed: installed_now,
            dependency_count: dependencies.len(),
        })
        .map_err(|err| err.to_string())?,
    );

    reporter.progress(100);
    reporter.log("SavesDeps completed".to_string());
    Ok(())
}

fn log_deps_blocking(reporter: &JobReporter, _args: LogDepsArgs) -> Result<(), String> {
    let (varspath, vampath) = config_paths(&reporter.state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    reporter.log("LogDeps start".to_string());
    reporter.progress(1);

    let log_path = locate_log_file()?;
    if !log_path.exists() {
        return Err("output_log.txt not found".to_string());
    }

    let mut contents = String::new();
    fs::File::open(&log_path)
        .and_then(|mut f| f.read_to_string(&mut contents))
        .map_err(|err| err.to_string())?;

    let regex = Regex::new(
        r"Missing\s+addon\s+package\s+(?<depens>[^\x3A\x2E]{1,60}\x2E[^\x3A\x2E]{1,80}\x2E(?:\d+|latest))\s+that\s+package(?<package>[^\x3A\x2E]{1,60}\x2E[^\x3A\x2E]{1,80}\x2E\d+)",
    )
    .map_err(|err| err.to_string())?;

    let mut dependencies = Vec::new();
    for caps in regex.captures_iter(&contents) {
        if let Some(dep) = caps.name("depens") {
            dependencies.push(dep.as_str().to_string());
        }
    }
    dependencies = distinct(dependencies);

    let db_path = crate::exe_dir().join("varManager.db");
    let db = Db::open(&db_path)?;
    db.ensure_schema()?;

    let (missing, installed_now) =
        install_missing_dependencies(reporter, db.connection(), &varspath, &vampath, &dependencies)?;

    reporter.set_result(
        serde_json::to_value(DepsJobResult {
            missing,
            installed: installed_now,
            dependency_count: dependencies.len(),
        })
        .map_err(|err| err.to_string())?,
    );

    reporter.progress(100);
    reporter.log("LogDeps completed".to_string());
    Ok(())
}

fn dependency_regex() -> Result<Regex, String> {
    Regex::new(
        r"\x22(([^\r\n\x22\x3A\x2E]{1,60})\x2E([^\r\n\x22\x3A\x2E]{1,80})\x2E(\d+|latest))(\x22?\s*)\x3A",
    )
    .map_err(|err| err.to_string())
}

fn extract_dependencies(regex: &Regex, json: &str) -> Vec<String> {
    let mut deps = Vec::new();
    for cap in regex.captures_iter(json) {
        if let Some(m) = cap.get(1) {
            let mut dep = m.as_str().to_string();
            if let Some(idx) = dep.find('/') {
                dep = dep[idx + 1..].to_string();
            }
            deps.push(dep);
        }
    }
    distinct(deps)
}

fn collect_files(root: &Path, ext: &str) -> Vec<PathBuf> {
    if !root.exists() {
        return Vec::new();
    }
    let mut files = Vec::new();
    for entry in WalkDir::new(root).into_iter().filter_map(|e| e.ok()) {
        if entry.file_type().is_file() {
            if let Some(extension) = entry.path().extension() {
                if extension.eq_ignore_ascii_case(ext) {
                    files.push(entry.path().to_path_buf());
                }
            }
        }
    }
    files
}

fn normalize_save_path(vampath: &Path, file: &Path) -> String {
    let rel = file.strip_prefix(vampath).unwrap_or(file);
    let mut path = rel.to_string_lossy().to_string();
    if path.len() > 255 {
        path = path[path.len() - 255..].to_string();
    }
    path
}

fn format_system_time(time: std::time::SystemTime) -> String {
    let dt: DateTime<Local> = time.into();
    dt.format("%Y-%m-%d %H:%M:%S").to_string()
}

fn list_saved_dependencies(conn: &rusqlite::Connection) -> Result<Vec<String>, String> {
    let mut stmt = conn
        .prepare("SELECT dependency FROM savedepens")
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map([], |row| row.get::<_, Option<String>>(0))
        .map_err(|err| err.to_string())?;
    let mut deps = Vec::new();
    for row in rows {
        if let Some(dep) = row.map_err(|err| err.to_string())? {
            deps.push(dep);
        }
    }
    Ok(distinct(deps))
}

fn install_missing_dependencies(
    reporter: &JobReporter,
    conn: &rusqlite::Connection,
    varspath: &Path,
    vampath: &Path,
    dependencies: &[String],
) -> Result<(Vec<String>, Vec<String>), String> {
    let mut missing = Vec::new();
    let mut installed = Vec::new();
    for dep in dependencies {
        let mut exist = resolve_var_exist_name(conn, dep)?;
        if let Some(stripped) = exist.strip_suffix('$') {
            exist = stripped.to_string();
            missing.push(format!("{}$", dep));
        }
        if exist != "missing" {
            match install_var(reporter, conn, varspath, vampath, &exist) {
                Ok(InstallOutcome::Installed) => installed.push(exist),
                Ok(InstallOutcome::AlreadyInstalled) => {}
                Err(err) => reporter.log(format!("install failed {} ({})", dep, err)),
            }
        } else {
            missing.push(dep.to_string());
        }
    }
    missing = distinct(missing);
    installed = distinct(installed);
    Ok((missing, installed))
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

fn collect_installed_names(vampath: &Path) -> HashSet<String> {
    let mut names = HashSet::new();
    let install_dir = vampath.join("AddonPackages").join(INSTALL_LINK_DIR);
    for path in collect_symlink_vars(&install_dir, true) {
        if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
            names.insert(stem.to_string());
        }
    }
    for path in collect_symlink_vars(&vampath.join("AddonPackages"), false) {
        if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
            names.insert(stem.to_string());
        }
    }
    names
}

fn collect_symlink_vars(root: &Path, recursive: bool) -> Vec<PathBuf> {
    if !root.exists() {
        return Vec::new();
    }
    let mut files = Vec::new();
    let walker = WalkDir::new(root)
        .follow_links(false)
        .max_depth(if recursive { usize::MAX } else { 1 })
        .into_iter();
    for entry in walker {
        let entry = match entry {
            Ok(entry) => entry,
            Err(_) => continue,
        };
        if entry.file_type().is_file() {
            if let Some(ext) = entry.path().extension() {
                if ext.eq_ignore_ascii_case("var") {
                    if is_symlink(entry.path()) {
                        files.push(entry.path().to_path_buf());
                    }
                }
            }
        }
    }
    files
}

fn is_symlink(path: &Path) -> bool {
    fs::symlink_metadata(path)
        .map(|meta| meta.file_type().is_symlink())
        .unwrap_or(false)
}

fn locate_log_file() -> Result<PathBuf, String> {
    let user_profile = std::env::var("USERPROFILE").map_err(|err| err.to_string())?;
    Ok(PathBuf::from(user_profile)
        .join("AppData")
        .join("LocalLow")
        .join("MeshedVR")
        .join("VaM")
        .join("output_log.txt"))
}

fn distinct(mut items: Vec<String>) -> Vec<String> {
    items.sort();
    items.dedup();
    items
}
