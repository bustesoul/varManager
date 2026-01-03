use crate::db::{upsert_install_status, var_exists_conn, Db};
use crate::paths::{config_paths, resolve_var_file_path, INSTALL_LINK_DIR, MISSING_LINK_DIR};
use crate::{job_log, job_progress, job_set_result, winfs, AppState};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fs;
use std::path::{Path, PathBuf};
use tokio::runtime::Handle;
use walkdir::WalkDir;

#[derive(Deserialize)]
struct RebuildLinksArgs {
    #[serde(default = "default_true")]
    include_missing: bool,
}

fn default_true() -> bool {
    true
}

#[derive(Serialize)]
struct RebuildLinksResult {
    total: usize,
    rebuilt: usize,
    skipped: usize,
    failed: usize,
}

pub async fn run_rebuild_links_job(
    state: AppState,
    id: u64,
    args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        let args = args
            .map(|value| serde_json::from_value::<RebuildLinksArgs>(value).map_err(|e| e.to_string()))
            .transpose()?
            .unwrap_or(RebuildLinksArgs { include_missing: true });
        rebuild_links_blocking(&reporter, args)
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

fn rebuild_links_blocking(reporter: &JobReporter, args: RebuildLinksArgs) -> Result<(), String> {
    let (varspath, vampath) = config_paths(&reporter.state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    reporter.log("RebuildLinks start".to_string());
    reporter.progress(1);

    let db_path = crate::exe_dir().join("varManager.db");
    let db = Db::open(&db_path)?;
    db.ensure_schema()?;

    let mut links = collect_symlink_vars(&vampath.join("AddonPackages").join(INSTALL_LINK_DIR), true);
    links.extend(collect_symlink_vars(&vampath.join("AddonPackages"), false));
    if args.include_missing {
        links.extend(collect_symlink_vars(
            &vampath.join("AddonPackages").join(MISSING_LINK_DIR),
            true,
        ));
    }

    let total = links.len();
    let mut rebuilt = 0;
    let mut skipped = 0;
    let mut failed = 0;

    for (idx, link_path) in links.iter().enumerate() {
        let target = match winfs::read_link_target(link_path) {
            Ok(target) => target,
            Err(err) => {
                reporter.log(format!(
                    "skip non-link {} ({})",
                    link_path.display(),
                    err
                ));
                skipped += 1;
                continue;
            }
        };

        let var_name = target
            .file_stem()
            .and_then(|s| s.to_str())
            .map(|s| s.to_string())
            .or_else(|| {
                link_path
                    .file_stem()
                    .and_then(|s| s.to_str())
                    .map(|s| s.to_string())
            });

        let var_name = match var_name {
            Some(name) => name,
            None => {
                skipped += 1;
                continue;
            }
        };

        if !var_exists_conn(db.connection(), &var_name)? {
            reporter.log(format!("skip missing record {}", var_name));
            skipped += 1;
            continue;
        }

        let dest = match resolve_var_file_path(&varspath, &var_name) {
            Ok(path) => path,
            Err(err) => {
                reporter.log(format!("skip {} ({})", var_name, err));
                failed += 1;
                continue;
            }
        };

        if let Err(err) = fs::remove_file(link_path) {
            reporter.log(format!(
                "remove link failed {} ({})",
                link_path.display(),
                err
            ));
        }

        if let Err(err) = winfs::create_symlink_file(link_path, &dest) {
            reporter.log(format!("rebuild failed {} ({})", var_name, err));
            failed += 1;
            continue;
        }

        if let Err(err) = set_link_times(link_path, &dest) {
            reporter.log(format!("set time failed {} ({})", var_name, err));
        }

        let _ = upsert_install_status(db.connection(), &var_name, true, false);
        rebuilt += 1;

        if total > 0 && (idx % 200 == 0 || idx + 1 == total) {
            let progress = 5 + ((idx + 1) * 90 / total) as u8;
            reporter.progress(progress.min(95));
        }
    }

    reporter.set_result(
        serde_json::to_value(RebuildLinksResult {
            total,
            rebuilt,
            skipped,
            failed,
        })
        .map_err(|err| err.to_string())?,
    );

    reporter.progress(100);
    reporter.log("RebuildLinks completed".to_string());
    Ok(())
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

fn set_link_times(link: &Path, target: &Path) -> Result<(), String> {
    let meta = fs::metadata(target).map_err(|err| err.to_string())?;
    let modified = meta.modified().map_err(|err| err.to_string())?;
    let created = meta.created().unwrap_or(modified);
    winfs::set_symlink_file_times(link, created, modified)
}
