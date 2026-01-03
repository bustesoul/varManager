use crate::db::{
    delete_var_related, list_vars, replace_dependencies, replace_scenes, upsert_var, Db,
    SceneRecord, VarRecord,
};
use crate::{job_log, job_progress, AppState};
use chrono::{DateTime, Local};
use regex::Regex;
use std::collections::HashSet;
use std::fs::{self, File};
use std::io::{BufReader, Read};
use std::path::{Path, PathBuf};
use std::time::SystemTime;
use tokio::runtime::Handle;
use walkdir::WalkDir;
use zip::ZipArchive;

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

pub async fn run_update_db_job(state: AppState, id: u64) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        update_db_blocking(&reporter)
    })
    .await
    .map_err(|err| err.to_string())?
}

struct JobReporter {
    state: AppState,
    id: u64,
    handle: Handle,
}

impl JobReporter {
    fn new(state: AppState, id: u64, handle: Handle) -> Self {
        Self { state, id, handle }
    }

    fn log(&self, msg: impl Into<String>) {
        let msg = msg.into();
        let _ = self.handle.block_on(job_log(&self.state, self.id, msg));
    }

    fn progress(&self, value: u8) {
        let _ = self
            .handle
            .block_on(job_progress(&self.state, self.id, value));
    }
}

fn update_db_blocking(reporter: &JobReporter) -> Result<(), String> {
    let (varspath, vampath) = config_paths(&reporter.state)?;
    reporter.log(format!("UpdateDB start: varspath={}", varspath.display()));
    reporter.progress(1);

    tidy_vars(&varspath, vampath.as_ref(), reporter)?;
    reporter.progress(10);

    let db_path = crate::exe_dir().join("varManager.db");
    let mut db = Db::open(&db_path)?;
    db.ensure_schema()?;
    reporter.log(format!("DB ready: {}", db.path().display()));

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

    let mut exist_vars: HashSet<String> = HashSet::new();
    let tx = db.transaction()?;
    for (idx, var_file) in var_files.iter().enumerate() {
        let basename = match var_file.file_stem() {
            Some(stem) => stem.to_string_lossy().to_string(),
            None => continue,
        };
        exist_vars.insert(basename.clone());

        let result = process_var_file(&dependency_regex, &varspath, var_file);
        match result {
            Ok(processed) => {
                upsert_var(&tx, &processed.var_record)?;
                replace_dependencies(&tx, &processed.var_record.var_name, &processed.dependencies)?;
                replace_scenes(&tx, &processed.var_record.var_name, &processed.scenes)?;
            }
            Err(ProcessError::NotComply(err)) => {
                reporter.log(err);
                move_to_not_comply(&varspath, var_file, reporter)?;
                continue;
            }
            Err(ProcessError::InvalidPackage(err)) => {
                reporter.log(err);
                move_to_not_comply(&varspath, var_file, reporter)?;
                continue;
            }
            Err(ProcessError::Io(err)) => return Err(err),
        }

        let progress = 10 + ((idx + 1) * 80 / var_files.len()) as u8;
        if idx % 200 == 0 || idx + 1 == var_files.len() {
            reporter.progress(progress.min(90));
        }
    }

    cleanup_missing_vars(&tx, &exist_vars, reporter)?;
    tx.commit().map_err(|err| err.to_string())?;

    reporter.progress(100);
    reporter.log("UpdateDB completed".to_string());
    Ok(())
}

fn config_paths(state: &AppState) -> Result<(PathBuf, Option<PathBuf>), String> {
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

fn normalize_path(value: &str) -> Option<PathBuf> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(PathBuf::from(trimmed))
    }
}

fn tidy_vars(varspath: &Path, vampath: Option<&PathBuf>, reporter: &JobReporter) -> Result<(), String> {
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

    if let Some(vampath) = vampath {
        let addon_path = vampath.join("AddonPackages");
        let addon_vars = collect_var_files(
            &addon_path,
            &[INSTALL_LINK_DIR, MISSING_LINK_DIR, TEMP_LINK_DIR],
            true,
        );
        vars.extend(addon_vars);
    } else {
        reporter.log("vampath not set; skip AddonPackages scan".to_string());
    }

    let total = vars.len();
    for (idx, varfile) in vars.into_iter().enumerate() {
        if !varfile.exists() {
            continue;
        }
        if is_symlink(&varfile) {
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
        let dest = unique_path(&creator_path, &filename);
        move_file(&varfile, &dest)?;

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

fn is_symlink(path: &Path) -> bool {
    fs::symlink_metadata(path)
        .map(|meta| meta.file_type().is_symlink())
        .unwrap_or(false)
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

    let file = File::open(var_file).map_err(|err| ProcessError::Io(err.to_string()))?;
    let reader = BufReader::new(file);
    let mut zip = ZipArchive::new(reader).map_err(|err| ProcessError::Io(err.to_string()))?;

    let meta_json = read_meta_json(&mut zip).map_err(|err| ProcessError::InvalidPackage(err))?;
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
        } else {
            if is_plugin_cs(&name_lc) {
                counts.plugin_cs += 1;
            } else if is_plugin_cslist(&name_lc) {
                counts.plugin_cslist += 1;
            }
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
    };

    Ok(ProcessedVar {
        var_record,
        scenes,
        dependencies,
    })
}

fn cleanup_missing_vars(
    tx: &rusqlite::Transaction<'_>,
    exist_vars: &HashSet<String>,
    reporter: &JobReporter,
) -> Result<(), String> {
    let db_vars = list_vars(tx)?;
    let mut removed = 0;
    for var_name in db_vars {
        if !exist_vars.contains(&var_name) {
            delete_var_related(tx, &var_name)?;
            removed += 1;
        }
    }
    if removed > 0 {
        reporter.log(format!("Removed {} missing var records", removed));
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

fn zip_datetime_to_string(dt: zip::DateTime) -> Option<String> {
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
