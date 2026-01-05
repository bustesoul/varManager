# varManager Flutter Architecture Notes

## Purpose
- Replace WinForms UI with Flutter (Windows, Material3).
- Keep behavior parity with active WinForms flows; skip known deadcode.
- Frontend consumes backend as the single source of data.
- Flutter manages backend lifecycle (start/health/shutdown).
- Distribution: unzip bundle with Flutter exe + backend exe + downloader in the same folder.

## Non-Goals
- Cross-platform support.
- Backend schema redesign (SQLite schema stays unchanged).
- Multi-instance support.

## Runtime Overview
```
Flutter App
  ├─ BackendProcessManager (spawn/health/shutdown)
  └─ BackendClient (HTTP)
        └─ Rust Backend (jobs + queries)
              └─ Filesystem + downloader exe
```
- No direct SQLite or filesystem reads from Flutter UI.
- All data and file access go through backend APIs.

## Configuration
- Config is loaded from backend `config.json` via API.
- UI can edit config through backend API (validate and persist).
- Base URL defaults to backend `listen_host` + `listen_port`.

## Backend Lifecycle (Flutter Responsibility)
- On app start:
  - Spawn backend exe if not running.
  - Poll `GET /health` until ready or timeout.
- During runtime:
  - All operations use HTTP APIs.
- On app exit:
  - Call `POST /shutdown`, wait briefly, then kill if still alive.

## Module Structure (Flutter)
```
lib/
  app/                // app entry, theme, routing
  core/
    backend/          // BackendClient, BackendProcessManager, JobRunner
    models/           // DTOs and UI models
    utils/            // shared helpers (format, debounce, etc.)
  features/
    home/             // main vars list + filters
    settings/
    missing_vars/
    scenes/
    hub/
    analysis/
    prepare_saves/
    var_detail/
    uninstall_vars/
    packswitch/
  widgets/            // shared UI components
  main.dart
```

## State Management (Keep It Simple)
- Use `flutter_riverpod` for feature-level state and DI.
- Use `StateNotifier` + `AsyncValue` for async list/job state.
- Use `ValueNotifier` for local widget state (selection, view mode).

## UI Pages and Mapping
| Flutter Feature/Page | WinForms Source | Notes | Status |
| --- | --- | --- | --- |
| Home (Vars List) | Form1 | Main list, filters, toolbar actions | PARTIAL |
| Settings Dialog | FormSettings | Read + edit config | DONE |
| Missing Vars Dialog | FormMissingVars | Link map + hub actions | DONE |
| Scenes Page | FormScenes | Scene list + actions | DONE |
| Hub Page | FormHub + HubItem | Browse + download | DONE |
| Analysis Dialog | FormAnalysis | Preset/scene analysis | DONE |
| Prepare Saves Dialog | PrepareSaves | Output validation + copy list | DONE |
| Var Detail Dialog | FormVarDetail | Detail + locate + filter | DONE |
| Uninstall Vars Dialog | FormUninstallVars | Preview navigation | DONE |
| PackSwitch Dialogs | FormSwitchAdd/Rename + VarsMove | Add/rename/move | DONE |

## Deadcode Skip Rule
- Port only features reachable by active UI handlers.
- Exclude unused handlers, hidden debug features, or unreachable menus.
- Mark any ambiguous feature as "SkipCandidate" in the tracking table.

## Job Flow (Standard Pattern)
1. `POST /jobs` with `{ kind, args }`
2. Poll `GET /jobs/{id}` for status/progress
3. Optional `GET /jobs/{id}/logs` for log streaming
4. Fetch `GET /jobs/{id}/result` on success

## Backend API Contract (Flutter Usage)
### Existing (Backend Done / Used by Flutter)
- `GET /health`
- `GET /config`
- `PUT /config`
- `POST /shutdown`
- `POST /jobs`
- `GET /jobs/{id}`
- `GET /jobs/{id}/logs`
- `GET /jobs/{id}/result`
- `GET /vars`
- `GET /vars/{varName}`
- `POST /vars/resolve`
- `POST /vars/dependencies`
- `POST /vars/previews`
- `GET /scenes`
- `GET /creators`
- `GET /stats`
- `GET /packswitch`
- `GET /analysis/atoms`
- `GET /saves/tree`
- `POST /saves/validate_output`
- `POST /missing/map/save`
- `POST /missing/map/load`
- `GET /preview`

### Needed for Flutter UI (To Add in Backend)
- None (current Flutter UI endpoints are implemented).

Notes:
- Prefer simple, stable DTOs and pagination.
- Allowlist any file streaming to varspath/vampath/cache only.

## UX/Performance Rules
- Lazy-load preview images; cache thumbnails in memory.
- Debounce search/filter input (200-300ms).
- Poll job status at 300-800ms; slow down when idle.
- Show job logs in a shared panel to match WinForms UX.

## Deployment Rules
- Bundle layout (zip):
  - `varManager_flutter.exe`
  - `varManager_backend.exe`
  - `plugin/vam_downloader.exe`
  - `config.json` (created if missing)
- Working directory is the bundle root.

## Progress Tracking
### Milestones
- [x] App shell + theme + routing
- [x] Backend process manager + health check
- [x] Core list (vars) + filters + selection
- [x] Job runner + log panel
- [x] Settings (read/write config)
- [x] Missing vars flow
- [x] Scenes + analysis flows
- [x] Hub flow
- [ ] Packaging + smoke tests

### Tracking Table
| Area | Task | Status | Notes |
| --- | --- | --- | --- |
| App Shell | Theme + routing + layout | DONE | Material3 baseline + rail |
| Backend | Process manager + health | DONE | Start/stop flow |
| Data | BackendClient + DTOs | DONE | Single base URL |
| Home | Vars list + filters | PARTIAL | list + preview + pagination/sort done; column-level filters + grid columns pending |
| Jobs | Update DB / install / uninstall | DONE | job flow + logs |
| Scenes | List + actions | DONE | 3-column layout + drag + filters + paging done; no width toggles |
| Hub | Browse + download | DONE | hub_info filters + cards + paging + repo status |
| Missing Vars | Link map + actions | DONE | ignore-version + row nav + downloads + map io |
| Settings | Config read/write | DONE | runtime update |
| Packaging | Zip layout + smoke test | TODO | |

### Parity TODO (WinForms -> Flutter)
- Home: column-level filters (WinForms DgvFilter).
- Home: expose grid-style columns (size/type counts/disabled) or equivalent detail view.
- Home: Clear Cache action for the current preview entry.
- Scenes: width toggles for Hide/Normal/Fav columns (optional parity).

## Differences vs WinForms (Current)
- Home uses a simplified list view; no DataGridView header filters or full column set.
- Home preview panel lacks the current-entry cache clear action (Form1 buttonClearCache).
- Settings are editable via `PUT /config` (WinForms settings dialog is read-only).
- Scenes uses responsive columns with drag/drop; no explicit width-toggle buttons.
