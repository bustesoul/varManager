use crate::paths::{addon_packages_dir, loadscene_path};
use crate::{exe_dir, util, AppState};
use serde_json::json;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use sysinfo::{ProcessesToUpdate, System};

const DEFAULT_VAM_EXEC: &str = "VaM (Desktop Mode).bat";
const DEFAULT_DOWNLOADER_REL: &str = "plugin\\vam_downloader.exe";

pub fn run_downloader(state: &AppState, urls: &[String]) -> Result<(), String> {
    let urls: Vec<String> = urls
        .iter()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
        .collect();
    if urls.is_empty() {
        return Err("no download urls provided".to_string());
    }

    let exec_path = resolve_downloader_path(state);
    if !exec_path.exists() {
        return Err(format!("downloader not found: {}", exec_path.display()));
    }
    let save_path = resolve_downloader_save_path(state)?;
    if !save_path.exists() {
        fs::create_dir_all(&save_path).map_err(|err| err.to_string())?;
    }

    let temp_file = util::temp_dir_file("vam_download")?;
    fs::write(&temp_file, urls.join("\r\n")).map_err(|err| err.to_string())?;

    let status = Command::new(&exec_path)
        .current_dir(exe_dir())
        .arg(&temp_file)
        .arg(&save_path)
        .status()
        .map_err(|err| err.to_string())?;

    let _ = fs::remove_file(&temp_file);

    if !status.success() {
        let code = status.code().unwrap_or(-1);
        return Err(format!("downloader exit code {}", code));
    }
    Ok(())
}

pub fn start_vam(state: &AppState) -> Result<(), String> {
    let cfg = state
        .config
        .read()
        .map_err(|_| "config lock poisoned".to_string())?;
    let vampath = cfg
        .vampath
        .as_ref()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .map(PathBuf::from)
        .ok_or_else(|| "vampath is required in config.json".to_string())?;
    let exec_name = cfg
        .vam_exec
        .as_ref()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| DEFAULT_VAM_EXEC.to_string());
    let exec_path = resolve_relative(&vampath, &exec_name);
    if !exec_path.exists() {
        return Err(format!("vam executable not found: {}", exec_path.display()));
    }

    if is_cmd_script(&exec_path) {
        let exec = format!("\"{}\"", exec_path.to_string_lossy());
        Command::new("cmd")
            .args(["/C", exec.as_str()])
            .current_dir(&vampath)
            .spawn()
            .map_err(|err| err.to_string())?;
    } else {
        Command::new(&exec_path)
            .current_dir(&vampath)
            .spawn()
            .map_err(|err| err.to_string())?;
    }
    Ok(())
}

pub fn rescan_packages(state: &AppState) -> Result<bool, String> {
    let cfg = state
        .config
        .read()
        .map_err(|_| "config lock poisoned".to_string())?;
    let vampath = cfg
        .vampath
        .as_ref()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .map(PathBuf::from)
        .ok_or_else(|| "vampath is required in config.json".to_string())?;

    let mut system = System::new();
    system.refresh_processes(ProcessesToUpdate::All, false);
    let is_running = system.processes().values().any(|proc_| {
        let name = proc_.name().to_string_lossy().to_ascii_lowercase();
        name == "vam" || name == "vam.exe"
    });
    if !is_running {
        return Ok(false);
    }

    let loadscene = loadscene_path(&vampath);
    if let Some(parent) = loadscene.parent() {
        fs::create_dir_all(parent).map_err(|err| err.to_string())?;
    }
    if loadscene.exists() {
        let _ = fs::remove_file(&loadscene);
    }
    let payload = json!({ "rescan": "true" });
    fs::write(&loadscene, payload.to_string()).map_err(|err| err.to_string())?;
    Ok(true)
}

pub fn open_folder(path: &Path) -> Result<(), String> {
    if !path.exists() {
        return Err(format!("path not found: {}", path.display()));
    }
    Command::new("explorer.exe")
        .arg(path)
        .spawn()
        .map_err(|err| err.to_string())?;
    Ok(())
}

fn resolve_downloader_path(state: &AppState) -> PathBuf {
    let cfg = match state.config.read() {
        Ok(cfg) => cfg,
        Err(err) => err.into_inner(),
    };
    if let Some(path) = cfg
        .downloader_path
        .as_ref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
    {
        let candidate = PathBuf::from(path);
        if candidate.is_absolute() {
            return candidate;
        }
        return exe_dir().join(candidate);
    }
    exe_dir().join(DEFAULT_DOWNLOADER_REL)
}

fn resolve_downloader_save_path(state: &AppState) -> Result<PathBuf, String> {
    let cfg = state
        .config
        .read()
        .map_err(|_| "config lock poisoned".to_string())?;
    if let Some(path) = cfg
        .downloader_save_path
        .as_ref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
    {
        let candidate = PathBuf::from(path);
        if candidate.is_absolute() {
            return Ok(candidate);
        }
        if let Some(vampath) = cfg.vampath.as_ref() {
            return Ok(PathBuf::from(vampath).join(candidate));
        }
        return Ok(exe_dir().join(candidate));
    }

    let vampath = cfg
        .vampath
        .as_ref()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .map(PathBuf::from)
        .ok_or_else(|| "vampath is required in config.json".to_string())?;
    Ok(addon_packages_dir(&vampath))
}

fn resolve_relative(root: &Path, path: &str) -> PathBuf {
    let candidate = PathBuf::from(path);
    if candidate.is_absolute() {
        candidate
    } else {
        root.join(candidate)
    }
}

fn is_cmd_script(path: &Path) -> bool {
    path.extension()
        .and_then(|ext| ext.to_str())
        .map(|ext| ext.eq_ignore_ascii_case("bat") || ext.eq_ignore_ascii_case("cmd"))
        .unwrap_or(false)
}
