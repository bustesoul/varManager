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
| Home (Vars List) | Form1 | Main list, filters, toolbar actions | TODO |
| Settings Dialog | FormSettings | Read + edit config | TODO |
| Missing Vars Dialog | FormMissingVars | Link map + hub actions | TODO |
| Scenes Page | FormScenes | Scene list + actions | TODO |
| Hub Page | FormHub + HubItem | Browse + download | TODO |
| Analysis Dialog | FormAnalysis | Preset/scene analysis | TODO |
| Prepare Saves Dialog | PrepareSaves | Output validation + copy list | TODO |
| Var Detail Dialog | FormVarDetail | Detail + locate + filter | TODO |
| Uninstall Vars Dialog | FormUninstallVars | Preview navigation | TODO |
| PackSwitch Dialogs | FormSwitchAdd/Rename + VarsMove | Add/rename/move | TODO |

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
### Existing (Backend Done)
- `GET /health`
- `GET /config`
- `POST /shutdown`
- `POST /jobs`
- `GET /jobs/{id}`
- `GET /jobs/{id}/logs`
- `GET /jobs/{id}/result`

### Needed for Flutter UI (To Add in Backend)
Minimum list/query endpoints to avoid direct SQLite access:
- `PUT /config` (validate + persist updates)
- `GET /vars` (filters + pagination + summary)
- `GET /vars/{varName}` (detail, deps, preview refs)
- `GET /scenes` (filters + pagination)
- `GET /creators` (distinct list for filters)
- `GET /stats` (counts for UI badges)
- `GET /preview` (stream preview image with allowlist)

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
- [ ] App shell + theme + routing
- [ ] Backend process manager + health check
- [ ] Core list (vars) + filters + selection
- [ ] Job runner + log panel
- [ ] Settings (read/write config)
- [ ] Missing vars flow
- [ ] Scenes + analysis flows
- [ ] Hub flow
- [ ] Packaging + smoke tests

### Tracking Table
| Area | Task | Status | Notes |
| --- | --- | --- | --- |
| App Shell | Theme + routing + layout | TODO | Material3 baseline |
| Backend | Process manager + health | TODO | Start/stop flow |
| Data | BackendClient + DTOs | TODO | Single base URL |
| Home | Vars list + filters | TODO | Parity with WinForms |
| Jobs | Update DB / install / uninstall | TODO | Job flow standard |
| Scenes | List + actions | TODO | |
| Hub | Browse + download | TODO | |
| Missing Vars | Link map + actions | TODO | |
| Settings | Config read/write | TODO | |
| Packaging | Zip layout + smoke test | TODO | |
