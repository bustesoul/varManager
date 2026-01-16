# varManager
[English](README.md) | [简体中文](README_CN.md)

A modern var package manager for Virt-A-Mate. Manage your var files efficiently using symbolic links, with a beautiful Flutter UI and powerful backend.

## Current Version: 2.0.0 (Major Update)

### What's New in v2.0.0

**Complete Architecture Rewrite** - We've rebuilt varManager from the ground up with modern technologies:

#### New Architecture
```
┌─────────────────────────────────┐
│  Flutter Frontend (Dart)        │  Cross-platform UI with Material Design 3
├─────────────────────────────────┤
│  Rust Backend (HTTP Service)    │  High-performance async job system
├─────────────────────────────────┤
│  SQLite Database                │  Lightweight data storage
└─────────────────────────────────┘
```

#### Key Improvements

**1. Modern UI & Workflows**
- Material Design 3 with responsive layouts and navigation rail
- Interactive onboarding wizard for first-time path setup
- Theme + language switching (Ocean/Forest/Rose/Dark; English/Chinese)
- Advanced VAR filters (size/deps/content types) and batch actions
- PackSwitch integrated into the Home sidebar
- Export/Import installed var lists for sharing or backup
- Missing Vars detail panel with dependents, map I/O, and Hub actions

**2. Scenes & Analysis**
- Hide/Normal/Fav 3-column board with drag-and-drop organization
- Atom tree view with dependency tracking and person details
- Scene analysis cache with clear-cache actions
- Quick actions for load/analyze/locate

**3. Hub & Downloads**
- Tag search + quick filter chips; card view with ratings/version/deps
- Detail dialog for extra fields (file size, program version, license)
- Download list builder with total size, copy links for external tools, and Download All
- Built-in download manager with pause/resume/cancel/retry and configurable concurrency
- Hub result caching to reduce redundant requests

**4. Dependency & Link Management**
- Missing dependency scan from installed packages, Saves folder, and VaM log
- Link substitution workflow with draft/apply mappings in the detail panel
- Native symlink support (no admin required)

**5. Performance & Deployment**
- Rust backend with async job queue and live log streaming
- Unified preview pipeline with memory + disk image cache
- Runtime config editing with validation and file pickers
- Self-contained bundle with backend auto-start/health/shutdown
- Windows-first Flutter app (cross-platform ready)

#### Installation & Deployment

**Package Structure:**
```
varManager_v2.0.0/
├── varManager.exe              # Main application (Flutter)
├── data/                        # Runtime data and backend
│   ├── varManager_backend.exe  # Backend service (Rust)
│   ├── flutter_windows.dll     # Flutter runtime
│   ├── *_plugin.dll            # Plugin DLLs
│   └── flutter_assets/         # Flutter assets
├── VaM_Plugins/                 # VaM game plugins (optional)
│   ├── loadscene.cs            # MMD scene loader
│   ├── MorphMerger.cs          # Morph merge utility
│   └── README.txt              # Plugin installation guide
└── config.json                 # Auto-generated on first run
```

**First Run:**
1. Extract all files to a folder
2. Run `varManager.exe`
3. The backend will start automatically
4. Configure your VaM paths in Settings
5. Click "Update DB" to scan your var files

**VaM Plugins (Optional):**

The release package includes optional VaM plugin scripts in the `VaM_Plugins/` folder:

- **loadscene.cs** - Load MMD scenes and animations directly in VaM
- **MorphMerger.cs** - Merge morphs for character customization

To use these plugins:
1. Locate your VaM installation directory
2. Navigate to `Custom\Scripts\` folder
3. Copy the `.cs` files from `VaM_Plugins/` to that folder
4. Launch VaM and find the plugins in the plugin list

⚠️ **Note:** These scripts run inside VaM's Unity engine and are separate from the varManager application.

**Hub Download Support:**

The varManager backend has built-in support for downloading var packages directly from VaM Hub:

- Integrated into the Hub browsing feature
- Supports batch downloads
- Handles authentication with VaM Hub automatically
- Configure your VaM Hub credentials in Settings when first using the download feature

**No Additional Runtime Required:**
- ❌ No .NET Runtime installation needed
- ❌ No administrator rights required (for normal operations)
- ✅ Self-contained executables
- ✅ Portable - run from any folder

**System Requirements:**
- **OS:** Windows 10/11 (64-bit)
- **Runtime:** None (Self-contained)
- **Permissions:** Standard User (No admin required)

**Configuration Tips:**
- Proxy support: configure HTTP proxy in Settings (system auto-detect or manual) for Hub downloads
- Paths: `vampath` is your main VaM install path; `varspath` defaults to the same path (only set it separately if your .var files live on another folder/drive)

**Known Issues:**
- Windows first: macOS and Linux builds are not yet available in this release
- Hub limits: some Hub resources may encounter rate limiting during heavy bulk downloads

---

## Building from Source (Developers)

If you want to build varManager from source:

### Prerequisites
- **Flutter SDK** 3.10+ (for frontend)
- **Rust toolchain** (for backend)
- **Git**

### Build Everything
```powershell
# Build debug version (Flutter + Rust Backend)
.\build.ps1 -Action build

# Build release package
.\build.ps1 -Action release
```

The build script automatically:
1. Builds the Flutter frontend
2. Compiles the Rust backend
3. Copies VaM plugin scripts
4. Packages everything into `release/varManager_<version>/`
