# varManager Architecture Notes

## Purpose
- Keep behavior parity with the current WinForms app.
- Windows only; no cross-OS support.
- New Rust backend runs as a local HTTP service.
- Frontend remains .NET WinForms, with minimal changes.
- Downloader stays as external .exe, called by backend.

## Key Conventions and Paths
- varspath: user-configured var repository (Settings.Default.varspath).
- vampath: user-configured VaM root (Settings.Default.vampath).
- AddonPackages switch root: `${vampath}\\___AddonPacksSwitch ___`.
- Active AddonPackages path: `${vampath}\\AddonPackages` (symlink).
- Link folders:
  - `${vampath}\\AddonPackages\\___VarsLink___`
  - `${vampath}\\AddonPackages\\___MissingVarLink___`
  - `${vampath}\\AddonPackages\\___TempVarLink___`
- Preview images: `${varspath}\\___PreviewPics___\\<type>\\<varName>\\*.jpg`
- Cache: `./Cache/<varName>/<entryName>/`
- DB: `varManager.db` next to the exe (current behavior).
- Logs: `varManager.log` in exe working directory (SimpleLogger).
- Downloader: `.\plugin\vam_downloader.exe`

## Database Schema (SQLite)
- dependencies(varName, dependency)
- installStatus(varName, installed, disabled)
- vars(varName, creatorName, packageName, metaDate, varDate, version, description, morph, cloth, hair, skin, pose, scene, script, plugin, asset, texture, look, subScene, appearance, dependencyCnt)
- scenes(varName, atomType, previewPic, scenePath, isPreset, isLoadable)
- savedepens(varName, dependency, SavePath, ModiDate)
- HideFav(varName, hide, fav)

## Core Flows (Current)
- Update DB: TidyVars -> UpdDB（解析 .var zip，提取 meta.json/场景/预览并更新 sqlite）-> install pending -> UpdateVarsInstalled -> RescanPackages.
- Install: VarInstall -> create symlink in ___VarsLink___ or ___TempVarLink___ -> set link times.
- Missing deps: query dependencies -> resolve versions -> install or show missing list.
- Save/Log analysis: parse JSON/log -> extract dependency list -> install or show missing list.
- Rescan VaM: write `Custom\\PluginData\\feelfar\\loadscene.json` with `rescan:true`.
- Hub: query hub API -> build download list -> call downloader exe.

## Rust Backend Summary (Target)
- Local HTTP service on 127.0.0.1 with config.json (default if missing).
- Endpoints for long jobs (start + polling progress + logs).
- Windows-native file ops and symlink creation (CreateSymbolicLinkW with ALLOW_UNPRIVILEGED_CREATE).
- Keep sqlite schema unchanged; file stays next to exe.
- Expose minimal API for WinForms to call; UI keeps filters and layout logic.

## Backend Scaffold (Current)
- Implemented endpoints: GET /health, GET /config, POST /shutdown.
- Config file: config.json next to backend exe, auto-created if missing.
- Config fields: listen_host, listen_port, log_level, job_concurrency, varspath, vampath, vam_exec, downloader_path, downloader_save_path.
- Job framework: POST /jobs, GET /jobs/{id}, GET /jobs/{id}/logs, GET /jobs/{id}/result (in-memory, capped logs).
- Job kinds: "noop", "update_db", "missing_deps", "rebuild_links", "install_vars"/"uninstall_vars"/"delete_vars", "saves_deps"/"log_deps", "fix_previews", "stale_vars"/"old_version_vars", "links_move"/"links_missing_create", "vars_export_installed"/"vars_install_batch"/"vars_toggle_install"/"vars_locate"/"refresh_install_status", "packswitch_add"/"packswitch_delete"/"packswitch_rename"/"packswitch_set", "scene_load"/"scene_analyze"/"scene_preset_*"/"scene_add_*"/"scene_hide/fav/unhide/unfav"/"cache_clear", "hub_*" (info/resources/resource_detail/find_packages/missing_scan/updates_scan/download_all), "vam_start"/"rescan_packages"/"open_url".
- Windows native file ops module implemented (symlink create/read, set file time).
- SQLite access layer implemented (schema ensure + CRUD helpers).
- update_db uses config varspath/vampath, tidies var files, parses zip/meta.json, updates dependencies/scenes/vars.

## Implementation Progress
- Done: backend service scaffold, config file generation, job framework, "update_db" job core flow.
- Done: job result endpoint + missing_deps job (scope installed/all/filtered) with auto-install for installed scope.
- Done: rebuild_links job（重建 ___VarsLink___/AddonPackages 顶层/___MissingVarLink___ 的符号链接）。
- Done: 安装/卸载/删除作业（install_vars/uninstall_vars/delete_vars），依赖展开与影响链逻辑按 C# 实现复刻。
- Done: 保存/日志依赖分析作业（saves_deps/log_deps），含依赖解析与自动安装。
- Done: Fix Preview 作业（fix_previews），缺失预览图从 .var 内重新提取。
- Done: Hub 作业（info/resources/resource_detail/find_packages/missing_scan/updates_scan/download_all）与下载器调用。
- Done: 场景/分析作业（scene_load/scene_analyze/scene_preset_* /scene_add_*），缓存生成与 loadscene.json 生成。
- Done: Hide/Fav/Cache 作业（scene_hide/fav/unhide/unfav, cache_clear）。
- Done: Stale/OldVersion 作业（stale_vars/old_version_vars）。
- Done: Vars 杂项作业（links_move/links_missing_create, vars_export_installed/vars_install_batch/vars_toggle_install/vars_locate, refresh_install_status）。
- Done: PackSwitch 作业（packswitch_add/delete/rename/set）。
- Done: 系统作业（vam_start/rescan_packages/open_url）。
- Done: Windows native symlink module (create/read/set file times).
- Done: SQLite schema ensure + helpers for vars/dependencies/scenes.
- Done: update_db 对齐 C# 流程（varsForInstall 记录 + 重复包移入 ___VarRedundant___ + UpdateVarsInstalled/RescanPackages + 缺失预览清理）。
- Pending: WinForms lifecycle integration (start/health/shutdown) and API call replacements.
- Note: missing_deps install resolves var file path as `${varspath}\\___VarTidied___\\<creator>\\<varName>.var` with fallback to `${varspath}\\<varName>.var` because the current schema has no VarPath column.

## UI Button Map

### Main Form (Form1)
| UI | Handler (file) | Current logic (short) | Rust backend plan | Status |
| --- | --- | --- | --- | --- |
| Settings | buttonSetting_Click (varManager/Form1.cs) | Open FormSettings; restart app | Frontend-only; backend reads config.json | TODO |
| UPD_DB | buttonUpdDB_Click | TidyVars -> UpdDB -> install pending -> UpdateVarsInstalled -> RescanPackages | POST /jobs (kind=update_db) | Backend done |
| Start VAM | buttonStartVam_Click | Start VaM.exe | POST /jobs (kind=vam_start) | Backend done |
| Missing Depends | buttonMissingDepends_Click | Check installed -> install or open MissingVars form | POST /jobs (kind=missing_deps, args.scope=installed) | Backend done |
| All Missing Depends | buttonAllMissingDepends_Click | Check all deps -> open MissingVars form | POST /jobs (kind=missing_deps, args.scope=all) | Backend done |
| Filtered Missing Depends | buttonFilteredMissingDepends_Click | Check deps for filtered list | POST /jobs (kind=missing_deps, args.scope=filtered, args.var_names=filtered list) | Backend done |
| Rebuild Symlink | buttonFixRebuildLink_Click | ReparsePoint -> recreate links | POST /jobs (kind=rebuild_links, args.include_missing=true) | Backend done |
| Saves Dependencies | buttonFixSavesDepend_Click | Parse Saves/Custom -> savedepens -> install | POST /jobs (kind=saves_deps) | Backend done |
| Log Analysis | buttonLogAnalysis_Click | Parse output_log.txt -> install | POST /jobs (kind=log_deps) | Backend done |
| Stale Vars | buttonStaleVars_Click | Move stale/old versions | POST /jobs (kind=stale_vars / old_version_vars) | Backend done |
| Install Selected | buttonInstall_Click | Install selected + deps | POST /jobs (kind=install_vars, args.include_dependencies=true) | Backend done |
| Uninstall Selected | buttonUninstallSels_Click | Remove links for selected | POST /jobs (kind=uninstall_vars, args.include_implicated=true) | Backend done |
| Delete Selected | buttonDelete_Click | Move to ___DeletedVars___ + cleanup | POST /jobs (kind=delete_vars, args.include_implicated=true) | Backend done |
| Move Links | buttonMove_Click | Move link files under ___VarsLink___ | POST /jobs (kind=links_move) | Backend done |
| Export Installed | buttonExpInsted_Click | Write installed list to txt | POST /jobs (kind=vars_export_installed) | Backend done |
| Install From Txt | buttonInstFormTxt_Click | Read list -> VarInstall | POST /jobs (kind=vars_install_batch) | Backend done |
| Add Switch | buttonPacksAdd_Click | Create new switch folder | POST /jobs (kind=packswitch_add) | Backend done |
| Delete Switch | buttonPacksDelete_Click | Delete switch folder | POST /jobs (kind=packswitch_delete) | Backend done |
| Rename Switch | buttonPacksRename_Click | Rename switch folder | POST /jobs (kind=packswitch_rename) | Backend done |
| Load Scene | buttonLoad_Click | Build loadscene.json + temp installs | POST /jobs (kind=scene_load) | Backend done |
| Preview Locate | buttonLocate_Click | Locate var file in Explorer | POST /jobs (kind=vars_locate) | Backend done |
| Preview Install/Remove | buttonpreviewinstall_Click | Install/Uninstall for selected var | POST /jobs (kind=vars_toggle_install) | Backend done |
| Analysis | buttonAnalysis_Click | Analyze scene atoms -> FormAnalysis | POST /jobs (kind=scene_analyze) | Backend done |
| Reset Filter | buttonResetFilter_Click | Reset UI filters | Frontend-only | TODO |
| Fix Preview | buttonFixPreview_Click | Re-extract missing previews | POST /jobs (kind=fix_previews) | Backend done |
| Hub | buttonHub_Click | Open FormHub | Frontend-only | TODO |
| Prepare Saves | prepareFormSavesToolStripMenuItem_Click | Open PrepareSaves | Frontend-only | TODO |
| Clear Cache | buttonClearCache_Click | Delete current scene cache | POST /jobs (kind=cache_clear) | Backend done |
| Preview Nav | toolStripButtonPreviewFirst/Prev/Next/Last | UI list navigation | Frontend-only | TODO |

### Settings (FormSettings)
| UI | Handler (file) | Current logic (short) | Rust backend plan | Status |
| --- | --- | --- | --- | --- |
| Vars Path | buttonVarspath_Click (varManager/FormSettings.cs) | Browse folder | Frontend-only | TODO |
| VaM Path | buttonVamPath_Click | Browse folder | Frontend-only | TODO |
| Exec Path | buttonExec_Click | Select VaM exe | Frontend-only | TODO |
| Save | buttonSave_Click | Persist Settings.Default | Frontend-only; backend uses config.json | TODO |

### Missing Vars (FormMissingVars)
| UI | Handler (file) | Current logic (short) | Rust backend plan | Status |
| --- | --- | --- | --- | --- |
| Fetch Download | toolStripButtonFillDownloadText_Click (varManager/FormMissingVars.cs) | Query hub -> fill download URLs | POST /jobs (kind=hub_find_packages) | Backend done |
| Download All | toolStripButtonDownloadAll_Click | Call vam_downloader.exe with URL list | POST /jobs (kind=hub_download_all) | Backend done |
| Link To | buttonLinkto_Click | Assign local link target | Frontend-only | TODO |
| OK | buttonOK_Click | Create missing link symlinks | POST /jobs (kind=links_missing_create) | Backend done |
| Cancel | buttonCancel_Click | Close dialog | Frontend-only | TODO |
| Save Installed | buttonSave_Click | Save installed vars list | POST /jobs (kind=vars_export_installed) | Backend done |
| Save Link Map | buttonSaveTxt_Click | Save missing->target mapping | Frontend-only | TODO |
| Load Link Map | buttonLoadTxt_Click | Load missing->target mapping | Frontend-only | TODO |
| Row Nav | bindingNavigatorMove* | UI navigation | Frontend-only | TODO |

### Scenes (FormScenes)
| UI | Handler (file) | Current logic (short) | Rust backend plan | Status |
| --- | --- | --- | --- | --- |
| Add Hide | buttonAddHide_Click (varManager/FormScenes.cs) | Set .hide file | POST /jobs (kind=scene_hide) | Backend done |
| Add Fav | buttonAddFav_Click | Set .fav file | POST /jobs (kind=scene_fav) | Backend done |
| Remove Hide | buttonRemoveHide_Click | Remove .hide file | POST /jobs (kind=scene_unhide) | Backend done |
| Remove Fav | buttonRemoveFav_Click | Remove .fav file | POST /jobs (kind=scene_unfav) | Backend done |
| Load Scene | buttonLoadscene_Click | Build loadscene.json | POST /jobs (kind=scene_load) | Backend done |
| Locate | buttonLocate_Click | Locate var or file | POST /jobs (kind=vars_locate) | Backend done |
| Analysis | buttonAnalysis_Click | Analyze scene atoms | POST /jobs (kind=scene_analyze) | Backend done |
| Reset Filter | buttonResetFilter_Click | Reset UI filters | Frontend-only | TODO |
| Clear Cache | buttonClearCache_Click | Delete cache for scene | POST /jobs (kind=cache_clear) | Backend done |
| Filter By Creator | buttonFilterByCreator_Click | UI filter by creator | Frontend-only | TODO |
| Hide/Normal/Fav Layout | buttonHide/Normal/Fav | UI layout width toggles | Frontend-only | TODO |

### Hub (FormHub + HubItem)
| UI | Handler (file) | Current logic (short) | Rust backend plan | Status |
| --- | --- | --- | --- | --- |
| Scan Hub (missing deps) | buttonScanHub_Click (varManager/FormHub.cs) | Find missing deps -> hub download list | POST /jobs (kind=hub_missing_scan) | Backend done |
| Scan Hub Updates | buttonScanHubUpdate_Click | Compare hub vs local -> download list | POST /jobs (kind=hub_updates_scan) | Backend done |
| Refresh | buttonRefresh_Click | Reload list page | POST /jobs (kind=hub_resources) | Backend done |
| Pagination | buttonFirst/Prev/Next/Last | Change page index | Frontend-only (or query backend) | TODO |
| Clear Filters | buttonClearFilters_Click | Reset filters | Frontend-only | TODO |
| Copy Links | buttonCopytoClip_Click | Clipboard URLs | Frontend-only | TODO |
| Download All | buttonDownloadAll_Click | Call downloader with URL list | POST /jobs (kind=hub_download_all) | Backend done |
| Clear Download List | button1_Click | Clear list | Frontend-only | TODO |
| Close/Exit | buttonClose_Click, buttonExit_Click | Close form | Frontend-only | TODO |
| HubItem InRepository | buttonInRepository_Click (varManager/HubItem.cs) | Generate download list / open link / locate | POST /jobs (kind=hub_resource_detail / vars_locate / open_url) | Backend done |
| HubItem Image | pictureBoxImage_Click | Open browser to hub page | POST /jobs (kind=open_url) | Backend done |
| HubItem Filter | buttonType/User, pictureBoxUser_Click | Apply UI filter | Frontend-only | TODO |

### Analysis (FormAnalysis)
| UI | Handler (file) | Current logic (short) | Rust backend plan | Status |
| --- | --- | --- | --- | --- |
| Load Look | buttonLoadLook_Click (varManager/FormAnalysis.cs) | Create look preset -> loadscene | POST /jobs (kind=scene_preset_look) | Backend done |
| Load Scene | buttonLoadScene_Click | Add empty scene + atoms | POST /jobs (kind=scene_preset_scene) | Backend done |
| Load Plugin | buttonLoadPlugin_Click | Create plugin preset | POST /jobs (kind=scene_preset_plugin) | Backend done |
| Load Pose | buttonLoadPose_Click | Create pose preset | POST /jobs (kind=scene_preset_pose) | Backend done |
| Load Animation | buttonLoadAnimation_Click | Create pose+animation preset | POST /jobs (kind=scene_preset_animation) | Backend done |
| Add To Scene | buttonAddToScene_Click | Add atoms to plugin data | POST /jobs (kind=scene_add_atoms) | Backend done |
| Add As Subscene | buttonAddAsSubscene_Click | Add atoms as subscene | POST /jobs (kind=scene_add_subscene) | Backend done |
| Clear Cache | buttonClearCache_Click | (empty handler) | Frontend-only | TODO |

### Prepare Saves (PrepareSaves)
| UI | Handler (file) | Current logic (short) | Rust backend plan | Status |
| --- | --- | --- | --- | --- |
| Analysis | buttonAnalysis_Click (varManager/PrepareSaves.cs) | Parse saves/custom deps | POST /jobs (kind=saves_deps) | Backend done |
| Output Folder | buttonOutputFolder_Click | Select output dir | Frontend-only | TODO |
| Output | buttonOutput_Click | Validate empty output | Frontend-only | TODO |
| Copy Vars | buttonVarCopyToClip_Click | Copy list to clipboard | Frontend-only | TODO |

### Var Detail (FormVarDetail)
| UI | Handler (file) | Current logic (short) | Rust backend plan | Status |
| --- | --- | --- | --- | --- |
| Locate Var | buttonLocate_Click (varManager/FormVarDetail.cs) | Locate var file | POST /jobs (kind=vars_locate) | Backend done |
| Filter Creator | buttonFilter_Click | Set creator filter | Frontend-only | TODO |

### Uninstall Vars (FormUninstallVars)
| UI | Handler (file) | Current logic (short) | Rust backend plan | Status |
| --- | --- | --- | --- | --- |
| Preview Nav | toolStripButtonPreviewFirst/Prev/Next/Last | UI list navigation | Frontend-only | TODO |
| Preview Click | listViewPreviewPics_Click / pictureBoxPreview_Click / buttonpreviewback_Click | UI preview | Frontend-only | TODO |

### Switch Dialogs
| UI | Handler (file) | Current logic (short) | Rust backend plan | Status |
| --- | --- | --- | --- | --- |
| Switch Add OK | FormSwitchAdd.buttonOK_Click | Validate new switch | Frontend-only (or backend validate) | TODO |
| Switch Rename OK | FormSwitchRename.buttonOK_Click | Validate rename | Frontend-only (or backend validate) | TODO |
| Vars Move OK | FormVarsMove.buttonOK_Click | Validate destination | Frontend-only | TODO |

## Windows Native API Notes (Current -> Rust)
- CreateSymbolicLink: used for file and dir links (Comm.CreateSymbolicLink).
- ReparsePoint: used to resolve target path for symlinks.
- SetSymboLinkFileTime: used to sync creation/write time on links.
- Rust should use CreateSymbolicLinkW with ALLOW_UNPRIVILEGED_CREATE and return clear error if it fails.

## Backend Service Lifecycle (Planned)
- Frontend starts backend exe.
- Poll /health until ready.
- Call APIs; for long jobs use /jobs/start + /jobs/{id}.
- On close: POST /shutdown, wait 2s, then kill if still running.
