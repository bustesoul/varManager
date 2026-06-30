use std::path::Path;
use std::process::Command;

pub fn valid_file_name(name: &str) -> String {
    name.chars()
        .filter(|c| is_valid_filename_char(*c))
        .collect()
}

fn is_valid_filename_char(c: char) -> bool {
    let invalid = ['<', '>', ':', '"', '/', '\\', '|', '?', '*'];
    if c.is_control() {
        return false;
    }
    !invalid.contains(&c)
}

pub fn normalize_entry_name(name: &str) -> String {
    name.replace(['\\', '/'], "_")
}

pub fn open_explorer_select(path: &Path) -> Result<(), String> {
    if !path.exists() {
        return Err(format!("path not found: {}", path.display()));
    }
    let arg = format!("/select,{}", path.display());
    Command::new("explorer.exe")
        .arg(arg)
        .spawn()
        .map_err(|err| err.to_string())?;
    Ok(())
}

pub fn open_url(url: &str) -> Result<(), String> {
    Command::new("cmd")
        .args(["/C", "start", "", url])
        .spawn()
        .map_err(|err| err.to_string())?;
    Ok(())
}
