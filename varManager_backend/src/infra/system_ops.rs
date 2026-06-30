use crate::app::AppState;
use crate::infra::paths::loadscene_path;
use serde_json::json;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use sysinfo::{ProcessesToUpdate, System};

#[cfg(windows)]
use std::os::windows::process::CommandExt;

#[cfg(windows)]
const CREATE_NEW_PROCESS_GROUP: u32 = 0x00000200;
#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x08000000;

const DEFAULT_VAM_EXEC: &str = "VaM (Desktop Mode).bat";

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

    spawn_detached(&exec_path, &vampath)?;
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

/// Spawn a process fully detached from the parent.
/// This prevents the child from blocking on inherited stdin/stdout/stderr handles.
#[cfg(windows)]
fn spawn_detached(exec_path: &Path, working_dir: &Path) -> Result<(), String> {
    if is_cmd_script(exec_path) {
        // For bat/cmd files: use "start" to launch in a new console window.
        // Use /B and CREATE_NO_WINDOW to keep it hidden while preserving START behavior.
        let exec = exec_path.to_string_lossy();
        let workdir = working_dir.to_string_lossy();
        Command::new("cmd")
            .args(["/C", "start", "", "/B", "/D", &workdir, &*exec])
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .creation_flags(CREATE_NO_WINDOW | CREATE_NEW_PROCESS_GROUP)
            .spawn()
            .map_err(|err| err.to_string())?;
    } else {
        // For exe files: launch directly with detached flags
        Command::new(exec_path)
            .current_dir(working_dir)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .creation_flags(CREATE_NO_WINDOW | CREATE_NEW_PROCESS_GROUP)
            .spawn()
            .map_err(|err| err.to_string())?;
    }

    Ok(())
}

#[cfg(not(windows))]
fn spawn_detached(exec_path: &Path, working_dir: &Path) -> Result<(), String> {
    Command::new(exec_path)
        .current_dir(working_dir)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|err| err.to_string())?;

    Ok(())
}
