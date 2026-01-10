use crate::infra::db::{
    delete_var_related, list_vars, replace_dependencies, replace_hide_fav, replace_scenes,
    upsert_install_status, upsert_var, var_exists_conn, HideFavRecord, SceneRecord, VarRecord,
};
use crate::infra::fs_util;
use crate::jobs::job_channel::JobReporter;
use crate::infra::paths::resolve_var_file_path;
use crate::domain::var_logic::vars_dependencies;
use crate::app::AppState;
use crate::infra::{system_ops, winfs};
use chrono::{DateTime, Local};
use regex::Regex;
use std::collections::HashSet;
use std::fs::{self, File};
use std::io::{BufReader, Read};
use std::path::{Path, PathBuf};
use std::time::SystemTime;
use walkdir::WalkDir;
use zip::ZipArchive;
use sqlx::{Sqlite, SqlitePool, Transaction};

const TIDIED_DIR: &str = "___VarTidied___";
const REDUNDANT_DIR: &str = "___VarRedundant___";
const NOT_COMPLY_DIR: &str = "___VarnotComplyRule___";
const PREVIEW_DIR: &str = "___PreviewPics___";
const STALE_DIR: &str = "___StaleVars___";
const OLD_VERSION_DIR: &str = "___OldVersionVars___";
const DELETED_DIR: &str = "___DeletedVars___";

const INSTALL_LINK_DIR: &str = "___VarsLink___";
const MISSING_LINK_DIR: &str = "___MissingVarLink___";
const TEMP_LINK_DIR: &str = "___TempVarLink___";
const VARS_FOR_INSTALL_FILE: &str = "varsForInstall.txt";

pub async fn run_update_db_job(state: AppState, reporter: JobReporter) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        update_db_blocking(&state, &reporter)
    })
    .await
    .map_err(|err| err.to_string())?
}

fn update_db_blocking(state: &AppState, reporter: &JobReporter) -> Result<(), String> {
    let (varspath, vampath) = config_paths(state)?;
    reporter.log(format!("UpdateDB start: varspath={}", varspath.display()));
    reporter.progress(1);

    let addon_vars = match vampath.as_ref() {
        Some(vampath) => collect_addonpackages_vars(vampath),
        None => Vec::new(),
    };

    let mut vars_for_install = load_vars_for_install();
    for varfile in &addon_vars {
        if fs_util::is_symlink(varfile) {
            continue;
        }
        if let Some(name) = varfile.file_stem().and_then(|s| s.to_str()) {
            if comply_var_name(name) {
                vars_for_install.push(name.to_string());
            }
        }
    }
    vars_for_install = dedup_strings(vars_for_install);
    save_vars_for_install(&vars_for_install)?;

    tidy_vars(
        &varspath,
        if vampath.is_some() { Some(&addon_vars) } else { None },
        reporter,
    )?;
    reporter.progress(10);

    let pool = state.db_pool.clone();
    let handle = tokio::runtime::Handle::current();
    let db_path = crate::infra::db::default_path();
    reporter.log(format!("DB ready: {}", db_path.display()));

    let tidied_dir = varspath.join(TIDIED_DIR);
    let var_files = collect_var_files(
        &tidied_dir,
        &[
            REDUNDANT_DIR,
            NOT_COMPLY_DIR,
            STALE_DIR,
            OLD_VERSION_DIR,
            DELETED_DIR,
        ],
        false,
    );
    if var_files.is_empty() {
        reporter.log("No VAR files found under tidied directory".to_string());
        reporter.progress(100);
        return Ok(());
    }

    let dependency_regex = Regex::new(
        r#"\x22(([^\r\n\x22\x3A\x2E]{1,60})\x2E([^\r\n\x22\x3A\x2E]{1,80})\x2E(\d+|latest))(\x22?\s*)\x3A"#,
    )
    .map_err(|err| err.to_string())?;

    let pool_for_tx = pool.clone();
    let varspath_async = varspath.clone();
    let reporter_async = reporter.clone();
    let vampath_async = vampath.clone();
    let dependency_regex = dependency_regex.clone();
    let var_files = var_files.clone();
    handle.block_on(async move {
        let mut exist_vars: HashSet<String> = HashSet::new();
        let mut tx = pool_for_tx.begin().await.map_err(|err| err.to_string())?;
        for (idx, var_file) in var_files.iter().enumerate() {
            let basename = match var_file.file_stem() {
                Some(stem) => stem.to_string_lossy().to_string(),
                None => continue,
            };
            exist_vars.insert(basename.clone());

            let result = process_var_file(&dependency_regex, &varspath_async, var_file);
            match result {
                Ok(processed) => {
                    upsert_var(&mut tx, &processed.var_record).await?;
                    replace_dependencies(
                        &mut tx,
                        &processed.var_record.var_name,
                        &processed.dependencies,
                    )
                    .await?;
                    replace_scenes(&mut tx, &processed.var_record.var_name, &processed.scenes)
                        .await?;
                    if let Some(vampath) = vampath_async.as_ref() {
                        let entries = collect_hide_fav_records(
                            vampath,
                            &processed.var_record.var_name,
                            &processed.scenes,
                        );
                        replace_hide_fav(&mut tx, &processed.var_record.var_name, &entries)
                            .await?;
                    }
                }
                Err(ProcessError::NotComply(err)) => {
                    reporter_async.log(err);
                    move_to_not_comply(&varspath_async, var_file, &reporter_async)?;
                    continue;
                }
                Err(ProcessError::InvalidPackage(err)) => {
                    reporter_async.log(err);
                    move_to_not_comply(&varspath_async, var_file, &reporter_async)?;
                    continue;
                }
                Err(ProcessError::Io(err)) => return Err(err),
            }

            let progress = 10 + ((idx + 1) * 80 / var_files.len()) as u8;
            if idx % 200 == 0 || idx + 1 == var_files.len() {
                reporter_async.progress(progress.min(90));
            }
        }

        cleanup_missing_vars(&mut tx, &exist_vars, &varspath_async, &reporter_async).await?;
        tx.commit().await.map_err(|err| err.to_string())?;
        Ok::<(), String>(())
    })?;

    reporter.progress(90);

    if !vars_for_install.is_empty() {
        if let Some(vampath) = vampath.as_ref() {
            reporter.log(format!(
                "Install pending vars (varsForInstall): {}",
                vars_for_install.len()
            ));
            let pending = handle.block_on(vars_dependencies(&pool, vars_for_install))?;
            let total = pending.len();
            for (idx, var_name) in pending.iter().enumerate() {
                match handle.block_on(install_var(&pool, &varspath, vampath, var_name)) {
                    Ok(InstallOutcome::Installed) => {
                        reporter.log(format!("{} installed", var_name));
                    }
                    Ok(InstallOutcome::AlreadyInstalled) => {}
                    Err(err) => {
                        reporter.log(format!("install pending failed {} ({})", var_name, err));
                    }
                }
                if total > 0 && (idx % 50 == 0 || idx + 1 == total) {
                    let progress = 90 + ((idx + 1) * 5 / total) as u8;
                    reporter.progress(progress.min(95));
                }
            }
            let _ = clear_vars_for_install();
        } else {
            reporter.log("vampath not set; skip varsForInstall install".to_string());
        }
    }

    reporter.progress(95);

    if let Some(vampath) = vampath.as_ref() {
        handle.block_on(refresh_install_status(&pool, vampath, reporter))?;
        reporter.progress(97);
        match system_ops::rescan_packages(state) {
            Ok(true) => reporter.log("RescanPackages triggered".to_string()),
            Ok(false) => reporter.log("RescanPackages skipped (VaM not running)".to_string()),
            Err(err) => reporter.log(format!("RescanPackages failed ({})", err)),
        }
    } else {
        reporter.log("vampath not set; skip UpdateVarsInstalled/RescanPackages".to_string());
    }

    reporter.progress(100);
    reporter.log("UpdateDB completed".to_string());
    Ok(())
}

fn config_paths(state: &AppState) -> Result<(PathBuf, Option<PathBuf>), String> {
    let cfg = state
        .config
        .read()
        .map_err(|_| "config lock poisoned".to_string())?;
    let varspath = cfg.varspath.as_ref().and_then(|s| normalize_path(s));
    let vampath = cfg.vampath.as_ref().and_then(|s| normalize_path(s));

    let varspath = varspath.ok_or_else(|| "varspath is required in config.json".to_string())?;
    Ok((varspath, vampath))
}

fn normalize_path(value: &str) -> Option<PathBuf> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(PathBuf::from(trimmed))
    }
}

fn read_hide_fav_for_scene(vampath: &Path, var_name: &str, scene_path: &str) -> (bool, bool) {
    let scenepath = Path::new(scene_path)
        .parent()
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_default();
    let scenename = Path::new(scene_path)
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_string();
    let base = crate::infra::paths::prefs_root(vampath)
        .join(var_name)
        .join(&scenepath);
    let pathhide = base.join(format!("{}.hide", scenename));
    let pathfav = base.join(format!("{}.fav", scenename));
    (pathhide.exists(), pathfav.exists())
}

fn collect_hide_fav_records(
    vampath: &Path,
    var_name: &str,
    scenes: &[SceneRecord],
) -> Vec<HideFavRecord> {
    scenes
        .iter()
        .filter_map(|scene| {
            let (hide, fav) =
                read_hide_fav_for_scene(vampath, var_name, &scene.scene_path);
            if hide || fav {
                Some(HideFavRecord {
                    scene_path: scene.scene_path.clone(),
                    hide,
                    fav,
                })
            } else {
                None
            }
        })
        .collect()
}

fn tidy_vars(
    varspath: &Path,
    addon_vars: Option<&[PathBuf]>,
    reporter: &JobReporter,
) -> Result<(), String> {
    let tidied_path = varspath.join(TIDIED_DIR);
    let redundant_path = varspath.join(REDUNDANT_DIR);
    let not_comply_path = varspath.join(NOT_COMPLY_DIR);
    fs::create_dir_all(&tidied_path).map_err(|err| err.to_string())?;
    fs::create_dir_all(&redundant_path).map_err(|err| err.to_string())?;
    fs::create_dir_all(&not_comply_path).map_err(|err| err.to_string())?;

    let mut vars = collect_var_files(
        varspath,
        &[
            TIDIED_DIR,
            REDUNDANT_DIR,
            NOT_COMPLY_DIR,
            STALE_DIR,
            OLD_VERSION_DIR,
            DELETED_DIR,
        ],
        false,
    );

    if let Some(addon_vars) = addon_vars {
        vars.extend(addon_vars.iter().cloned());
    } else {
        reporter.log("vampath not set; skip AddonPackages scan".to_string());
    }

    let total = vars.len();
    for (idx, varfile) in vars.into_iter().enumerate() {
        if !varfile.exists() {
            continue;
        }
        if fs_util::is_symlink(&varfile) {
            continue;
        }
        if !comply_var_file(&varfile) {
            move_to_not_comply(varspath, &varfile, reporter)?;
            continue;
        }

        let varname = varfile
            .file_stem()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_default();
        let parts: Vec<&str> = varname.split('.').collect();
        if parts.len() != 3 {
            move_to_not_comply(varspath, &varfile, reporter)?;
            continue;
        }
        let creator_path = tidied_path.join(parts[0]);
        fs::create_dir_all(&creator_path).map_err(|err| err.to_string())?;
        let filename = varfile
            .file_name()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_else(|| varname.clone() + ".var");
        let dest = creator_path.join(&filename);
        if dest.exists() {
            let redundant_dest = unique_path(&redundant_path, &filename);
            reporter.log(format!(
                "{} has same filename in tidy dir, moved to {}",
                varfile.display(),
                redundant_dest.display()
            ));
            move_file(&varfile, &redundant_dest)?;
        } else {
            move_file(&varfile, &dest)?;
        }

        if idx % 500 == 0 && total > 0 {
            reporter.log(format!("TidyVars progress: {}/{}", idx + 1, total));
        }
    }
    reporter.log("TidyVars completed".to_string());
    Ok(())
}

fn collect_var_files(root: &Path, exclude_dirs: &[&str], follow_links: bool) -> Vec<PathBuf> {
    if !root.exists() {
        return Vec::new();
    }
    let exclude: HashSet<String> = exclude_dirs.iter().map(|s| s.to_string()).collect();
    let mut files = Vec::new();
    let walker = WalkDir::new(root).follow_links(follow_links).into_iter();
    for entry in walker.filter_entry(|e| {
        if e.file_type().is_dir() {
            if let Some(name) = e.file_name().to_str() {
                return !exclude.contains(name);
            }
        }
        true
    }) {
        let entry = match entry {
            Ok(entry) => entry,
            Err(_) => continue,
        };
        if entry.file_type().is_file() {
            if let Some(ext) = entry.path().extension() {
                if ext.eq_ignore_ascii_case("var") {
                    files.push(entry.path().to_path_buf());
                }
            }
        }
    }
    files
}

fn move_to_not_comply(varspath: &Path, src: &Path, reporter: &JobReporter) -> Result<(), String> {
    let not_comply_path = varspath.join(NOT_COMPLY_DIR);
    fs::create_dir_all(&not_comply_path).map_err(|err| err.to_string())?;
    let filename = src
        .file_name()
        .map(|s| s.to_string_lossy().to_string())
        .unwrap_or_else(|| "unknown.var".to_string());
    let dest = unique_path(&not_comply_path, &filename);
    reporter.log(format!(
        "Move non-compliant var to {}",
        dest.display()
    ));
    move_file(src, &dest)
}

fn move_file(src: &Path, dest: &Path) -> Result<(), String> {
    if let Some(parent) = dest.parent() {
        fs::create_dir_all(parent).map_err(|err| err.to_string())?;
    }
    match fs::rename(src, dest) {
        Ok(_) => Ok(()),
        Err(_) => {
            fs::copy(src, dest).map_err(|err| err.to_string())?;
            fs::remove_file(src).map_err(|err| err.to_string())
        }
    }
}

fn unique_path(dir: &Path, filename: &str) -> PathBuf {
    let base = dir.join(filename);
    if !base.exists() {
        return base;
    }
    let stem = Path::new(filename)
        .file_stem()
        .map(|s| s.to_string_lossy().to_string())
        .unwrap_or_else(|| filename.to_string());
    let ext = Path::new(filename)
        .extension()
        .map(|s| s.to_string_lossy().to_string())
        .unwrap_or_default();
    let mut count = 1;
    loop {
        let candidate = if ext.is_empty() {
            dir.join(format!("{}({})", stem, count))
        } else {
            dir.join(format!("{}({}).{}", stem, count, ext))
        };
        if !candidate.exists() {
            return candidate;
        }
        count += 1;
    }
}

fn comply_var_file(path: &Path) -> bool {
    path.file_stem()
        .and_then(|s| s.to_str())
        .map(comply_var_name)
        .unwrap_or(false)
}

fn comply_var_name(name: &str) -> bool {
    let parts: Vec<&str> = name.split('.').collect();
    if parts.len() != 3 {
        return false;
    }
    parts[2].chars().all(|c| c.is_ascii_digit())
}

fn vars_for_install_path() -> PathBuf {
    crate::app::exe_dir().join(VARS_FOR_INSTALL_FILE)
}

fn load_vars_for_install() -> Vec<String> {
    let path = vars_for_install_path();
    let contents = match fs::read_to_string(&path) {
        Ok(contents) => contents,
        Err(_) => return Vec::new(),
    };
    contents
        .lines()
        .map(|line| line.trim().to_string())
        .filter(|line| !line.is_empty())
        .collect()
}

fn save_vars_for_install(vars: &[String]) -> Result<(), String> {
    let path = vars_for_install_path();
    if vars.is_empty() {
        let _ = fs::remove_file(&path);
        return Ok(());
    }
    let contents = vars.join("\r\n");
    fs::write(&path, contents).map_err(|err| err.to_string())
}

fn clear_vars_for_install() -> Result<(), String> {
    save_vars_for_install(&[])
}

fn dedup_strings(items: Vec<String>) -> Vec<String> {
    let mut seen = HashSet::new();
    let mut out = Vec::new();
    for item in items {
        let trimmed = item.trim();
        if trimmed.is_empty() {
            continue;
        }
        let value = trimmed.to_string();
        if seen.insert(value.clone()) {
            out.push(value);
        }
    }
    out
}

fn collect_addonpackages_vars(vampath: &Path) -> Vec<PathBuf> {
    let addon_path = vampath.join("AddonPackages");
    collect_var_files(
        &addon_path,
        &[INSTALL_LINK_DIR, MISSING_LINK_DIR, TEMP_LINK_DIR],
        true,
    )
}

async fn refresh_install_status(
    pool: &SqlitePool,
    vampath: &Path,
    reporter: &JobReporter,
) -> Result<(), String> {
    sqlx::query("DELETE FROM installStatus")
        .execute(pool)
        .await
        .map_err(|err| err.to_string())?;
    let installed_links = fs_util::collect_installed_links(vampath);
    tracing::debug!(
        vampath = %vampath.display(),
        link_count = installed_links.len(),
        "refresh_install_status: collected links"
    );
    let mut installed = 0;
    for (var_name, link_path) in installed_links {
        if !var_exists_conn(pool, &var_name).await? {
            continue;
        }
        let disabled = link_path.with_extension("var.disabled").exists();
        upsert_install_status(pool, &var_name, true, disabled).await?;
        installed += 1;
    }
    reporter.log(format!("UpdateVarsInstalled completed: {}", installed));
    Ok(())
}

enum InstallOutcome {
    Installed,
    AlreadyInstalled,
}

async fn install_var(
    pool: &SqlitePool,
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
    upsert_install_status(pool, var_name, true, false).await?;
    tracing::debug!(
        var_name = %var_name,
        link_path = %link_path.display(),
        dest = %dest.display(),
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

struct ProcessedVar {
    var_record: VarRecord,
    scenes: Vec<SceneRecord>,
    dependencies: Vec<String>,
}

enum ProcessError {
    NotComply(String),
    InvalidPackage(String),
    Io(String),
}

fn process_var_file(
    dependency_regex: &Regex,
    varspath: &Path,
    var_file: &Path,
) -> Result<ProcessedVar, ProcessError> {
    if !comply_var_file(var_file) {
        return Err(ProcessError::NotComply(format!(
            "Invalid var name: {}",
            var_file.display()
        )));
    }

    let basename = var_file
        .file_stem()
        .and_then(|s| s.to_str())
        .ok_or_else(|| ProcessError::NotComply("Missing var name".to_string()))?;
    let parts: Vec<&str> = basename.split('.').collect();
    if parts.len() != 3 {
        return Err(ProcessError::NotComply(format!(
            "Invalid var format: {}",
            basename
        )));
    }
    let creator_name = parts[0].to_string();
    let package_name = parts[1].to_string();
    let version = parts[2].to_string();

    let meta = fs::metadata(var_file).map_err(|err| ProcessError::Io(err.to_string()))?;
    let var_date = meta
        .modified()
        .ok()
        .map(format_system_time);

    // Calculate file size in MB
    let fsize_mb = meta.len() as f64 / (1024.0 * 1024.0);

    let file = File::open(var_file).map_err(|err| ProcessError::Io(err.to_string()))?;
    let reader = BufReader::new(file);
    let mut zip = ZipArchive::new(reader).map_err(|err| ProcessError::Io(err.to_string()))?;

    let meta_json = read_meta_json(&mut zip).map_err(ProcessError::InvalidPackage)?;
    let meta_date = meta_json.meta_date;
    let dependencies = extract_dependencies(dependency_regex, &meta_json.contents);

    let mut counts = Counts::default();
    let mut scenes = Vec::new();

    for i in 0..zip.len() {
        let entry_name = {
            let entry = zip.by_index(i).map_err(|err| ProcessError::Io(err.to_string()))?;
            if entry.is_dir() {
                continue;
            }
            entry.name().to_string()
        };

        let name_lc = entry_name.to_lowercase();
        if let Some(entry_info) = classify_entry(&name_lc) {
            let (typename, is_preset) = entry_info;
            let count = counts.bump(typename);

            let preview_pic = extract_preview(
                &mut zip,
                &entry_name,
                varspath,
                basename,
                typename,
                count,
            )
            .ok();

            if is_scene_record_type(typename) {
                scenes.push(SceneRecord {
                    var_name: basename.to_string(),
                    atom_type: typename.to_string(),
                    preview_pic,
                    scene_path: entry_name.clone(),
                    is_preset,
                    is_loadable: true,
                });
            }
        } else if is_plugin_cs(&name_lc) {
            counts.plugin_cs += 1;
        } else if is_plugin_cslist(&name_lc) {
            counts.plugin_cslist += 1;
        }
    }

    let plugin_count = if counts.plugin_cslist > 0 {
        counts.plugin_cslist
    } else {
        counts.plugin_cs
    };

    let var_record = VarRecord {
        var_name: basename.to_string(),
        creator_name: Some(creator_name),
        package_name: Some(package_name),
        meta_date,
        var_date,
        version: Some(version),
        description: None,
        morph: Some(counts.morphs as i64),
        cloth: Some(counts.clothing as i64),
        hair: Some(counts.hairstyle as i64),
        skin: Some(counts.skin as i64),
        pose: Some(counts.pose as i64),
        scene: Some(counts.scenes as i64),
        script: Some(0),
        plugin: Some(plugin_count as i64),
        asset: Some(counts.assets as i64),
        texture: Some(0),
        look: Some(counts.looks as i64),
        sub_scene: Some(0),
        appearance: Some(0),
        dependency_cnt: Some(dependencies.len() as i64),
        fsize: Some(fsize_mb),
    };

    Ok(ProcessedVar {
        var_record,
        scenes,
        dependencies,
    })
}

async fn cleanup_missing_vars(
    tx: &mut Transaction<'_, Sqlite>,
    exist_vars: &HashSet<String>,
    varspath: &Path,
    reporter: &JobReporter,
) -> Result<(), String> {
    let db_vars = list_vars(tx).await?;
    let mut removed = 0;
    for var_name in db_vars {
        if !exist_vars.contains(&var_name) {
            delete_var_related(tx, &var_name).await?;
            if let Err(err) = delete_preview_pics(varspath, &var_name) {
                reporter.log(format!(
                    "delete preview pics failed {} ({})",
                    var_name, err
                ));
            }
            removed += 1;
        }
    }
    if removed > 0 {
        reporter.log(format!("Removed {} missing var records", removed));
    }
    Ok(())
}

fn delete_preview_pics(varspath: &Path, var_name: &str) -> Result<(), String> {
    let types = [
        "scenes", "looks", "hairstyle", "clothing", "assets", "morphs", "skin", "pose",
    ];
    for typename in types {
        let dir = varspath.join(PREVIEW_DIR).join(typename).join(var_name);
        if dir.exists() {
            fs::remove_dir_all(&dir).map_err(|err| err.to_string())?;
        }
    }
    Ok(())
}

fn format_system_time(time: SystemTime) -> String {
    let dt: DateTime<Local> = time.into();
    dt.format("%Y-%m-%d %H:%M:%S").to_string()
}

fn read_meta_json(zip: &mut ZipArchive<BufReader<File>>) -> Result<MetaJson, String> {
    let mut entry = zip
        .by_name("meta.json")
        .map_err(|_| "meta.json not found".to_string())?;
    let meta_date = zip_datetime_to_string(entry.last_modified());
    let mut contents = String::new();
    entry
        .read_to_string(&mut contents)
        .map_err(|err| err.to_string())?;
    Ok(MetaJson { meta_date, contents })
}

struct MetaJson {
    meta_date: Option<String>,
    contents: String,
}

fn zip_datetime_to_string(dt: Option<zip::DateTime>) -> Option<String> {
    let dt = dt?;
    Some(format!(
        "{:04}-{:02}-{:02} {:02}:{:02}:{:02}",
        dt.year(),
        dt.month(),
        dt.day(),
        dt.hour(),
        dt.minute(),
        dt.second()
    ))
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
    deps.sort();
    deps.dedup();
    deps
}

fn classify_entry(name_lc: &str) -> Option<(&'static str, bool)> {
    if name_lc.starts_with("saves/scene/") && name_lc.ends_with(".json") {
        return Some(("scenes", false));
    }
    if name_lc.starts_with("saves/person/appearance/")
        && (name_lc.ends_with(".json") || name_lc.ends_with(".vac"))
    {
        return Some(("looks", name_lc.ends_with(".json")));
    }
    if (name_lc.starts_with("custom/atom/person/appearance/")
        || name_lc.starts_with("custom/atom/person/general/"))
        && (name_lc.ends_with(".json") || name_lc.ends_with(".vap"))
    {
        return Some(("looks", true));
    }
    if name_lc.starts_with("custom/clothing/")
        && (name_lc.ends_with(".vam") || name_lc.ends_with(".vap"))
    {
        return Some(("clothing", false));
    }
    if name_lc.starts_with("custom/atom/person/clothing/")
        && (name_lc.ends_with(".vam") || name_lc.ends_with(".vap"))
    {
        return Some(("clothing", name_lc.ends_with(".vap")));
    }
    if name_lc.starts_with("custom/hair/")
        && (name_lc.ends_with(".vam") || name_lc.ends_with(".vap"))
    {
        return Some(("hairstyle", false));
    }
    if name_lc.starts_with("custom/atom/person/hair/")
        && (name_lc.ends_with(".vam") || name_lc.ends_with(".vap"))
    {
        return Some(("hairstyle", name_lc.ends_with(".vap")));
    }
    if name_lc.starts_with("custom/assets/") && name_lc.ends_with(".assetbundle") {
        return Some(("assets", false));
    }
    if name_lc.starts_with("custom/atom/person/morphs/")
        && (name_lc.ends_with(".vmi") || name_lc.ends_with(".vap"))
    {
        return Some(("morphs", name_lc.ends_with(".vap")));
    }
    if name_lc.starts_with("custom/atom/person/pose/") && name_lc.ends_with(".vap") {
        return Some(("pose", true));
    }
    if name_lc.starts_with("saves/person/pose/")
        && (name_lc.ends_with(".json") || name_lc.ends_with(".vac"))
    {
        return Some(("pose", name_lc.ends_with(".json")));
    }
    if name_lc.starts_with("custom/atom/person/skin/") && name_lc.ends_with(".vap") {
        return Some(("skin", true));
    }
    None
}

fn is_scene_record_type(typename: &str) -> bool {
    matches!(
        typename,
        "scenes" | "looks" | "clothing" | "hairstyle" | "morphs" | "pose" | "skin"
    )
}

fn is_plugin_cs(name_lc: &str) -> bool {
    (name_lc.starts_with("custom/scripts/") || name_lc.starts_with("custom/atom/person/scripts/"))
        && name_lc.ends_with(".cs")
}

fn is_plugin_cslist(name_lc: &str) -> bool {
    (name_lc.starts_with("custom/scripts/") || name_lc.starts_with("custom/atom/person/scripts/"))
        && name_lc.ends_with(".cslist")
}

fn extract_preview(
    zip: &mut ZipArchive<BufReader<File>>,
    entry_name: &str,
    varspath: &Path,
    var_name: &str,
    typename: &str,
    count: usize,
) -> Result<String, String> {
    let dot = entry_name.rfind('.').ok_or_else(|| "no extension".to_string())?;
    let jpg_entry = format!("{}{}", &entry_name[..dot], ".jpg");
    let mut jpg = zip
        .by_name(&jpg_entry)
        .map_err(|_| "jpg not found".to_string())?;
    let namejpg = Path::new(&jpg_entry)
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("preview")
        .to_lowercase();

    let jpgname = format!("{}{:03}_{}.jpg", typename, count, namejpg);
    let type_dir = varspath.join(PREVIEW_DIR).join(typename).join(var_name);
    fs::create_dir_all(&type_dir).map_err(|err| err.to_string())?;
    let jpg_path = type_dir.join(&jpgname);
    if jpg_path.exists() {
        return Ok(jpgname);
    }
    let mut out = File::create(&jpg_path).map_err(|err| err.to_string())?;
    std::io::copy(&mut jpg, &mut out).map_err(|err| err.to_string())?;
    Ok(jpgname)
}

#[derive(Default)]
struct Counts {
    scenes: usize,
    looks: usize,
    clothing: usize,
    hairstyle: usize,
    assets: usize,
    morphs: usize,
    pose: usize,
    skin: usize,
    plugin_cs: usize,
    plugin_cslist: usize,
}

impl Counts {
    fn bump(&mut self, typename: &str) -> usize {
        match typename {
            "scenes" => {
                self.scenes += 1;
                self.scenes
            }
            "looks" => {
                self.looks += 1;
                self.looks
            }
            "clothing" => {
                self.clothing += 1;
                self.clothing
            }
            "hairstyle" => {
                self.hairstyle += 1;
                self.hairstyle
            }
            "assets" => {
                self.assets += 1;
                self.assets
            }
            "morphs" => {
                self.morphs += 1;
                self.morphs
            }
            "pose" => {
                self.pose += 1;
                self.pose
            }
            "skin" => {
                self.skin += 1;
                self.skin
            }
            _ => 0,
        }
    }
}
