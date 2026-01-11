# varManager Project Structure

## Active Projects (v2.0.0)

```
varManager/
├── .github/workflows/build.yml  # GitHub Actions CI
├── build.ps1                    # Build/release script
├── VERSION                      # Version source of truth
├── README.md                    # Main documentation
├── README_CN.md                 # 中文文档
├── PROJECT_STRUCTURE.md         # This file
├── varmanager_flutter/          # Flutter frontend (Dart)
│   ├── lib/
│   │   ├── app/                 # App shell, theme, routing
│   │   ├── core/                # Backend client, models, utils
│   │   ├── features/            # Feature pages
│   │   ├── l10n/                # Localization resources
│   │   └── widgets/             # Shared UI components
│   ├── windows/                 # Windows runner
│   ├── linux/                   # Linux runner
│   ├── macos/                   # macOS runner
│   ├── ios/                     # iOS runner
│   ├── android/                 # Android runner
│   ├── web/                     # Web runner
│   └── pubspec.yaml             # Flutter dependencies
│
├── varManager_backend/          # Rust backend (HTTP service)
│   ├── src/
│   │   ├── main.rs              # Axum server entry
│   │   ├── api/                 # HTTP API
│   │   ├── app/                 # App wiring
│   │   ├── domain/              # Domain logic
│   │   ├── infra/               # IO, FS, download, DB helpers
│   │   ├── jobs/                # Job handlers
│   │   ├── scenes/              # Scene analysis pipeline
│   │   ├── services/            # Shared services
│   │   └── util/                # Utilities
│   └── Cargo.toml               # Rust dependencies
│
├── Custom/Scripts/              # VaM plugin scripts (C#)
│   ├── loadscene.cs             # MMD scene loader
│   ├── MorphMerger.cs           # Morph merge utility
│   └── README.md                # Usage guide
│
├── LoadScene/                   # C# library for VaM plugins
│   └── src/LibMMD/              # MMD model/motion parser
│
├── MMDLoader/                   # Standalone WPF tool (optional)
│   └── *.xaml, *.cs             # WPF application
│
└── _archived/                   # Legacy C# WinForms code (v1.0.4.x)
    ├── varManager/              # Old main program
    ├── DragNDrop/               # Old custom controls
    ├── StarRatingControl/
    ├── ThreeStateTreeView/
    └── ...                      # For reference only
```

## Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Frontend** | Flutter 3.10+ (Dart) | Cross-platform UI (Windows/macOS/Linux) |
| **Backend** | Rust + Axum + Tokio | HTTP service, async job system, Hub downloads |
| **Database** | SQLite (sqlx) | Lightweight data storage |
| **VaM Plugins** | C# (Unity scripting) | In-game scripts for VaM |

## Build Artifacts

### Release Package Structure:
```
varManager_v2.0.0/
├── varManager.exe              # Main application
├── data/                        # Runtime data and backend
│   ├── varManager_backend.exe  # Backend service
│   ├── flutter_windows.dll     # Flutter runtime
│   ├── *_plugin.dll            # Plugin DLLs
│   └── flutter_assets/         # Flutter assets
├── VaM_Plugins/
│   ├── loadscene.cs
│   ├── MorphMerger.cs
│   └── README.txt
├── config.json                  # Auto-generated
├── VERSION
├── README.md
├── README_CN.md
└── INSTALL.txt                  # Auto-generated
```

## Development Workflow

### 1. Local Development
```powershell
# Build debug version
.\build.ps1 -Action build

# Build release package
.\build.ps1 -Action release

# Clean build artifacts
.\build.ps1 -Action clean
```

### 2. CI/CD (GitHub Actions)
- Workflow: `.github/workflows/build.yml`
- Trigger: push/PR to `master`, and manual dispatch
- Builds Flutter frontend and Rust backend via `.\build.ps1 -Action release`
- Uploads `release/varManager_<version>` as a GitHub artifact

### 3. VaM Plugin Development
```bash
# Edit scripts in Custom/Scripts/
# No build needed - VaM compiles at runtime
# Copy .cs files to VaM/Custom/Scripts/
```

## Key Directories

| Directory | Status | Git Tracked | Purpose |
|-----------|--------|-------------|---------|
| `varmanager_flutter/` | ✅ Active | Yes | Main UI |
| `varManager_backend/` | ✅ Active | Yes | Backend service |
| `Custom/Scripts/` | ✅ Active | Yes | VaM plugins |
| `LoadScene/` | ✅ Active | Yes | Plugin library source |
| `MMDLoader/` | ⚠️ Optional | Yes | Standalone tool |
| `_archived/` | 📦 Legacy | Yes | Old C# code |

## Documentation

- **README.md** - Main documentation (English)
- **README_CN.md** - 中文文档
- **PROJECT_STRUCTURE.md** - This file
- **Custom/Scripts/README.md** - VaM plugin guide
- **_archived/README.md** - Legacy code reference

## Notes

1. **VaM Plugins:** Source files committed to Git, no compilation needed
2. **config.json:** Generated on first run, not stored in the repository
3. **_archived/:** Historical reference, not part of active development
4. **LoadScene/MMDLoader:** Source available for manual building if needed
