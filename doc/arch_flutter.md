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
| Home (Vars List) | Form1 | Main list, filters, toolbar actions, **PackSwitch panel (right sidebar)** | PARTIAL |
| Settings Dialog | FormSettings | Read + edit config | DONE |
| Missing Vars Dialog | FormMissingVars | Link map + hub actions | DONE |
| Scenes Page | FormScenes | Scene list + actions | DONE |
| Hub Page | FormHub + HubItem | Browse + download | DONE |
| Analysis Dialog | FormAnalysis | Preset/scene analysis | DONE |
| Prepare Saves Dialog | PrepareSaves | Output validation + copy list | DONE |
| Var Detail Dialog | FormVarDetail | Detail + locate + filter | DONE |
| Uninstall Vars Dialog | FormUninstallVars | Preview navigation | DONE |
| ~~PackSwitch Dialogs~~ | ~~FormSwitchAdd/Rename + VarsMove~~ | **Now integrated in Home Page sidebar** | DONE |

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
  - `varManager.exe`
  - `data/varManager_backend.exe`
  - `data/flutter_windows.dll`
  - `data/*_plugin.dll`
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

### Recent Changes (v2.0.0)
- **PackSwitch Integration**: PackSwitch functionality moved from separate page to Home page right sidebar (180px width, visible in wide mode >= 1200px). Matches original C# Form1 right panel design with dropdown selector and Add/Activate/Rename/Delete buttons.

## Comprehensive UI Differences: Flutter vs WinForms

### 1. Home Page (Form1) Differences

#### **1.1 Data Display**
| Feature | WinForms (Form1) | Flutter (HomePage) | Impact |
|---------|------------------|-------------------|--------|
| **Main List** | DataGridView (20 columns) | ListView with ListTile | Simplified view |
| **Column Count** | 20 visible columns (varName, installed, fsize, metaDate, varDate, scenes, looks, clothing, hairstyle, plugins, assets, morphs, pose, skin, disabled, etc.) | 4 visible fields (title, subtitle, status chip, details button) | Reduced information density |
| **Column Filtering** | DgvFilterPopup - right-click column header for advanced filtering | No column-level filtering | Missing advanced filter capability |
| **Row Selection** | Click row to select | Checkbox + row click | Similar |
| **Detail Button** | Column button in grid | Trailing button in ListTile | Similar functionality |
| **Install Status** | Checkbox column (clickable toggle) | Chip indicator only (non-interactive) | Less direct control |

#### **1.2 Filtering & Search**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Basic Filters** | Creator dropdown, search textbox, installed 3-state checkbox | Creator dropdown, search textbox, installed dropdown (3 options) | Similar capability |
| **Advanced Filters** | DgvFilterPopup with per-column filters | Dedicated filter row: package name, version, disabled, size range (min/max MB), dependency count range (min/max), 12 presence filters (hasScene, hasLook, etc.) | Different approach - Flutter has dedicated advanced filters but no column header filtering |
| **Filter Reset** | Reset button + DgvFilterPopup reset | Clear button in selection row | Similar |
| **Debouncing** | None (immediate filter) | 250ms search, 300ms filter debounce | Better UX in Flutter |

#### **1.3 Preview Panel**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Layout** | SplitContainer (resizable) | Responsive layout (Row/Column based on width) | Flutter adapts to screen size |
| **Preview List** | ListView (VirtualMode, 128x128 images) | GridView (dynamic 2-6 columns, responsive) | Flutter more flexible |
| **Cache Clear** | "Clear Cache" button for current preview entry | **MISSING** | Lost functionality |
| **Preview Type Filter** | ComboBox + "Loadable" checkbox | Dropdown filter | Similar |
| **Preview Detail** | TableLayoutPanel with text fields | Card with Image + text + buttons | Different layout approach |
| **Image Size** | Fixed ImageList 128x128 | BorderedImage (variable size) | More flexible in Flutter |

#### **1.4 Toolbar & Actions**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Main Actions** | Update DB, Start VAM, Install Selected, Uninstall Selected, Delete Selected | Update DB, Start VaM, Install Selected, Uninstall Selected (no Delete in main toolbar) | Delete moved to selection actions |
| **Pack Switch** | ComboBox + Add/Del/Rename buttons (right panel) | **Integrated in right sidebar (180px, dropdown + 4 buttons)** | **FIXED - Now matches original layout** |
| **Dependency Analysis** | 4 buttons: Installed Packages, All Packages, Saves JsonFile, Filtered Packages | 3 "Missing deps" buttons with level indicators (fast/normal/recursive) | Simplified to missing deps only |
| **Export/Import** | Export Insted, Install By TXT buttons | Export List, Import List buttons (in selection actions) | Similar functionality |
| **Move to SubDir** | Dedicated button | "Move to subdir" button (in selection actions) | Same functionality |
| **Browser/Hub** | "Brow" button with Hub logo | Dedicated Hub nav destination | Better organization in Flutter |

#### **1.5 Pagination**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Controls** | BindingNavigator (首页/上页/下页/末页) | Row with page numbers + navigation buttons | Similar functionality |
| **Per-Page Options** | Not visible in main grid | Dropdown (25/50/100/200) | More flexible in Flutter |
| **Position** | Top of grid | Top and bottom of list | Better UX in Flutter |

#### **1.6 Selection Info**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Selection Count** | Not prominently displayed | "X selected" text + Clear button | Better visibility in Flutter |
| **Selection Actions** | Bottom FlowLayoutPanel | Wrap below list (Install, Uninstall, Delete, Move, Export, Import, Locate) | More comprehensive action set |

---

### 2. Settings Page Differences

| Feature | WinForms (FormSettings) | Flutter (SettingsPage) | Impact |
|---------|------------------------|----------------------|--------|
| **Edit Mode** | Read-only display with folder browser | Editable TextFields | **MAJOR** - Flutter allows runtime config changes |
| **Path Selection** | FolderBrowserDialog, OpenFileDialog | Manual text input + validation | Less user-friendly in Flutter (no file picker) |
| **Config Persistence** | Not implemented (read-only) | `PUT /config` API saves to backend | Functional improvement |
| **Fields** | varspath, vampath, exec (3 fields) | All config.json fields editable | More comprehensive |
| **Validation** | None | Backend validation on save | Better error handling |

---

### 3. Missing Vars Page Differences

#### **3.1 Layout**
| Feature | WinForms (FormMissingVars) | Flutter (MissingVarsPage) | Impact |
|---------|---------------------------|--------------------------|--------|
| **Main List** | DataGridView with ToolStrip | Custom row-based table (header + ListView) | Different visual style |
| **Columns** | Grid columns | Flex-based Row (Missing Var, Link To, DL icon) | Similar information |
| **Details Panel** | Not present | Right sidebar (360px) with Details/Dependents/Dependent Saves | **MAJOR** - Better information display |

#### **3.2 Filtering**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Version Filter** | ToolStrip ComboBox (ignore version) | Dropdown (ignore/all) | Same functionality |
| **Creator Filter** | Not visible | Dropdown filter | Added in Flutter |
| **Search** | Not visible | TextField search | Added in Flutter |

#### **3.3 Navigation**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Row Navigation** | Scroll only | Page-based navigation (首页/上页/下页/末页 + row counter) | Better navigation in Flutter |

#### **3.4 Actions**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Download** | ToolStrip buttons | Card buttons in detail panel | Better organization |
| **Map I/O** | ToolStrip buttons | Separate card buttons | Similar functionality |
| **Link Editing** | In-grid editing | TextField in detail panel + Set/Clear buttons | More explicit in Flutter |
| **Google Search** | Not visible | "Google Search" button for selected var | Added in Flutter |

#### **3.5 Download Status**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Indicator** | Column text/icon | Icon with color coding (cloud_done=green, cloud_download=orange, block=grey) | More visual in Flutter |

---

### 4. Scenes Page Differences

#### **4.1 Display Mode**
| Feature | WinForms (FormScenes) | Flutter (ScenesPage) | Impact |
|---------|----------------------|---------------------|--------|
| **Main View** | Single ListView (VirtualMode) | 3-column layout (Hide/Normal/Fav) | **MAJOR** - Different organization |
| **Column Visibility** | Single list view | FilterChips to toggle column display | More flexible in Flutter |
| **Width Toggles** | Not present | Not present (responsive width) | Parity maintained |

#### **4.2 Scene Cards**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Layout** | ListViewItem with image | Card with Wrap (Image + Text + Chips + Buttons) | Richer card design |
| **Image Size** | Fixed (from ImageList) | ClipRRect 72x72 | Similar |
| **Actions** | Context menu or buttons | 6 TextButtons (Load, Analyze, Locate, etc.) | More visible in Flutter |

#### **4.3 Drag & Drop**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Implementation** | DragAndDropListView custom control | LongPressDraggable + DragTarget | Both support drag/drop |
| **Visual Feedback** | Custom feedback | Material elevation + opacity | Flutter more polished |

#### **4.4 Filtering**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Category** | ComboBox (8 types) | Dropdown (8 types) | Same |
| **Creator** | ComboBox | Dropdown | Same |
| **Location** | Not visible | FilterChips (Installed/Not installed/MissingLink/Save) | Added in Flutter |
| **Name Search** | TextBox | TextField | Same |
| **Sorting** | ComboBox (Date/VarName/Creator) | Dropdown (4 options) | Similar |
| **Advanced Options** | Checkboxes (Merge, Ignore gender, Male) | FilterChips | Same functionality, different UI |
| **Person Order** | RadioButtons (1-8) | Dropdown (1-8) | Different control type |

---

### 5. Hub Page Differences

#### **5.1 Layout**
| Feature | WinForms (FormHub) | Flutter (HubPage) | Impact |
|---------|-------------------|------------------|--------|
| **Main View** | DataGridView | GridView with ResourceCards | More visual in Flutter |
| **Sidebar** | Not present | Left sidebar (340px) with all filters | Better organization |

#### **5.2 Resource Display**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Format** | Table rows | Cards with Image + metadata | More modern UI |
| **Image** | No preview images | 96x96 thumbnail | Better visual browsing |
| **Actions** | Column buttons | Button row (Repository status, Add Downloads, Open Page) | Similar functionality |
| **Quick Filters** | Not present | ActionChip tags (paytype/type/creator) | Added convenience |

#### **5.3 Filtering**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Filter Location** | Top ComboBoxes | Left sidebar (all in one place) | Better organization |
| **Filter Count** | 7 filters | 7 filters (Location, Pay Type, Category, Creator, Tag, Primary Sort, Secondary Sort) | Same coverage |
| **Search** | Search box | TextField in sidebar | Same |

#### **5.4 Download Management**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Download List** | Separate section/dialog | Card in sidebar | Integrated view |
| **Actions** | ToolStrip buttons | Outlined buttons (Download All, Copy Links, Clear List) | Similar functionality |

#### **5.5 Repository Status**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Status Display** | Text in grid | FilledButton.tonal with dynamic text (In Repository/Generate Download/Upgrade/etc.) | More visual feedback |

---

### 6. Analysis Page Differences

#### **6.1 Layout**
| Feature | WinForms (FormAnalysis) | Flutter (AnalysisPage) | Impact |
|---------|------------------------|----------------------|--------|
| **Main View** | TreeView + ListBox | Left panel (320px) + Right tree panel (expanded) | Different organization |
| **Tree Control** | triStateTreeViewAtoms (custom) | ExpansionTile tree with Checkbox | Similar functionality |

#### **6.2 Person Selection**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Control** | ListBox | RadioListTile list in Card | More Material Design style |

#### **6.3 Look Options**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Type Filters** | Checkboxes | FilterChips | More compact in Flutter |
| **Person Order** | Not visible in Analysis form | Dropdown (1-8) | Added in Flutter |
| **Ignore Gender** | Checkbox | FilterChip | Same functionality |

#### **6.4 Actions**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Single Atom** | Buttons | FilledButtons (4: Load Look, Load Pose, Load Animation, Load Plugin) | Same functionality |
| **Scene Load** | Buttons | FilledButtons (4: Load Scene, Add To Scene, Add as Subscene, Clear Selection) | Same functionality |
| **Selection Count** | Not displayed | "X atoms selected" text | Better feedback in Flutter |

---

### 7. Var Detail Page Differences

| Feature | WinForms (FormVarDetail) | Flutter (VarDetailPage) | Impact |
|---------|-------------------------|------------------------|--------|
| **Layout** | 3 DataGridViews (Dependencies, Dependent Vars, Dependent Saves) | Cards with ListTile lists | Different visual approach |
| **Color Coding** | Row colors (red=missing, yellow=version mismatch, green=installed) | Row colors (red=missing, orange=close version, green=installed) | Similar with slight difference |
| **Actions** | Locate button, Filter buttons | Locate button, Filter buttons | Same functionality |
| **Info Display** | TextBox fields | Card text fields | Similar |

---

### 8. Other Pages Differences

#### **8.1 PackSwitch**
| Feature | WinForms (FormSwitchAdd/Rename + VarsMove) | Flutter (Integrated in HomePage) | Impact |
|---------|-------------------------------------------|----------------------------------|--------|
| **Organization** | Right panel in Form1 (159px width) | Right sidebar in HomePage (180px width, wide mode only) | **Restored to original layout** |
| **List Display** | ComboBox dropdown | ComboBox dropdown with "Active" badge | Similar with visual enhancement |
| **Buttons** | Add (blue), Del (orange-red), Rename (deep red) | Add (filled), Activate (tonal), Rename (outlined), Delete (outlined red) | Material Design 3 styling |

#### **8.2 Uninstall Vars Preview**
| Feature | WinForms (FormUninstallVars) | Flutter (UninstallVarsPage) | Impact |
|---------|------------------------------|---------------------------|--------|
| **Preview List** | DataGridView + preview panel | List + preview images | Similar |
| **Dependency Display** | DataGridView | List | Similar information |

#### **8.3 Prepare Saves**
| Feature | WinForms (PrepareSaves) | Flutter (PrepareSavesPage) | Impact |
|---------|------------------------|---------------------------|--------|
| **Tree Selection** | Custom tree control | ExpansionTile with 3-state checkboxes | Similar functionality |

---

### 9. Overall Architecture Differences

#### **9.1 Navigation**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Pattern** | Multiple Form windows | Single app with NavigationRail/NavigationBar | Modern single-page app |
| **Dialog Management** | ShowDialog for child forms | Navigator routes + Dialogs | More flexible routing |

#### **9.2 State Management**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Pattern** | BindingSource + DataTable + EF Core | Riverpod (StateProvider, FutureProvider) | Modern reactive approach |
| **Data Binding** | Two-way binding to DataTable | One-way binding with manual updates | Different paradigm |

#### **9.3 Theming**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Approach** | Manual color coding per control | Material3 ThemeData with color scheme | Consistent theming |
| **Customization** | Per-control properties | Global theme + component themes | More maintainable |

#### **9.4 Responsiveness**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Layout** | Fixed layouts with SplitContainers | LayoutBuilder + responsive breakpoints | Better multi-screen support |
| **Scaling** | DPI-aware but not responsive | Fully responsive (width/height breakpoints) | More modern |

#### **9.5 Performance**
| Feature | WinForms | Flutter | Impact |
|---------|----------|---------|--------|
| **Virtual Lists** | VirtualMode ListView (manual implementation) | Built-in ListView.builder lazy loading | Easier in Flutter |
| **Image Caching** | Manual ImageList management (limit 20) | Image provider caching + memory management | Better in Flutter |
| **Debouncing** | Not implemented | Debouncer class (250-300ms) | Better UX in Flutter |

---

### 10. Missing Features (WinForms → Flutter)

#### **10.1 Home Page**
1. **DgvFilterPopup** - Column header right-click advanced filtering (CRITICAL)
2. **Grid Columns** - No visibility for detailed stats (fsize, metaDate, varDate, counts for scenes/looks/clothing/hairstyle/plugins/assets/morphs/pose/skin)
3. **Clear Cache Button** - Preview panel lacks cache clear for current entry
4. **Install Checkbox Toggle** - Can't click to toggle install status directly in list

#### **10.2 General**
1. **File Picker Dialogs** - Settings page doesn't have FolderBrowserDialog/OpenFileDialog (manual text entry only)
2. **Log Analysis** - No dedicated log analysis feature (WinForms buttonLogAnalysis)
3. **Stale Vars** - No dedicated page for handling outdated package versions
4. **Old Version Vars** - No duplicate version cleanup UI

---

### 11. Added Features (Flutter → WinForms)

#### **11.1 Home Page**
1. **Advanced Filter Row** - Dedicated filter controls for size range, dependency count, presence filters
2. **Selection Actions Panel** - More visible action buttons for selected items
3. **Responsive Grid** - Preview grid adapts column count to screen width

#### **11.2 Missing Vars Page**
1. **Detail Sidebar** - Rich detail panel with dependents and dependent saves
2. **Google Search** - Direct search button for missing vars
3. **Page Navigation** - Better navigation with page controls

#### **11.3 Scenes Page**
1. **3-Column Layout** - Visual separation of Hide/Normal/Fav scenes
2. **Location Filter Chips** - Visual filter for Installed/Not installed/MissingLink/Save
3. **Reset Filters** - Dedicated reset button

#### **11.4 Hub Page**
1. **Visual Cards** - Image thumbnails for resources
2. **Sidebar Organization** - All filters in one organized panel
3. **Quick Filter Chips** - ActionChip tags for fast filtering
4. **Integrated Download List** - Download management in same view

#### **11.5 General**
1. **Editable Settings** - Runtime configuration changes
2. **Modern Navigation** - NavigationRail/NavigationBar with icon destinations
3. **Job Log Panel** - Shared job log viewer (matches WinForms ListBox but more integrated)

---

## Summary of Critical Gaps

### Must Implement for Parity:
1. **Home Page Column Filtering** - DgvFilterPopup equivalent for advanced per-column filtering
2. **Home Page Column Display** - Show detailed stats (size, dates, content counts) in grid or detail view
3. **Preview Cache Clear** - Add "Clear Cache" action for selected preview entry

### Nice to Have:
1. File picker dialogs for Settings page
2. Stale Vars management page
3. Log analysis feature
4. Direct install status toggle in list (checkbox interaction)

### Flutter Improvements Over WinForms:
1. Editable settings with backend persistence
2. Better responsive layouts
3. Modern Material Design 3 theming
4. More visual feedback (cards, chips, color coding)
5. Integrated navigation (no modal window juggling)
6. Better performance with built-in optimizations (lazy loading, caching)
7. **PackSwitch integrated in main page (no separate navigation needed)**
