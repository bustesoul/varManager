pub mod deps_jobs;
pub mod hub;
pub mod job_channel;
pub mod links;
pub mod missing_deps;
pub mod packswitch;
pub mod preview_jobs;
pub mod stale_jobs;
pub mod system_jobs;
pub mod update_db;
pub mod vars_jobs;
pub mod vars_misc;

use self::job_channel::{send_job_failed, send_job_finished, send_job_started, JobReporter};
use crate::app::AppState;
use crate::scenes;
use serde_json::Value;

pub fn spawn_job(state: AppState, id: u64, kind: String, args: Option<Value>) {
    let job_tx = state.job_tx.clone();
    tokio::spawn(async move {
        let semaphore = match state.job_semaphore.read() {
            Ok(guard) => guard.clone(),
            Err(err) => err.into_inner().clone(),
        };
        let permit = semaphore.acquire().await;
        if permit.is_err() {
            send_job_failed(&job_tx, id, "failed to acquire job slot".to_string()).await;
            return;
        }
        let _permit = permit.unwrap();
        send_job_started(&job_tx, id, format!("job started: {}", kind)).await;

        // Create JobReporter for this job
        let reporter = JobReporter::new(id, job_tx.clone());

        if let Err(err) = dispatch(&state, &reporter, &kind, args).await {
            send_job_failed(&job_tx, id, err).await;
            return;
        }
        send_job_finished(&job_tx, id, "job completed".to_string()).await;
    });
}

pub async fn dispatch(
    state: &AppState,
    reporter: &JobReporter,
    kind: &str,
    args: Option<Value>,
) -> Result<(), String> {
    match kind {
        "noop" => {
            let _args = args;
            for step in 0..=5 {
                let progress = (step * 20) as u8;
                reporter.progress(progress);
                reporter.log(format!("noop step {}/5", step));
                tokio::time::sleep(std::time::Duration::from_millis(200)).await;
            }
            Ok(())
        }
        "update_db" => update_db::run_update_db_job(state.clone(), reporter.clone()).await,
        "missing_deps" => {
            missing_deps::run_missing_deps_job(state.clone(), reporter.clone(), args).await
        }
        "rebuild_links" => links::run_rebuild_links_job(state.clone(), reporter.clone(), args).await,
        "links_move" => links::run_move_links_job(state.clone(), reporter.clone(), args).await,
        "links_missing_create" => {
            links::run_missing_links_create_job(state.clone(), reporter.clone(), args).await
        }
        "install_vars" => vars_jobs::run_install_vars_job(state.clone(), reporter.clone(), args).await,
        "preview_uninstall" => {
            vars_jobs::run_preview_uninstall_job(state.clone(), reporter.clone(), args).await
        }
        "uninstall_vars" => {
            vars_jobs::run_uninstall_vars_job(state.clone(), reporter.clone(), args).await
        }
        "delete_vars" => vars_jobs::run_delete_vars_job(state.clone(), reporter.clone(), args).await,
        "vars_export_installed" => {
            vars_misc::run_export_installed_job(state.clone(), reporter.clone(), args).await
        }
        "vars_install_batch" => {
            vars_misc::run_install_batch_job(state.clone(), reporter.clone(), args).await
        }
        "vars_toggle_install" => {
            vars_misc::run_toggle_install_job(state.clone(), reporter.clone(), args).await
        }
        "vars_locate" => vars_misc::run_locate_job(state.clone(), reporter.clone(), args).await,
        "refresh_install_status" => {
            vars_misc::run_refresh_install_status_job(state.clone(), reporter.clone(), args).await
        }
        "saves_deps" => deps_jobs::run_saves_deps_job(state.clone(), reporter.clone(), args).await,
        "log_deps" => deps_jobs::run_log_deps_job(state.clone(), reporter.clone(), args).await,
        "fix_previews" => preview_jobs::run_fix_previews_job(state.clone(), reporter.clone(), args).await,
        "stale_vars" => stale_jobs::run_stale_vars_job(state.clone(), reporter.clone(), args).await,
        "old_version_vars" => {
            stale_jobs::run_old_version_vars_job(state.clone(), reporter.clone(), args).await
        }
        "packswitch_add" => {
            packswitch::run_packswitch_add_job(state.clone(), reporter.clone(), args).await
        }
        "packswitch_delete" => {
            packswitch::run_packswitch_delete_job(state.clone(), reporter.clone(), args).await
        }
        "packswitch_rename" => {
            packswitch::run_packswitch_rename_job(state.clone(), reporter.clone(), args).await
        }
        "packswitch_set" => {
            packswitch::run_packswitch_set_job(state.clone(), reporter.clone(), args).await
        }
        "hub_missing_scan" => hub::run_hub_missing_scan_job(state.clone(), reporter.clone(), args).await,
        "hub_updates_scan" => hub::run_hub_updates_scan_job(state.clone(), reporter.clone(), args).await,
        "hub_download_all" => hub::run_hub_download_all_job(state.clone(), reporter.clone(), args).await,
        "hub_info" => hub::run_hub_info_job(state.clone(), reporter.clone()).await,
        "hub_resources" => hub::run_hub_resources_job(state.clone(), reporter.clone(), args).await,
        "hub_resource_detail" => {
            hub::run_hub_resource_detail_job(state.clone(), reporter.clone(), args).await
        }
        "hub_overview_panel" => {
            hub::run_hub_overview_panel_job(state.clone(), reporter.clone(), args).await
        }
        "hub_find_packages" => {
            hub::run_hub_find_packages_job(state.clone(), reporter.clone(), args).await
        }
        "scene_load" => scenes::run_scene_load_job(state.clone(), reporter.clone(), args).await,
        "scene_analyze" => scenes::run_scene_analyze_job(state.clone(), reporter.clone(), args).await,
        "scene_preset_look" => {
            scenes::run_scene_preset_look_job(state.clone(), reporter.clone(), args).await
        }
        "scene_preset_plugin" => {
            scenes::run_scene_preset_plugin_job(state.clone(), reporter.clone(), args).await
        }
        "scene_preset_pose" => {
            scenes::run_scene_preset_pose_job(state.clone(), reporter.clone(), args).await
        }
        "scene_preset_animation" => {
            scenes::run_scene_preset_animation_job(state.clone(), reporter.clone(), args).await
        }
        "scene_preset_scene" => {
            scenes::run_scene_preset_scene_job(state.clone(), reporter.clone(), args).await
        }
        "scene_add_atoms" => scenes::run_scene_add_atoms_job(state.clone(), reporter.clone(), args).await,
        "scene_add_subscene" => {
            scenes::run_scene_add_subscene_job(state.clone(), reporter.clone(), args).await
        }
        "scene_hide" => scenes::run_scene_hide_job(state.clone(), reporter.clone(), args).await,
        "scene_fav" => scenes::run_scene_fav_job(state.clone(), reporter.clone(), args).await,
        "scene_unhide" => scenes::run_scene_unhide_job(state.clone(), reporter.clone(), args).await,
        "scene_unfav" => scenes::run_scene_unfav_job(state.clone(), reporter.clone(), args).await,
        "cache_clear" => scenes::run_cache_clear_job(state.clone(), reporter.clone(), args).await,
        "vam_start" => system_jobs::run_vam_start_job(state.clone(), reporter.clone(), args).await,
        "rescan_packages" => {
            system_jobs::run_rescan_packages_job(state.clone(), reporter.clone(), args).await
        }
        "open_url" => system_jobs::run_open_url_job(state.clone(), reporter.clone(), args).await,
        _ => Err(format!("job kind not implemented: {}", kind)),
    }
}
