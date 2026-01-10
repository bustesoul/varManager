# varManager
[English](README.md) | [简体中文](README_CN.md)

A modern var package manager for Virt-A-Mate. Manage your var files efficiently using symbolic links, with a beautiful cross-platform UI and powerful backend.

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

**1. Modern User Interface**
- Material Design 3 theme with responsive layouts
- Real-time job log streaming
- Improved filtering and search capabilities
- Better preview image management
- Integrated PackSwitch in main window

**2. Performance & Reliability**
- Rust-powered backend for faster processing
- Asynchronous job queue with concurrent execution
- Better memory management and caching
- Native Windows symbolic link support

**3. Cross-Platform Ready**
- Built with Flutter - supports Windows, macOS, and Linux
- No .NET Runtime dependency required
- Smaller deployment size
- Easier installation

**4. Enhanced Features**
- Complete dependency analysis (fast/normal/recursive modes)
- Hub integration with batch downloads
- Scene analysis with drag-and-drop organization
- Missing vars resolution with smart linking
- Stale package cleanup

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

#### What Happened to the C# Version?

The legacy C# WinForms application (v1.0.4.x) has been **archived** to the `_archived/` folder for reference. All functionality has been migrated to the new Flutter + Rust architecture with feature parity and improvements.

**If you need the old C# version:**
- You can find it in the `_archived/varManager/` directory
- Requires .NET 9.0 Runtime
- No longer actively maintained

#### Migration from v1.0.4.x

Your data is safe! The new version uses the same SQLite database format:
- ✅ Your var repository configuration is preserved
- ✅ All package install states are retained
- ✅ Scene favorites and hide lists are kept
- ✅ Missing var link mappings are maintained

Simply run the new version in the same folder and everything will work.

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

---

## Legacy Version History

### Version 1.0.4.13 Update Tips (Archived):
0. **Upgrade Notice**: Before deploying the new version, remove the old program directory. Cleanup guide (if you keep the folder): `varManager.mdb` (old Access DB), `varManager.exe`, `varManager.pdb`, `varManager.dll.config` (you can edit it to extract old settings), `varManager.db*`, `varManager.log`.
1. **Upgrade**: Switch database to SQLite and upgrade to .NET 9.
2. **First Run Notice**: On first run, please click `UPD_DB` to rebuild the database.
3. **No Data Loss**: Your var files and profile settings are not stored in the database, so they will not be lost.
4. **Form UX**: More windows are resizable, and redundant UpdateDB duplicate-file logs are reduced.

### Version 1.0.4.11 Update Tips:
1. **Support Multiple Download**: Support download multiple var by once click in 
MissingVarPage(after fetch missing var) and HubPage (after Generate Download List).
2. **Notice**: This new feature function is not stable now, you might be manually check download result and re-use it again.
You *MUST* click UPD_DB button after downloaded, otherwise it will repeatedly download the same var.

### Version 1.0.4.10 Update Tips:
0. **Upgrade Notice**: If you wish to retain your old variable profile, make sure to back up `varManager.mdb`. It is recommended to use the new version with a completely updated profile for optimal performance.
1. **Administrator IS NECESSARY**: Starting from version 1.0.4.9, `varManager.exe` must be run as an administrator due to the necessity of creating symlinks in .NET 6.0.
2. **Runtime Installation**: If `varManager.exe` fails to run, try installing the .NET Desktop Runtime 6.0 from [here](https://dotnet.microsoft.com/en-us/download/dotnet/6.0).
3. **New Button**: New `FetchDownloadFromHub` Button for Hub var resource get and download, it supports download missing single var at `depends analyse` page for now, download function powered by plugin [vam_downloader](https://github.com/bustesoul/vam_downloader).
