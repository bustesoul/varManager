use crate::app::AppState;
use crate::jobs::job_channel::JobReporter;
use serde_json::Value;

use super::core;

pub async fn run_scene_load_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "scene_load args required".to_string())?;
        let args: core::SceneLoadArgs =
            serde_json::from_value(args).map_err(|err| err.to_string())?;
        core::scene_load_blocking(&state, &reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_scene_analyze_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "scene_analyze args required".to_string())?;
        let args: core::SceneAnalyzeArgs =
            serde_json::from_value(args).map_err(|err| err.to_string())?;
        core::scene_analyze_blocking(&state, &reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_scene_preset_look_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "scene_preset_look args required".to_string())?;
        let args: core::ScenePresetLookArgs =
            serde_json::from_value(args).map_err(|err| err.to_string())?;
        core::scene_preset_look_blocking(&state, &reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_scene_preset_plugin_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    run_scene_preset_job(state, reporter, args, core::PresetKind::Plugin).await
}

pub async fn run_scene_preset_pose_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    run_scene_preset_job(state, reporter, args, core::PresetKind::Pose).await
}

pub async fn run_scene_preset_animation_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    run_scene_preset_job(state, reporter, args, core::PresetKind::Animation).await
}

pub async fn run_scene_preset_scene_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "scene_preset_scene args required".to_string())?;
        let args: core::ScenePresetSceneArgs =
            serde_json::from_value(args).map_err(|err| err.to_string())?;
        core::scene_preset_scene_blocking(&state, &reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

pub async fn run_scene_add_atoms_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    run_scene_atoms_job(state, reporter, args, false).await
}

pub async fn run_scene_add_subscene_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    run_scene_atoms_job(state, reporter, args, true).await
}

pub async fn run_scene_hide_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    run_scene_hide_fav_job(state, reporter, args, -1).await
}

pub async fn run_scene_fav_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    run_scene_hide_fav_job(state, reporter, args, 1).await
}

pub async fn run_scene_unhide_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    run_scene_hide_fav_job(state, reporter, args, 0).await
}

pub async fn run_scene_unfav_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    run_scene_hide_fav_job(state, reporter, args, 0).await
}

pub async fn run_cache_clear_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "cache_clear args required".to_string())?;
        let args: core::CacheClearArgs =
            serde_json::from_value(args).map_err(|err| err.to_string())?;
        core::cache_clear_blocking(&state, &reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

async fn run_scene_preset_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
    kind: core::PresetKind,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "scene_preset args required".to_string())?;
        let args: core::ScenePresetArgs =
            serde_json::from_value(args).map_err(|err| err.to_string())?;
        core::scene_preset_blocking(&state, &reporter, args, kind)
    })
    .await
    .map_err(|err| err.to_string())?
}

async fn run_scene_atoms_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
    as_subscene: bool,
) -> Result<(), String> {
    tokio::task::spawn_blocking(move || {
        let args = args.ok_or_else(|| "scene_add_atoms args required".to_string())?;
        let mut args: core::SceneAtomsArgs =
            serde_json::from_value(args).map_err(|err| err.to_string())?;
        args.as_subscene = as_subscene || args.as_subscene;
        core::scene_add_atoms_blocking(&state, &reporter, args)
    })
    .await
    .map_err(|err| err.to_string())?
}

async fn run_scene_hide_fav_job(
    state: AppState,
    reporter: JobReporter,
    args: Option<Value>,
    hide_fav: i32,
) -> Result<(), String> {
    let args = args.ok_or_else(|| "scene_hide_fav args required".to_string())?;
    let args: core::SceneHideFavArgs =
        serde_json::from_value(args).map_err(|err| err.to_string())?;
    let state_for_blocking = state.clone();
    let var_name = args.var_name.clone();
    let scene_path = args.scene_path.clone();
    let status = tokio::task::spawn_blocking(move || {
        core::set_hide_fav(
            &state_for_blocking,
            var_name.as_deref(),
            &scene_path,
            hide_fav,
        )
    })
    .await
    .map_err(|err| err.to_string())??;
    core::sync_hide_fav_db(&state, args.var_name.as_deref(), &args.scene_path, status).await?;
    reporter.log("scene hide/fav updated");
    Ok(())
}
