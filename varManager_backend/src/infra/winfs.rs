use std::ffi::OsStr;
use std::os::windows::ffi::OsStrExt;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use windows::core::{Error as WinError, PCWSTR};
use windows::Win32::Foundation::{
    CloseHandle, GetLastError, ERROR_INVALID_PARAMETER, ERROR_PRIVILEGE_NOT_HELD, FILETIME,
    WIN32_ERROR,
};
use windows::Win32::Storage::FileSystem::{
    CreateFileW, CreateSymbolicLinkW, SetFileTime, FILE_ATTRIBUTE_NORMAL, FILE_FLAG_BACKUP_SEMANTICS,
    FILE_FLAG_OPEN_REPARSE_POINT, FILE_SHARE_DELETE, FILE_SHARE_READ, FILE_SHARE_WRITE,
    FILE_WRITE_ATTRIBUTES, OPEN_EXISTING, SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE,
    SYMBOLIC_LINK_FLAG_DIRECTORY, SYMBOLIC_LINK_FLAGS,
};

const WINDOWS_EPOCH_OFFSET_SECS: u64 = 11_644_473_600;

pub fn create_symlink_file(link: &Path, target: &Path) -> Result<(), String> {
    create_symlink(link, target, false)
}

pub fn create_symlink_dir(link: &Path, target: &Path) -> Result<(), String> {
    create_symlink(link, target, true)
}

pub fn read_link_target(path: &Path) -> Result<PathBuf, String> {
    std::fs::read_link(path).map_err(|err| format!("read_link failed: {}", err))
}

pub fn set_symlink_file_times(
    path: &Path,
    created: SystemTime,
    modified: SystemTime,
) -> Result<(), String> {
    let wide = to_wide(path);
    let handle = unsafe {
        CreateFileW(
            PCWSTR(wide.as_ptr()),
            FILE_WRITE_ATTRIBUTES.0,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            None,
            OPEN_EXISTING,
            FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS | FILE_ATTRIBUTE_NORMAL,
            None,
        )
    }
    .map_err(|err| format!("CreateFileW for file time failed ({}).", format_hresult_error(err)))?;

    let creation = system_time_to_filetime(created);
    let last_write = system_time_to_filetime(modified);
    let set_result = unsafe { SetFileTime(handle, Some(&creation), None, Some(&last_write)) };
    let close_result = unsafe { CloseHandle(handle) };

    if let Err(err) = close_result {
        if set_result.is_ok() {
            return Err(format!("CloseHandle failed ({}).", format_hresult_error(err)));
        }
    }
    if let Err(err) = set_result {
        return Err(format!("SetFileTime failed ({}).", format_hresult_error(err)));
    }

    Ok(())
}

fn create_symlink(link: &Path, target: &Path, is_dir: bool) -> Result<(), String> {
    let link_w = to_wide(link);
    let target_w = to_wide(target);
    let flag = if is_dir {
        SYMBOLIC_LINK_FLAG_DIRECTORY
    } else {
        SYMBOLIC_LINK_FLAGS::default()
    };

    let ok = unsafe {
        CreateSymbolicLinkW(
            PCWSTR(link_w.as_ptr()),
            PCWSTR(target_w.as_ptr()),
            flag | SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE,
        )
    };

    if ok {
        return Ok(());
    }

    let err = unsafe { GetLastError() };
    if err == ERROR_INVALID_PARAMETER {
        let retry = unsafe {
            CreateSymbolicLinkW(PCWSTR(link_w.as_ptr()), PCWSTR(target_w.as_ptr()), flag)
        };
        if retry {
            return Ok(());
        }
    }

    let err = unsafe { GetLastError() };
    let hint = if err == ERROR_PRIVILEGE_NOT_HELD {
        "Enable Developer Mode or run as Administrator."
    } else {
        "Check Windows Developer Mode settings or permissions."
    };
    Err(format!(
        "CreateSymbolicLinkW failed ({}). {}",
        format_win32_error(err),
        hint
    ))
}

fn to_wide(path: &Path) -> Vec<u16> {
    OsStr::new(path)
        .encode_wide()
        .chain(std::iter::once(0))
        .collect()
}

fn system_time_to_filetime(time: SystemTime) -> FILETIME {
    let duration = time
        .duration_since(UNIX_EPOCH)
        .unwrap_or_else(|_| Duration::from_secs(0));
    let ticks = (duration.as_secs() + WINDOWS_EPOCH_OFFSET_SECS) * 10_000_000
        + (duration.subsec_nanos() as u64 / 100);
    FILETIME {
        dwLowDateTime: ticks as u32,
        dwHighDateTime: (ticks >> 32) as u32,
    }
}

fn format_hresult_error(err: WinError) -> String {
    let code = err.code().0 as u32;
    let message = err.message();
    format!("code 0x{code:08X}: {message}")
}

fn format_win32_error(err: WIN32_ERROR) -> String {
    let message = std::io::Error::from_raw_os_error(err.0 as i32).to_string();
    format!("code {}: {}", err.0, message)
}
