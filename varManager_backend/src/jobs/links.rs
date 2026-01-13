use crate::app::AppState;
use crate::infra::db::{upsert_install_status, var_exists_conn};
use crate::infra::fs_util;
use crate::infra::paths::{
    config_paths, resolve_var_file_path, INSTALL_LINK_DIR, MISSING_LINK_DIR,
};
use crate::infra::winfs;
use crate::jobs::job_channel::JobReporter;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::fs;
use std::path::{Path, PathBuf};
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

#[derive(Deserialize)]
struct MoveLinksArgs {
    var_names: Vec<String>,
    target_dir: String,
}

#[derive(Serialize)]
struct MoveLinksResult {
    total: usize,
    moved: usize,
    skipped: usize,
}

#[derive(Deserialize)]
struct MissingLinksArgs {
    links: Vec<MissingLinkItem>,
}

#[derive(Deserialize)]
struct MissingLinkItem {
    missing_var: String,
    dest_var: String,
}

#[derive(Serialize)]
struct MissingLinksResult {
    total: usize,
    created: usize,
    skipped: usize,
    failed: usize,
}

pub async fn run_rebuild_links_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args
            .map(|value| {
                serde_json::from_value::<RebuildLinksArgs>(value).map_err(|e| e.to_string())
            })
            .transpose()?
            .unwrap_or(RebuildLinksArgs {
                include_missing: true,
            });
        rebuild_links_blocking(&state, &reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_move_links_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "links_move args required".to_string())?;
        let args: MoveLinksArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
        move_links_blocking(&state, &reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_missing_links_create_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "links_missing_create args required".to_string())?;
        let args: MissingLinksArgs = serde_json::from_value(args).map_err(|err| err.to_string())?;
        missing_links_create_blocking(&state, &reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

fn rebuild_links_blocking(
    state: &AppState,
    reporter: &JobReporter,
    args: RebuildLinksArgs,
) -> Result<(), String> {
    let (varspath, vampath) = config_paths(state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    reporter.log("RebuildLinks start".to_string());
    reporter.progress(1);

    let pool = &state.db_pool;
    let handle = tokio::runtime::Handle::current();

    let mut links =
        fs_util::collect_symlink_vars(&vampath.join("AddonPackages").join(INSTALL_LINK_DIR), true);
    links.extend(fs_util::collect_symlink_vars(
        &vampath.join("AddonPackages"),
        false,
    ));
    if args.include_missing {
        links.extend(fs_util::collect_symlink_vars(
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
                reporter.log(format!("skip non-link {} ({})", link_path.display(), err));
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

        if !handle.block_on(var_exists_conn(pool, &var_name))? {
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

        let _ = handle.block_on(upsert_install_status(pool, &var_name, true, false));
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

fn move_links_blocking(
    state: &AppState,
    reporter: &JobReporter,
    args: MoveLinksArgs,
) -> Result<(), String> {
    let (_, vampath) = config_paths(state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    let target_dir = args.target_dir.trim();
    if target_dir.is_empty() {
        return Err("target_dir is required".to_string());
    }

    let link_root = vampath.join("AddonPackages").join(INSTALL_LINK_DIR);
    fs::create_dir_all(&link_root).map_err(|err| err.to_string())?;
    let dest_dir = link_root.join(target_dir);
    fs::create_dir_all(&dest_dir).map_err(|err| err.to_string())?;

    let total = args.var_names.len();
    let mut moved = 0;
    let mut skipped = 0;

    for var_name in &args.var_names {
        let match_path = find_link_path(&link_root, var_name);
        let Some(src) = match_path else {
            skipped += 1;
            continue;
        };
        let dest = dest_dir.join(format!("{}.var", var_name));
        if dest.exists() {
            skipped += 1;
            continue;
        }
        match fs::rename(&src, &dest) {
            Ok(_) => moved += 1,
            Err(err) => {
                reporter.log(format!("move failed {} ({})", src.display(), err));
                skipped += 1;
            }
        }
    }

    reporter.set_result(
        serde_json::to_value(MoveLinksResult {
            total,
            moved,
            skipped,
        })
        .map_err(|err| err.to_string())?,
    );
    Ok(())
}

fn missing_links_create_blocking(
    state: &AppState,
    reporter: &JobReporter,
    args: MissingLinksArgs,
) -> Result<(), String> {
    let (varspath, vampath) = config_paths(state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    let missing_dir = vampath.join("AddonPackages").join(MISSING_LINK_DIR);
    fs::create_dir_all(&missing_dir).map_err(|err| err.to_string())?;

    let total = args.links.len();
    let mut created = 0;
    let mut skipped = 0;
    let mut failed = 0;

    for item in args.links {
        let mut missing_var = item.missing_var.trim().to_string();
        let dest_var = item.dest_var.trim();
        if missing_var.is_empty() {
            skipped += 1;
            continue;
        }

        let matches = find_missing_matches(&missing_dir, &missing_var);
        for old in matches {
            let _ = fs::remove_file(&old);
            let disabled = old.with_extension("var.disabled");
            let _ = fs::remove_file(&disabled);
        }

        if dest_var.is_empty() {
            skipped += 1;
            continue;
        }

        if missing_var.to_ascii_lowercase().ends_with(".latest") {
            if let Some((base, _)) = missing_var.rsplit_once('.') {
                if let Some((_, dest_version)) = dest_var.rsplit_once('.') {
                    missing_var = format!("{}.{}", base, dest_version);
                }
            }
        }

        let dest = match resolve_var_file_path(&varspath, dest_var) {
            Ok(path) => path,
            Err(err) => {
                reporter.log(format!("missing link skip {} ({})", dest_var, err));
                failed += 1;
                continue;
            }
        };
        let link_path = missing_dir.join(format!("{}.var", missing_var));
        match winfs::create_symlink_file(&link_path, &dest) {
            Ok(_) => {
                if let Err(err) = set_link_times(&link_path, &dest) {
                    reporter.log(format!("set time failed {} ({})", missing_var, err));
                }
                created += 1;
            }
            Err(err) => {
                reporter.log(format!("link create failed {} ({})", missing_var, err));
                failed += 1;
            }
        }
    }

    reporter.set_result(
        serde_json::to_value(MissingLinksResult {
            total,
            created,
            skipped,
            failed,
        })
        .map_err(|err| err.to_string())?,
    );
    Ok(())
}

fn find_link_path(root: &Path, var_name: &str) -> Option<PathBuf> {
    let target = format!("{}.var", var_name);
    let walker = WalkDir::new(root).follow_links(false).into_iter();
    for entry in walker.filter_map(|e| e.ok()) {
        if entry.file_type().is_file()
            && entry
                .file_name()
                .to_string_lossy()
                .eq_ignore_ascii_case(&target)
        {
            return Some(entry.path().to_path_buf());
        }
    }
    None
}

fn find_missing_matches(root: &Path, missing_var: &str) -> Vec<PathBuf> {
    let mut matches = Vec::new();
    let is_latest = missing_var.to_ascii_lowercase().ends_with(".latest");
    let target_base = if is_latest {
        missing_var
            .rsplit_once('.')
            .map(|(base, _)| base.to_string())
    } else {
        None
    };
    let walker = WalkDir::new(root).follow_links(false).into_iter();
    for entry in walker.filter_map(|e| e.ok()) {
        if entry.file_type().is_file() {
            let file_name = entry.file_name().to_string_lossy().to_string();
            if !file_name.to_ascii_lowercase().ends_with(".var") {
                continue;
            }
            if !is_latest {
                if file_name.eq_ignore_ascii_case(&format!("{}.var", missing_var)) {
                    matches.push(entry.path().to_path_buf());
                }
            } else if let Some(base) = &target_base {
                if let Some(stem) = Path::new(&file_name).file_stem().and_then(|s| s.to_str()) {
                    if stem.starts_with(base) {
                        matches.push(entry.path().to_path_buf());
                    }
                }
            }
        }
    }
    matches
}

fn set_link_times(link: &Path, target: &Path) -> Result<(), String> {
    let meta = fs::metadata(target).map_err(|err| err.to_string())?;
    let modified = meta.modified().map_err(|err| err.to_string())?;
    let created = meta.created().unwrap_or(modified);
    winfs::set_symlink_file_times(link, created, modified)
}
