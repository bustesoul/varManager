use crate::app::AppState;
use crate::util;
use std::path::{Component, Path, PathBuf};

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
    let cfg = state
        .config
        .read()
        .map_err(|_| "config lock poisoned".to_string())?;
    let varspath = cfg.varspath.as_ref().and_then(|s| normalize_path(s));
    let vampath = cfg.vampath.as_ref().and_then(|s| normalize_path(s));

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

pub fn safe_relative_path(relative: &str, label: &str) -> Result<PathBuf, String> {
    let relative = PathBuf::from(relative.replace('/', "\\"));
    if relative.as_os_str().is_empty() {
        return Err(format!("{} is empty", label));
    }
    for component in relative.components() {
        match component {
            Component::ParentDir | Component::Prefix(_) | Component::RootDir => {
                return Err(format!("invalid {}", label));
            }
            Component::CurDir => {}
            Component::Normal(name) => {
                if name.to_string_lossy().contains(':') {
                    return Err(format!("invalid {}", label));
                }
            }
        }
    }
    Ok(relative)
}

pub fn is_safe_file_name(name: &str) -> bool {
    !name.is_empty()
        && name != "."
        && name != ".."
        && !name.ends_with(['.', ' '])
        && util::valid_file_name(name) == name
}

pub fn validate_file_name(name: &str, label: &str) -> Result<String, String> {
    let name = name.trim();
    if is_safe_file_name(name) {
        Ok(name.to_string())
    } else {
        Err(format!("invalid {}", label))
    }
}

pub fn marker_path_for_file(path: &Path, marker: &str) -> PathBuf {
    let extension = path.extension().and_then(|s| s.to_str()).unwrap_or("");
    if extension.is_empty() {
        path.with_extension(marker)
    } else {
        path.with_extension(format!("{}.{}", extension, marker))
    }
}

pub fn resolve_var_file_path(varspath: &Path, var_name: &str) -> Result<PathBuf, String> {
    let parts: Vec<&str> = var_name.split('.').collect();
    if parts.len() != 3 || parts.iter().any(|part| part.is_empty()) || !is_safe_file_name(var_name)
    {
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn safe_relative_path_rejects_paths_outside_root() {
        assert!(safe_relative_path("../Foo.json", "scene path").is_err());
        assert!(safe_relative_path("C:/Foo.json", "scene path").is_err());
        assert!(safe_relative_path("/Saves/scene/Foo.json", "scene path").is_err());
        assert!(safe_relative_path("Saves/scene/Foo:bar.json", "scene path").is_err());
    }

    #[test]
    fn validate_file_name_rejects_path_like_names() {
        assert_eq!(
            validate_file_name(" creator.package.1 ", "var name").unwrap(),
            "creator.package.1"
        );
        assert!(validate_file_name("creator/package.1", "var name").is_err());
        assert!(validate_file_name("creator:package.1", "var name").is_err());
        assert!(validate_file_name(".", "var name").is_err());
        assert!(validate_file_name("name.", "var name").is_err());
    }

    #[test]
    fn resolve_var_file_path_rejects_path_like_var_names() {
        let root = Path::new("C:\\Vars");

        assert!(resolve_var_file_path(root, "creator/package.name.1").is_err());
        assert!(resolve_var_file_path(root, "creator\\package.name.1").is_err());
        assert!(resolve_var_file_path(root, "creator:package.name.1").is_err());
        assert!(resolve_var_file_path(root, "creator.package").is_err());
    }
}
