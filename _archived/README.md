# Archived C# Projects

This directory contains the legacy C# WinForms implementation of varManager (v1.0.4.x).

## Contents

- **varManager/** - Main C# WinForms application (.NET 9.0)
- **DragNDrop/** - Custom drag-and-drop ListView control
- **StarRatingControl/** - Star rating control
- **ThreeStateTreeView/** - Three-state tree view control
- **HUB/** - Empty placeholder project
- **packages/** - NuGet package cache
- **varManager.sln** - Visual Studio solution file

## Status

⚠️ **This code is no longer actively maintained.**

All functionality has been migrated to the new Flutter + Rust architecture (v2.0.0+).

## Why Archived?

The v2.0.0 release represents a complete architectural rewrite:
- **Old:** C# WinForms + .NET Runtime + EF Core + SQLite
- **New:** Flutter UI + Rust Backend + SQLite

The new architecture provides:
- Cross-platform support (Windows/macOS/Linux)
- Better performance (Rust backend)
- Modern UI (Material Design 3)
- No .NET Runtime dependency
- Smaller deployment size
- Easier maintenance

## Reference Use Only

This code is kept for:
- Historical reference
- Understanding migration decisions
- Fallback if critical issues arise with v2.0.0

## Running the Old C# Version

If you need to run the legacy version:

1. Requirements:
   - .NET 9.0 Runtime
   - Windows OS
   - Visual Studio 2022 or higher (for building)

2. Build:
   ```
   cd _archived
   dotnet build varManager.sln
   ```

3. Run:
   ```
   cd varManager/bin/Debug/net9.0-windows
   varManager.exe
   ```

## Migration to v2.0.0

See the main [README.md](../README.md) for migration instructions. Your database and configuration will work seamlessly with the new version.
