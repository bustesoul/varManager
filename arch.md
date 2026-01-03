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
- Update DB: TidyVars -> UpdDB -> parse .var zip -> extract meta.json, scenes, previews -> update sqlite.
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
- Config fields: listen_host, listen_port, log_level, job_concurrency.
- Job framework: POST /jobs, GET /jobs/{id}, GET /jobs/{id}/logs (in-memory, capped logs).
- Placeholder job kind: "noop" (others return not implemented).

## UI Button Map

### Main Form (Form1)
| UI | Handler (file) | Current logic (short) | Rust backend plan | Status |
| --- | --- | --- | --- | --- |
| Settings | buttonSetting_Click (varManager/Form1.cs) | Open FormSettings; restart app | Frontend-only; backend reads config.json | TODO |
| UPD_DB | buttonUpdDB_Click | TidyVars -> UpdDB -> install pending -> UpdateVarsInstalled -> RescanPackages | POST /jobs/update-db | TODO |
| Start VAM | buttonStartVam_Click | Start VaM.exe | POST /vam/start (optional) | TODO |
| Missing Depends | buttonMissingDepends_Click | Check installed -> install or open MissingVars form | POST /jobs/missing-deps?scope=installed | TODO |
| All Missing Depends | buttonAllMissingDepends_Click | Check all deps -> open MissingVars form | POST /jobs/missing-deps?scope=all | TODO |
| Filtered Missing Depends | buttonFilteredMissingDepends_Click | Check deps for filtered list | POST /jobs/missing-deps?scope=filtered | TODO |
| Rebuild Symlink | buttonFixRebuildLink_Click | ReparsePoint -> recreate links | POST /links/rebuild | TODO |
| Saves Dependencies | buttonFixSavesDepend_Click | Parse Saves/Custom -> savedepens -> install | POST /jobs/saves-deps | TODO |
| Log Analysis | buttonLogAnalysis_Click | Parse output_log.txt -> install | POST /jobs/log-deps | TODO |
| Stale Vars | buttonStaleVars_Click | Move stale/old versions | POST /jobs/stale-vars | TODO |
| Install Selected | buttonInstall_Click | Install selected + deps | POST /vars/install | TODO |
| Uninstall Selected | buttonUninstallSels_Click | Remove links for selected | POST /vars/uninstall | TODO |
| Delete Selected | buttonDelete_Click | Move to ___DeletedVars___ + cleanup | POST /vars/delete | TODO |
| Move Links | buttonMove_Click | Move link files under ___VarsLink___ | POST /links/move | TODO |
| Export Installed | buttonExpInsted_Click | Write installed list to txt | POST /vars/export-installed | TODO |
| Install From Txt | buttonInstFormTxt_Click | Read list -> VarInstall | POST /vars/install-batch | TODO |
| Add Switch | buttonPacksAdd_Click | Create new switch folder | POST /packswitch/add | TODO |
| Delete Switch | buttonPacksDelete_Click | Delete switch folder | POST /packswitch/delete | TODO |
| Rename Switch | buttonPacksRename_Click | Rename switch folder | POST /packswitch/rename | TODO |
| Load Scene | buttonLoad_Click | Build loadscene.json + temp installs | POST /scene/load | TODO |
| Preview Locate | buttonLocate_Click | Locate var file in Explorer | POST /vars/locate | TODO |
| Preview Install/Remove | buttonpreviewinstall_Click | Install/Uninstall for selected var | POST /vars/toggle-install | TODO |
| Analysis | buttonAnalysis_Click | Analyze scene atoms -> FormAnalysis | POST /scene/analyze | TODO |
| Reset Filter | buttonResetFilter_Click | Reset UI filters | Frontend-only | TODO |
| Fix Preview | buttonFixPreview_Click | Re-extract missing previews | POST /jobs/fix-previews | TODO |
| Hub | buttonHub_Click | Open FormHub | Frontend-only | TODO |
| Prepare Saves | prepareFormSavesToolStripMenuItem_Click | Open PrepareSaves | Frontend-only | TODO |
| Clear Cache | buttonClearCache_Click | Delete current scene cache | POST /cache/clear | TODO |
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
| Fetch Download | toolStripButtonFillDownloadText_Click (varManager/FormMissingVars.cs) | Query hub -> fill download URLs | POST /hub/missing/fetch | TODO |
| Download All | toolStripButtonDownloadAll_Click | Call vam_downloader.exe with URL list | POST /hub/download-all | TODO |
| Link To | buttonLinkto_Click | Assign local link target | Frontend-only | TODO |
| OK | buttonOK_Click | Create missing link symlinks | POST /links/missing/create | TODO |
| Cancel | buttonCancel_Click | Close dialog | Frontend-only | TODO |
| Save Installed | buttonSave_Click | Save installed vars list | POST /vars/export-installed | TODO |
| Save Link Map | buttonSaveTxt_Click | Save missing->target mapping | Frontend-only | TODO |
| Load Link Map | buttonLoadTxt_Click | Load missing->target mapping | Frontend-only | TODO |
| Row Nav | bindingNavigatorMove* | UI navigation | Frontend-only | TODO |

### Scenes (FormScenes)
| UI | Handler (file) | Current logic (short) | Rust backend plan | Status |
| --- | --- | --- | --- | --- |
| Add Hide | buttonAddHide_Click (varManager/FormScenes.cs) | Set .hide file | POST /scenes/hide | TODO |
| Add Fav | buttonAddFav_Click | Set .fav file | POST /scenes/fav | TODO |
| Remove Hide | buttonRemoveHide_Click | Remove .hide file | POST /scenes/unhide | TODO |
| Remove Fav | buttonRemoveFav_Click | Remove .fav file | POST /scenes/unfav | TODO |
| Load Scene | buttonLoadscene_Click | Build loadscene.json | POST /scene/load | TODO |
| Locate | buttonLocate_Click | Locate var or file | POST /vars/locate | TODO |
| Analysis | buttonAnalysis_Click | Analyze scene atoms | POST /scene/analyze | TODO |
| Reset Filter | buttonResetFilter_Click | Reset UI filters | Frontend-only | TODO |
| Clear Cache | buttonClearCache_Click | Delete cache for scene | POST /cache/clear | TODO |
| Filter By Creator | buttonFilterByCreator_Click | UI filter by creator | Frontend-only | TODO |
| Hide/Normal/Fav Layout | buttonHide/Normal/Fav | UI layout width toggles | Frontend-only | TODO |

### Hub (FormHub + HubItem)
| UI | Handler (file) | Current logic (short) | Rust backend plan | Status |
| --- | --- | --- | --- | --- |
| Scan Hub (missing deps) | buttonScanHub_Click (varManager/FormHub.cs) | Find missing deps -> hub download list | POST /hub/missing/scan | TODO |
| Scan Hub Updates | buttonScanHubUpdate_Click | Compare hub vs local -> download list | POST /hub/updates/scan | TODO |
| Refresh | buttonRefresh_Click | Reload list page | POST /hub/resources | TODO |
| Pagination | buttonFirst/Prev/Next/Last | Change page index | Frontend-only (or query backend) | TODO |
| Clear Filters | buttonClearFilters_Click | Reset filters | Frontend-only | TODO |
| Copy Links | buttonCopytoClip_Click | Clipboard URLs | Frontend-only | TODO |
| Download All | buttonDownloadAll_Click | Call downloader with URL list | POST /hub/download-all | TODO |
| Clear Download List | button1_Click | Clear list | Frontend-only | TODO |
| Close/Exit | buttonClose_Click, buttonExit_Click | Close form | Frontend-only | TODO |
| HubItem InRepository | buttonInRepository_Click (varManager/HubItem.cs) | Generate download list / open link / locate | POST /hub/resource-detail or /vars/locate | TODO |
| HubItem Image | pictureBoxImage_Click | Open browser to hub page | Frontend-only | TODO |
| HubItem Filter | buttonType/User, pictureBoxUser_Click | Apply UI filter | Frontend-only | TODO |

### Analysis (FormAnalysis)
| UI | Handler (file) | Current logic (short) | Rust backend plan | Status |
| --- | --- | --- | --- | --- |
| Load Look | buttonLoadLook_Click (varManager/FormAnalysis.cs) | Create look preset -> loadscene | POST /scene/preset/look | TODO |
| Load Scene | buttonLoadScene_Click | Add empty scene + atoms | POST /scene/preset/scene | TODO |
| Load Plugin | buttonLoadPlugin_Click | Create plugin preset | POST /scene/preset/plugin | TODO |
| Load Pose | buttonLoadPose_Click | Create pose preset | POST /scene/preset/pose | TODO |
| Load Animation | buttonLoadAnimation_Click | Create pose+animation preset | POST /scene/preset/animation | TODO |
| Add To Scene | buttonAddToScene_Click | Add atoms to plugin data | POST /scene/add-atoms | TODO |
| Add As Subscene | buttonAddAsSubscene_Click | Add atoms as subscene | POST /scene/add-subscene | TODO |
| Clear Cache | buttonClearCache_Click | (empty handler) | Frontend-only | TODO |

### Prepare Saves (PrepareSaves)
| UI | Handler (file) | Current logic (short) | Rust backend plan | Status |
| --- | --- | --- | --- | --- |
| Analysis | buttonAnalysis_Click (varManager/PrepareSaves.cs) | Parse saves/custom deps | POST /jobs/saves-deps | TODO |
| Output Folder | buttonOutputFolder_Click | Select output dir | Frontend-only | TODO |
| Output | buttonOutput_Click | Validate empty output | Frontend-only | TODO |
| Copy Vars | buttonVarCopyToClip_Click | Copy list to clipboard | Frontend-only | TODO |

### Var Detail (FormVarDetail)
| UI | Handler (file) | Current logic (short) | Rust backend plan | Status |
| --- | --- | --- | --- | --- |
| Locate Var | buttonLocate_Click (varManager/FormVarDetail.cs) | Locate var file | POST /vars/locate | TODO |
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
