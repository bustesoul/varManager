use crate::infra::paths::INSTALL_LINK_DIR;
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

pub fn is_symlink(path: &Path) -> bool {
    fs::symlink_metadata(path)
        .map(|meta| meta.file_type().is_symlink())
        .unwrap_or(false)
}

pub fn collect_symlink_vars(root: &Path, recursive: bool) -> Vec<PathBuf> {
    if !root.exists() {
        return Vec::new();
    }
    let scan_root = resolve_symlink_root(root);
    if !scan_root.exists() {
        return Vec::new();
    }
    let mut files = Vec::new();
    let walker = WalkDir::new(&scan_root)
        .follow_links(false)
        .max_depth(if recursive { usize::MAX } else { 1 })
        .into_iter();
    for entry in walker {
        let entry = match entry {
            Ok(entry) => entry,
            Err(_) => continue,
        };
        if entry.file_type().is_file() || entry.file_type().is_symlink() {
            if let Some(ext) = entry.path().extension() {
                if ext.eq_ignore_ascii_case("var") && is_symlink(entry.path()) {
                    files.push(entry.path().to_path_buf());
                }
            }
        }
    }
    files
}

fn resolve_symlink_root(root: &Path) -> PathBuf {
    if !is_symlink(root) {
        return root.to_path_buf();
    }
    if let Ok(target) = fs::read_link(root) {
        if target.is_absolute() {
            return target;
        }
        if let Some(parent) = root.parent() {
            return parent.join(target);
        }
    }
    root.to_path_buf()
}

pub fn collect_installed_links(vampath: &Path) -> HashMap<String, PathBuf> {
    let mut installed = HashMap::new();
    let install_dir = vampath.join("AddonPackages").join(INSTALL_LINK_DIR);
    for link in collect_symlink_vars(&install_dir, true) {
        if let Some(stem) = link.file_stem().and_then(|s| s.to_str()) {
            installed.insert(stem.to_string(), link);
        }
    }
    for link in collect_symlink_vars(&vampath.join("AddonPackages"), false) {
        if let Some(stem) = link.file_stem().and_then(|s| s.to_str()) {
            installed.insert(stem.to_string(), link);
        }
    }
    installed
}

pub fn collect_installed_links_ci(vampath: &Path) -> HashMap<String, PathBuf> {
    collect_installed_links(vampath)
        .into_iter()
        .map(|(name, path)| (name.to_ascii_lowercase(), path))
        .collect()
}
