use crate::AppState;
use std::path::{Path, PathBuf};

pub const TIDIED_DIR: &str = "___VarTidied___";
pub const INSTALL_LINK_DIR: &str = "___VarsLink___";
pub const MISSING_LINK_DIR: &str = "___MissingVarLink___";
pub const TEMP_LINK_DIR: &str = "___TempVarLink___";
pub const PREVIEW_DIR: &str = "___PreviewPics___";
pub const DELETED_DIR: &str = "___DeletedVars___";
pub const STALE_DIR: &str = "___StaleVars___";
pub const OLD_VERSION_DIR: &str = "___OldVersionVars___";
pub const ADDON_PACK_SWITCH_DIR: &str = "___AddonPacksSwitch ___";
pub const ADDON_PACKAGES_DIR: &str = "AddonPackages";
pub const ADDON_PREFS_DIR: &str = "AddonPackagesFilePrefs";
pub const PLUGIN_DATA_DIR: &str = "Custom";
pub const FEELFAR_DIR: &str = "PluginData";
pub const FEELFAR_NAME: &str = "feelfar";
pub const CACHE_DIR: &str = "Cache";
pub const LOADSCENE_FILE: &str = "loadscene.json";

pub fn config_paths(state: &AppState) -> Result<(PathBuf, Option<PathBuf>), String> {
    let varspath = state
        .config
        .varspath
        .as_ref()
        .and_then(|s| normalize_path(s));
    let vampath = state
        .config
        .vampath
        .as_ref()
        .and_then(|s| normalize_path(s));

    let varspath = varspath.ok_or_else(|| "varspath is required in config.json".to_string())?;
    Ok((varspath, vampath))
}

pub fn normalize_path(value: &str) -> Option<PathBuf> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(PathBuf::from(trimmed))
    }
}

pub fn resolve_var_file_path(varspath: &Path, var_name: &str) -> Result<PathBuf, String> {
    let parts: Vec<&str> = var_name.split('.').collect();
    if parts.len() != 3 {
        return Err(format!("invalid var name: {}", var_name));
    }
    let creator = parts[0];
    let candidate = varspath
        .join(TIDIED_DIR)
        .join(creator)
        .join(format!("{}.var", var_name));
    if candidate.exists() {
        return Ok(candidate);
    }
    let fallback = varspath.join(format!("{}.var", var_name));
    if fallback.exists() {
        return Ok(fallback);
    }
    Err(format!("var file not found for {}", var_name))
}

pub fn addon_packages_dir(vampath: &Path) -> PathBuf {
    vampath.join(ADDON_PACKAGES_DIR)
}

pub fn missing_links_dir(vampath: &Path) -> PathBuf {
    addon_packages_dir(vampath).join(MISSING_LINK_DIR)
}

pub fn install_links_dir(vampath: &Path) -> PathBuf {
    addon_packages_dir(vampath).join(INSTALL_LINK_DIR)
}

pub fn temp_links_dir(vampath: &Path) -> PathBuf {
    addon_packages_dir(vampath).join(TEMP_LINK_DIR)
}

pub fn addon_switch_root(vampath: &Path) -> PathBuf {
    vampath.join(ADDON_PACK_SWITCH_DIR)
}

pub fn prefs_root(vampath: &Path) -> PathBuf {
    vampath.join(ADDON_PREFS_DIR)
}

pub fn feelfar_dir(vampath: &Path) -> PathBuf {
    vampath
        .join(PLUGIN_DATA_DIR)
        .join(FEELFAR_DIR)
        .join(FEELFAR_NAME)
}

pub fn loadscene_path(vampath: &Path) -> PathBuf {
    feelfar_dir(vampath).join(LOADSCENE_FILE)
}
