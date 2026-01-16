use crate::infra::db::{upsert_install_status, var_exists_conn};
use crate::infra::fs_util;
use crate::jobs::job_channel::JobReporter;
use crate::infra::paths::{
    addon_packages_dir, addon_switch_root, config_paths, INSTALL_LINK_DIR, MISSING_LINK_DIR,
    TEMP_LINK_DIR,
};
use crate::app::AppState;
use crate::infra::{system_ops, winfs};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeSet;
use std::fs;
use std::path::{Path, PathBuf};
use sqlx::SqlitePool;
use walkdir::WalkDir;

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

#[derive(Serialize)]
struct PackSwitchSetResult {
    status: String,
    name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    addon_path: Option<String>,
}

enum PackSwitchSetOutcome {
    Switched,
    UpdateDbRequired { addon_path: PathBuf },
}

const DEFAULT_SWITCH_NAME: &str = "default";
const MANAGED_DIRS: [&str; 3] = [INSTALL_LINK_DIR, MISSING_LINK_DIR, TEMP_LINK_DIR];

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
        let outcome = set_switch_blocking(&state, &reporter, &args.name)?;
        let result = match outcome {
            PackSwitchSetOutcome::Switched => PackSwitchSetResult {
                status: "switched".to_string(),
                name: args.name,
                addon_path: None,
            },
            PackSwitchSetOutcome::UpdateDbRequired { addon_path } => PackSwitchSetResult {
                status: "update_db_required".to_string(),
                name: args.name,
                addon_path: Some(addon_path.display().to_string()),
            },
        };
        reporter.set_result(serde_json::to_value(result).map_err(|err| err.to_string())?);
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
    if name.eq_ignore_ascii_case(DEFAULT_SWITCH_NAME) {
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
    if old_name.eq_ignore_ascii_case(DEFAULT_SWITCH_NAME) {
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

fn set_switch_blocking(
    state: &AppState,
    reporter: &JobReporter,
    name: &str,
) -> Result<PackSwitchSetOutcome, String> {
    let (_, vampath) = config_paths(state)?;
    let vampath = vampath.ok_or_else(|| "vampath is required in config.json".to_string())?;
    let switch_root = addon_switch_root(&vampath);
    let target = switch_root.join(name);
    fs::create_dir_all(&target).map_err(|err| err.to_string())?;

    let addon_path = addon_packages_dir(&vampath);
    let addon_was_symlink = ensure_addonpackages_dir(&addon_path, reporter)?;

    let managed_dirs = collect_managed_dirs();
    if !addon_was_symlink && managed_dirs_have_real_vars(&addon_path, &managed_dirs) {
        reporter.log(format!(
            "Managed link folders contain real var files; update DB required: {}",
            addon_path.display()
        ));
        return Ok(PackSwitchSetOutcome::UpdateDbRequired { addon_path });
    }

    let default_pack = switch_root.join(DEFAULT_SWITCH_NAME);
    fs::create_dir_all(&default_pack).map_err(|err| err.to_string())?;
    ensure_pack_dirs(&target, &managed_dirs)?;

    for dir_name in &managed_dirs {
        let addon_dir = addon_path.join(dir_name);
        if addon_dir.exists() && !fs_util::is_symlink(&addon_dir) {
            move_controlled_dir(&addon_dir, &default_pack, dir_name, reporter)?;
        }
        let pack_dir = target.join(dir_name);
        ensure_addon_dir_link(&addon_dir, &pack_dir)?;
    }

    let pool = &state.db_pool;
    let handle = tokio::runtime::Handle::current();
    let _ = handle.block_on(refresh_install_status(pool, &vampath));
    let _ = system_ops::rescan_packages(state);
    reporter.log(format!("switch to {}", name));
    Ok(PackSwitchSetOutcome::Switched)
}

fn collect_managed_dirs() -> BTreeSet<String> {
    let mut dirs = BTreeSet::new();
    for name in MANAGED_DIRS {
        dirs.insert(name.to_string());
    }
    dirs
}

fn ensure_addonpackages_dir(addon_path: &Path, reporter: &JobReporter) -> Result<bool, String> {
    if fs_util::is_symlink(addon_path) {
        reporter.log(format!(
            "AddonPackages is a symlink; migrating to folder-based packswitch: {}",
            addon_path.display()
        ));
        if fs::remove_file(addon_path).is_err() {
            fs::remove_dir_all(addon_path).map_err(|err| err.to_string())?;
        }
        fs::create_dir_all(addon_path).map_err(|err| err.to_string())?;
        return Ok(true);
    }
    if addon_path.exists() && !addon_path.is_dir() {
        return Err(format!(
            "AddonPackages is not a directory: {}",
            addon_path.display()
        ));
    }
    fs::create_dir_all(addon_path).map_err(|err| err.to_string())?;
    Ok(false)
}

fn managed_dirs_have_real_vars(addon_path: &Path, managed_dirs: &BTreeSet<String>) -> bool {
    for dir_name in managed_dirs {
        let path = addon_path.join(dir_name);
        if !path.exists() {
            continue;
        }
        let scan_root = resolve_link_dir_target(&path);
        if contains_real_var_files(&scan_root) {
            return true;
        }
    }
    false
}

fn resolve_link_dir_target(path: &Path) -> PathBuf {
    if fs_util::is_symlink(path) {
        if let Ok(target) = winfs::read_link_target(path) {
            if target.is_absolute() {
                return target;
            }
            if let Some(parent) = path.parent() {
                return parent.join(target);
            }
        }
    }
    path.to_path_buf()
}

fn contains_real_var_files(root: &Path) -> bool {
    if !root.exists() {
        return false;
    }
    let walker = WalkDir::new(root).follow_links(false).into_iter();
    for entry in walker {
        let entry = match entry {
            Ok(entry) => entry,
            Err(_) => continue,
        };
        if !entry.file_type().is_file() {
            continue;
        }
        if let Some(ext) = entry.path().extension() {
            if ext.eq_ignore_ascii_case("var") && !fs_util::is_symlink(entry.path()) {
                return true;
            }
        }
    }
    false
}

fn ensure_pack_dirs(pack_root: &Path, managed_dirs: &BTreeSet<String>) -> Result<(), String> {
    for dir_name in managed_dirs {
        let dir = pack_root.join(dir_name);
        if !dir.exists() {
            fs::create_dir_all(&dir).map_err(|err| err.to_string())?;
        }
    }
    Ok(())
}

fn move_controlled_dir(
    src: &Path,
    default_pack: &Path,
    dir_name: &str,
    reporter: &JobReporter,
) -> Result<(), String> {
    if !src.is_dir() {
        return Err(format!("controlled path is not a directory: {}", src.display()));
    }
    if !default_pack.exists() {
        fs::create_dir_all(default_pack).map_err(|err| err.to_string())?;
    }
    let dest = default_pack.join(dir_name);
    let dest = if dest.exists() {
        unique_pack_dir(default_pack, dir_name)
    } else {
        dest
    };
    fs::rename(src, &dest).map_err(|err| err.to_string())?;
    reporter.log(format!(
        "moved existing link folder to {}",
        dest.display()
    ));
    Ok(())
}

fn unique_pack_dir(pack_root: &Path, dir_name: &str) -> PathBuf {
    let mut index = 1;
    loop {
        let candidate = pack_root.join(format!("{dir_name}__from_addonpackages_{index}"));
        if !candidate.exists() {
            return candidate;
        }
        index += 1;
    }
}

fn ensure_addon_dir_link(addon_dir: &Path, pack_dir: &Path) -> Result<(), String> {
    if addon_dir.exists() && fs_util::is_symlink(addon_dir) {
        if let Ok(current_target) = winfs::read_link_target(addon_dir) {
            let cur = current_target.to_string_lossy().to_ascii_lowercase();
            let want = pack_dir.to_string_lossy().to_ascii_lowercase();
            if cur == want {
                return Ok(());
            }
        }
        if fs::remove_file(addon_dir).is_err() {
            fs::remove_dir_all(addon_dir).map_err(|err| err.to_string())?;
        }
    } else if addon_dir.exists() {
        return Err(format!(
            "cannot link over non-symlink directory: {}",
            addon_dir.display()
        ));
    }
    winfs::create_symlink_dir(addon_dir, pack_dir)?;
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::jobs::job_channel::{create_job_channel, JobReporter};
    use super::winfs;
    use std::fs;
    use std::path::{Path, PathBuf};

    fn make_temp_dir(prefix: &str) -> PathBuf {
        let base = std::env::temp_dir();
        let pid = std::process::id();
        for idx in 0..1000 {
            let candidate = base.join(format!("{prefix}_{pid}_{idx}"));
            if !candidate.exists() {
                fs::create_dir_all(&candidate).unwrap();
                return candidate;
            }
        }
        panic!("failed to create temp dir");
    }

    fn write_file(path: &Path) {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        fs::write(path, b"test").unwrap();
    }

    fn symlink_supported() -> bool {
        let root = make_temp_dir("packswitch_symlink_probe");
        let target = root.join("target");
        let link = root.join("link");
        let ok = fs::create_dir_all(&target)
            .map_err(|err| err.to_string())
            .and_then(|_| winfs::create_symlink_dir(&link, &target))
            .is_ok();
        let _ = fs::remove_file(&link).or_else(|_| fs::remove_dir_all(&link));
        let _ = fs::remove_dir_all(&root);
        ok
    }

    fn switch_pack_links(addon_path: &Path, switch_root: &Path, name: &str) -> Result<(), String> {
        let target = switch_root.join(name);
        fs::create_dir_all(&target).map_err(|err| err.to_string())?;
        let managed = collect_managed_dirs();
        ensure_pack_dirs(&target, &managed)?;
        for dir_name in &managed {
            let addon_dir = addon_path.join(dir_name);
            let pack_dir = target.join(dir_name);
            ensure_addon_dir_link(&addon_dir, &pack_dir)?;
        }
        Ok(())
    }

    #[test]
    fn managed_dirs_detect_real_var_in_root() {
        let root = make_temp_dir("packswitch_root_var");
        let addon_path = root.join("AddonPackages");
        let install_dir = addon_path.join(INSTALL_LINK_DIR);
        fs::create_dir_all(&install_dir).unwrap();
        write_file(&install_dir.join("sample.var"));

        let managed = collect_managed_dirs();
        assert!(managed_dirs_have_real_vars(&addon_path, &managed));

        let _ = fs::remove_dir_all(&root);
    }

    #[test]
    fn managed_dirs_detect_real_var_in_nested_dir() {
        let root = make_temp_dir("packswitch_nested_var");
        let addon_path = root.join("AddonPackages");
        let install_dir = addon_path.join(INSTALL_LINK_DIR).join("nested");
        fs::create_dir_all(&install_dir).unwrap();
        write_file(&install_dir.join("deep.VAR"));

        let managed = collect_managed_dirs();
        assert!(managed_dirs_have_real_vars(&addon_path, &managed));

        let _ = fs::remove_dir_all(&root);
    }

    #[test]
    fn managed_dirs_ignore_vars_outside_managed_dirs() {
        let root = make_temp_dir("packswitch_outside_var");
        let addon_path = root.join("AddonPackages");
        let other_dir = addon_path.join("UserStuff");
        fs::create_dir_all(&other_dir).unwrap();
        write_file(&other_dir.join("loose.var"));

        let managed = collect_managed_dirs();
        assert!(!managed_dirs_have_real_vars(&addon_path, &managed));

        let _ = fs::remove_dir_all(&root);
    }

    #[test]
    fn managed_dirs_ignore_non_var_files() {
        let root = make_temp_dir("packswitch_non_var");
        let addon_path = root.join("AddonPackages");
        let install_dir = addon_path.join(INSTALL_LINK_DIR);
        fs::create_dir_all(&install_dir).unwrap();
        write_file(&install_dir.join("note.txt"));

        let managed = collect_managed_dirs();
        assert!(!managed_dirs_have_real_vars(&addon_path, &managed));

        let _ = fs::remove_dir_all(&root);
    }

    #[test]
    fn move_controlled_dir_uses_unique_name_on_collision() {
        let root = make_temp_dir("packswitch_move_collision");
        let default_pack = root.join("default");
        let existing = default_pack.join(INSTALL_LINK_DIR);
        fs::create_dir_all(&existing).unwrap();
        write_file(&existing.join("keep.txt"));

        let src = root.join("AddonPackages").join(INSTALL_LINK_DIR);
        fs::create_dir_all(&src).unwrap();
        write_file(&src.join("moved.txt"));

        let (tx, _rx) = create_job_channel();
        let reporter = JobReporter::new(1, tx);
        move_controlled_dir(&src, &default_pack, INSTALL_LINK_DIR, &reporter).unwrap();

        assert!(!src.exists());
        let moved = default_pack.join(format!("{INSTALL_LINK_DIR}__from_addonpackages_1"));
        assert!(moved.exists());

        let _ = fs::remove_dir_all(&root);
    }

    #[test]
    fn ensure_addon_dir_link_rejects_real_directory() {
        let root = make_temp_dir("packswitch_link_reject");
        let addon_dir = root.join("AddonPackages").join(INSTALL_LINK_DIR);
        let pack_dir = root.join("switches").join("default").join(INSTALL_LINK_DIR);
        fs::create_dir_all(&addon_dir).unwrap();
        fs::create_dir_all(&pack_dir).unwrap();

        let result = ensure_addon_dir_link(&addon_dir, &pack_dir);
        assert!(result.is_err());

        let _ = fs::remove_dir_all(&root);
    }

    #[test]
    fn switch_pack_creates_links_when_missing() {
        if !symlink_supported() {
            return;
        }
        let root = make_temp_dir("packswitch_basic_links");
        let addon_path = root.join("AddonPackages");
        let switch_root = root.join("___AddonPacksSwitch ___");
        fs::create_dir_all(&addon_path).unwrap();

        switch_pack_links(&addon_path, &switch_root, "default").unwrap();
        for dir_name in collect_managed_dirs() {
            let addon_dir = addon_path.join(&dir_name);
            assert!(addon_dir.exists());
            assert!(fs_util::is_symlink(&addon_dir));
        }

        let _ = fs::remove_dir_all(&root);
    }

    #[test]
    fn switch_pack_updates_existing_links() {
        if !symlink_supported() {
            return;
        }
        let root = make_temp_dir("packswitch_update_links");
        let addon_path = root.join("AddonPackages");
        let switch_root = root.join("___AddonPacksSwitch ___");
        fs::create_dir_all(&addon_path).unwrap();

        switch_pack_links(&addon_path, &switch_root, "default").unwrap();
        switch_pack_links(&addon_path, &switch_root, "alt").unwrap();

        for dir_name in collect_managed_dirs() {
            let addon_dir = addon_path.join(&dir_name);
            let target = winfs::read_link_target(&addon_dir).unwrap();
            assert!(target.to_string_lossy().to_ascii_lowercase().contains("alt"));
        }

        let _ = fs::remove_dir_all(&root);
    }

    #[test]
    fn switch_pack_noop_when_target_matches() {
        if !symlink_supported() {
            return;
        }
        let root = make_temp_dir("packswitch_noop_links");
        let addon_path = root.join("AddonPackages");
        let switch_root = root.join("___AddonPacksSwitch ___");
        fs::create_dir_all(&addon_path).unwrap();

        switch_pack_links(&addon_path, &switch_root, "default").unwrap();
        let addon_dir = addon_path.join(INSTALL_LINK_DIR);
        let before = winfs::read_link_target(&addon_dir).unwrap();
        switch_pack_links(&addon_path, &switch_root, "default").unwrap();
        let after = winfs::read_link_target(&addon_dir).unwrap();
        assert_eq!(
            before.to_string_lossy().to_ascii_lowercase(),
            after.to_string_lossy().to_ascii_lowercase()
        );

        let _ = fs::remove_dir_all(&root);
    }

    #[test]
    fn migrate_addonpackages_symlink_to_directory() {
        if !symlink_supported() {
            return;
        }
        let root = make_temp_dir("packswitch_migrate_symlink");
        let addon_path = root.join("AddonPackages");
        let target = root.join("legacy_target");
        fs::create_dir_all(&target).unwrap();
        winfs::create_symlink_dir(&addon_path, &target).unwrap();

        let (tx, _rx) = create_job_channel();
        let reporter = JobReporter::new(1, tx);
        let was_symlink = ensure_addonpackages_dir(&addon_path, &reporter).unwrap();

        assert!(was_symlink);
        assert!(addon_path.exists());
        assert!(!fs_util::is_symlink(&addon_path));

        let _ = fs::remove_dir_all(&root);
    }
}
