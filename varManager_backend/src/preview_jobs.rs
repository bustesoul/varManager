use crate::db::Db;
use crate::paths::{config_paths, resolve_var_file_path, PREVIEW_DIR};
use crate::{job_log, job_progress, job_set_result, AppState};
use serde::Serialize;
use serde_json::Value;
use std::fs::{self, File};
use std::io::{BufReader, Write};
use std::path::{Path, PathBuf};
use tokio::runtime::Handle;
use zip::ZipArchive;

#[derive(Serialize)]
struct FixPreviewResult {
    total: usize,
    fixed: usize,
    skipped: usize,
    failed: usize,
}

pub async fn run_fix_previews_job(
    state: AppState,
    id: u64,
    _args: Option<Value>,
) -> Result<(), String> {
    let handle = Handle::current();
    tokio::task::spawn_blocking(move || {
        let reporter = JobReporter::new(state, id, handle);
        fix_previews_blocking(&reporter)
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

    fn set_result(&self, result: Value) {
        let _ = self
            .handle
            .block_on(job_set_result(&self.state, self.id, result));
    }
}

fn fix_previews_blocking(reporter: &JobReporter) -> Result<(), String> {
    let (varspath, _) = config_paths(&reporter.state)?;
    reporter.log("FixPreviews start".to_string());
    reporter.progress(1);

    let db_path = crate::exe_dir().join("varManager.db");
    let db = Db::open(&db_path)?;
    db.ensure_schema()?;

    let scenes = list_scenes_with_preview(db.connection())?;
    let total = scenes.len();
    let mut fixed = 0;
    let mut skipped = 0;
    let mut failed = 0;

    for (idx, scene) in scenes.iter().enumerate() {
        let preview_path = preview_file_path(&varspath, scene);
        if preview_path.exists() {
            skipped += 1;
        } else {
            match reextract_preview(&varspath, scene, &preview_path) {
                Ok(true) => {
                    fixed += 1;
                    reporter.log(format!("fixed {}", preview_path.display()));
                }
                Ok(false) => {
                    failed += 1;
                    reporter.log(format!("missing {}", preview_path.display()));
                }
                Err(err) => {
                    failed += 1;
                    reporter.log(format!("fix failed {} ({})", preview_path.display(), err));
                }
            }
        }

        if total > 0 && (idx % 200 == 0 || idx + 1 == total) {
            let progress = 5 + ((idx + 1) * 90 / total) as u8;
            reporter.progress(progress.min(95));
        }
    }

    reporter.set_result(
        serde_json::to_value(FixPreviewResult {
            total,
            fixed,
            skipped,
            failed,
        })
        .map_err(|err| err.to_string())?,
    );

    reporter.progress(100);
    reporter.log("FixPreviews completed".to_string());
    Ok(())
}

struct ScenePreview {
    var_name: String,
    atom_type: String,
    preview_pic: String,
    scene_path: String,
}

fn list_scenes_with_preview(conn: &rusqlite::Connection) -> Result<Vec<ScenePreview>, String> {
    let mut stmt = conn
        .prepare(
            "SELECT varName, atomType, previewPic, scenePath FROM scenes WHERE previewPic IS NOT NULL AND previewPic <> ''",
        )
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map([], |row| {
            Ok(ScenePreview {
                var_name: row.get::<_, String>(0)?,
                atom_type: row.get::<_, String>(1)?,
                preview_pic: row.get::<_, String>(2)?,
                scene_path: row.get::<_, String>(3)?,
            })
        })
        .map_err(|err| err.to_string())?;
    let mut scenes = Vec::new();
    for row in rows {
        scenes.push(row.map_err(|err| err.to_string())?);
    }
    Ok(scenes)
}

fn preview_file_path(varspath: &Path, scene: &ScenePreview) -> PathBuf {
    varspath
        .join(PREVIEW_DIR)
        .join(&scene.atom_type)
        .join(&scene.var_name)
        .join(&scene.preview_pic)
}

fn reextract_preview(
    varspath: &Path,
    scene: &ScenePreview,
    preview_path: &Path,
) -> Result<bool, String> {
    let var_file = resolve_var_file_path(varspath, &scene.var_name)?;
    let file = File::open(&var_file).map_err(|err| err.to_string())?;
    let reader = BufReader::new(file);
    let mut zip = ZipArchive::new(reader).map_err(|err| err.to_string())?;

    let dot = scene
        .scene_path
        .rfind('.')
        .ok_or_else(|| "scene path missing extension".to_string())?;
    let jpg_entry = format!("{}{}", &scene.scene_path[..dot], ".jpg");
    let mut jpg = match zip.by_name(&jpg_entry) {
        Ok(entry) => entry,
        Err(_) => return Ok(false),
    };

    if let Some(parent) = preview_path.parent() {
        fs::create_dir_all(parent).map_err(|err| err.to_string())?;
    }
    let mut out = File::create(preview_path).map_err(|err| err.to_string())?;
    std::io::copy(&mut jpg, &mut out).map_err(|err| err.to_string())?;
    out.flush().map_err(|err| err.to_string())?;
    Ok(true)
}
