use crate::app::AppState;
use crate::infra::paths::{config_paths, resolve_var_file_path, PREVIEW_DIR};
use crate::jobs::job_channel::JobReporter;
use serde::Serialize;
use serde_json::Value;
use sqlx::{Row, SqlitePool};
use std::fs::{self, File};
use std::io::{BufReader, Write};
use std::path::{Path, PathBuf};
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
    reporter: JobReporter,
    _args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || fix_previews_blocking(&state, &reporter))
        .await
        .map_err(|err| err.to_string())?
}

fn fix_previews_blocking(state: &AppState, reporter: &JobReporter) -> Result<(), String> {
    let (varspath, _) = config_paths(state)?;
    reporter.log("FixPreviews start".to_string());
    reporter.progress(1);

    let pool = &state.db_pool;
    let handle = tokio::runtime::Handle::current();
    let scenes = handle.block_on(list_scenes_with_preview(pool))?;
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

async fn list_scenes_with_preview(pool: &SqlitePool) -> Result<Vec<ScenePreview>, String> {
    let rows = sqlx::query(
        "SELECT varName, atomType, previewPic, scenePath FROM scenes WHERE previewPic IS NOT NULL AND previewPic <> ''",
    )
    .fetch_all(pool)
    .await
    .map_err(|err| err.to_string())?;
    let mut scenes = Vec::new();
    for row in rows {
        scenes.push(ScenePreview {
            var_name: row.try_get::<String, _>(0).map_err(|err| err.to_string())?,
            atom_type: row.try_get::<String, _>(1).map_err(|err| err.to_string())?,
            preview_pic: row.try_get::<String, _>(2).map_err(|err| err.to_string())?,
            scene_path: row.try_get::<String, _>(3).map_err(|err| err.to_string())?,
        });
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
