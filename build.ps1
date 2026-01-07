param(
    [ValidateSet("build", "clean", "release")]
    [string]$Action = "build",

    [ValidateSet("all", "flutter", "backend")]
    [string]$Project = "all",

    [switch]$SkipFlutterPubGet
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$flutterDir = Join-Path $root "varmanager_flutter"
$backendDir = Join-Path $root "varManager_backend"
$releaseRoot = Join-Path $root "release"
$script:ProjectVersion = $null

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing directory: $Path"
    }
}

function Ensure-Tool {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing tool in PATH: $Name"
    }
}

function Get-ProjectVersion {
    $versionPath = Join-Path $root "VERSION"
    if (-not (Test-Path -LiteralPath $versionPath)) {
        throw "Missing VERSION file: $versionPath"
    }
    $raw = Get-Content -LiteralPath $versionPath -TotalCount 1
    $version = $raw.Trim()
    if ([string]::IsNullOrWhiteSpace($version)) {
        throw "VERSION file is empty"
    }
    return $version
}

function Sync-VersionFiles {
    param([string]$Version)

    $pubspecPath = Join-Path $flutterDir "pubspec.yaml"
    if (Test-Path -LiteralPath $pubspecPath) {
        $lines = @(Get-Content -LiteralPath $pubspecPath)
        $updated = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*version\s*:') {
                $lines[$i] = "version: $Version+0"
                $updated = $true
                break
            }
        }
        if ($updated) {
            Set-Content -LiteralPath $pubspecPath -Value $lines -Encoding ascii
        }
    }

    $cargoPath = Join-Path $backendDir "Cargo.toml"
    if (Test-Path -LiteralPath $cargoPath) {
        $lines = @(Get-Content -LiteralPath $cargoPath)
        $inPackage = $false
        $updated = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match '^\s*\[package\]\s*$') {
                $inPackage = $true
                continue
            }
            if ($line -match '^\s*\[.*\]\s*$') {
                $inPackage = $false
            }
            if ($inPackage -and $line -match '^\s*version\s*=\s*".*"\s*$') {
                $lines[$i] = "version = `"$Version`""
                $updated = $true
                break
            }
        }
        if ($updated) {
            Set-Content -LiteralPath $cargoPath -Value $lines -Encoding ascii
        }
    }
}

function Ensure-EmptyDir {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Invoke-Checked {
    param(
        [string]$Exe,
        [string[]]$ArgumentList,
        [string]$WorkDir
    )
    Write-Host ("> " + $Exe + " " + ($ArgumentList -join " "))
    Push-Location $WorkDir
    try {
        & $Exe @ArgumentList
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed: $Exe $($ArgumentList -join ' ')"
        }
    }
    finally {
        Pop-Location
    }
}

function Clean-Flutter {
    Ensure-Dir $flutterDir
    Ensure-Tool "flutter"
    Invoke-Checked -Exe "flutter" -ArgumentList @("clean") -WorkDir $flutterDir
}

function Build-Flutter {
    param([ValidateSet("debug", "release")] [string]$Mode)
    Ensure-Dir $flutterDir
    Ensure-Tool "flutter"
    if (-not $script:ProjectVersion) {
        $script:ProjectVersion = Get-ProjectVersion
    }
    if (-not $SkipFlutterPubGet) {
        Invoke-Checked -Exe "flutter" -ArgumentList @("pub", "get") -WorkDir $flutterDir
    }
    $flutterArgs = @("build", "windows")
    if ($Mode -eq "debug") {
        $flutterArgs += "--debug"
    }
    elseif ($Mode -eq "release") {
        $flutterArgs += "--release"
    }
    $flutterArgs += "--dart-define=APP_VERSION=$script:ProjectVersion"
    $flutterArgs += "--build-name"
    $flutterArgs += $script:ProjectVersion
    $flutterArgs += "--build-number"
    $flutterArgs += "0"
    Invoke-Checked -Exe "flutter" -ArgumentList $flutterArgs -WorkDir $flutterDir
}

function Clean-Backend {
    Ensure-Dir $backendDir
    Ensure-Tool "cargo"
    Invoke-Checked -Exe "cargo" -ArgumentList @("clean") -WorkDir $backendDir
}

function Build-Backend {
    param([ValidateSet("debug", "release")] [string]$Mode)
    Ensure-Dir $backendDir
    Ensure-Tool "cargo"
    if (-not $script:ProjectVersion) {
        $script:ProjectVersion = Get-ProjectVersion
    }
    $cargoArgs = @("build")
    if ($Mode -eq "release") {
        $cargoArgs += "--release"
    }
    $previousVersion = $env:APP_VERSION
    $env:APP_VERSION = $script:ProjectVersion
    try {
        Invoke-Checked -Exe "cargo" -ArgumentList $cargoArgs -WorkDir $backendDir
    }
    finally {
        if ($null -eq $previousVersion) {
            Remove-Item Env:APP_VERSION -ErrorAction SilentlyContinue
        }
        else {
            $env:APP_VERSION = $previousVersion
        }
    }
}

function Stage-FlutterRelease {
    Ensure-Dir $flutterDir
    $src = $null
    $primary = Join-Path $flutterDir "build\\windows\\x64\\runner\\Release"
    $fallback = Join-Path $flutterDir "build\\windows\\runner\\Release"
    if (Test-Path -LiteralPath $primary) {
        $src = $primary
    }
    elseif (Test-Path -LiteralPath $fallback) {
        $src = $fallback
    }
    if (-not $src) {
        Write-Warning "Flutter release output not found."
        return
    }

    $dest = Join-Path $releaseRoot "flutter\\windows"
    Ensure-EmptyDir $dest
    if (Test-Path -LiteralPath $src -PathType Leaf) {
        Copy-Item -LiteralPath $src -Destination $dest -Force
    }
    else {
        Copy-Item -Path (Join-Path $src "*") -Destination $dest -Recurse -Force
    }
    $versionPath = Join-Path $root "VERSION"
    if (Test-Path -LiteralPath $versionPath) {
        Copy-Item -LiteralPath $versionPath -Destination (Join-Path $dest "VERSION") -Force
    }
}

function Stage-BackendRelease {
    Ensure-Dir $backendDir
    $srcDir = Join-Path $backendDir "target\\release"
    if (-not (Test-Path -LiteralPath $srcDir)) {
        Write-Warning "Backend release output not found: $srcDir"
        return
    }

    $dest = Join-Path $releaseRoot "backend"
    Ensure-EmptyDir $dest

    $binaries = Get-ChildItem -Path $srcDir -File -Filter "*.exe"
    if (-not $binaries) {
        Write-Warning "No backend executables found in $srcDir"
        return
    }

    foreach ($bin in $binaries) {
        Copy-Item -LiteralPath $bin.FullName -Destination $dest -Force
        $pdb = Join-Path $srcDir ($bin.BaseName + ".pdb")
        if (Test-Path -LiteralPath $pdb) {
            Copy-Item -LiteralPath $pdb -Destination $dest -Force
        }
    }
}

function Stage-VaMPlugins {
    # Copy VaM plugin scripts (user needs to manually copy these to VaM/Custom/Scripts/)
    $pluginScripts = @(
        "Custom\\Scripts\\loadscene.cs",
        "Custom\\Scripts\\MorphMerger.cs"
    )

    $dest = Join-Path $releaseRoot "vam_plugins"
    Ensure-EmptyDir $dest

    foreach ($script in $pluginScripts) {
        $src = Join-Path $root $script
        if (Test-Path -LiteralPath $src) {
            Copy-Item -LiteralPath $src -Destination $dest -Force
            Write-Host "Copied VaM plugin: $script"
        }
        else {
            Write-Warning "VaM plugin script not found: $src"
        }
    }

    # Create README for VaM plugins
    $readmeContent = @"
# VaM Plugins

These C# scripts are designed to run inside Virt-A-Mate (VaM) game engine.

## Installation

1. Locate your VaM installation directory
2. Navigate to ``Custom\Scripts\`` folder
3. Copy these ``.cs`` files to that folder
4. The scripts will be available in VaM's plugin list

## Included Scripts

- **loadscene.cs** - Scene loader with MMD support
- **MorphMerger.cs** - Morph merging utility

## Requirements

- Virt-A-Mate installed
- These scripts use Unity engine APIs and cannot run outside VaM

## Source Code

Full source code with LibMMD library is available in the ``LoadScene/`` directory of the main repository.
"@
    Set-Content -Path (Join-Path $dest "README.txt") -Value $readmeContent -Encoding UTF8
}

function Assemble-ReleasePackage {
    if (-not $script:ProjectVersion) {
        $script:ProjectVersion = Get-ProjectVersion
    }
    $targetName = "varManager_$script:ProjectVersion"
    $target = Join-Path $releaseRoot $targetName
    Ensure-EmptyDir $target

    # Copy Flutter frontend
    $flutterSrc = Join-Path $releaseRoot "flutter\\windows"
    if (Test-Path -LiteralPath $flutterSrc) {
        Copy-Item -Path (Join-Path $flutterSrc "*") -Destination $target -Recurse -Force
    }
    else {
        Write-Warning "Flutter release folder not found: $flutterSrc"
    }

    # Copy Rust backend
    $backendSrc = Join-Path $releaseRoot "backend"
    if (Test-Path -LiteralPath $backendSrc) {
        Copy-Item -Path (Join-Path $backendSrc "*") -Destination $target -Recurse -Force
    }
    else {
        Write-Warning "Backend release folder not found: $backendSrc"
    }

    # Copy VaM plugin scripts
    $vamPluginsSrc = Join-Path $releaseRoot "vam_plugins"
    if (Test-Path -LiteralPath $vamPluginsSrc) {
        $vamPluginsDest = Join-Path $target "VaM_Plugins"
        New-Item -ItemType Directory -Path $vamPluginsDest -Force | Out-Null
        Copy-Item -Path (Join-Path $vamPluginsSrc "*") -Destination $vamPluginsDest -Recurse -Force
        Write-Host "VaM plugins staged to: VaM_Plugins\"
    }
    else {
        Write-Warning "VaM plugins folder not found: $vamPluginsSrc"
    }

    # Copy documentation files
    $docFiles = @("VERSION", "README.md", "README_CN.md")
    foreach ($doc in $docFiles) {
        $src = Join-Path $root $doc
        if (Test-Path -LiteralPath $src) {
            Copy-Item -LiteralPath $src -Destination (Join-Path $target $doc) -Force
        }
    }

    # Create INSTALL.txt with quick start guide
    $installGuide = @"
# varManager v$script:ProjectVersion Quick Start

## Installation

1. Extract all files to a folder
2. Run varmanager_flutter.exe
3. The backend service will start automatically
4. Configure VaM paths in Settings
5. Click "Update DB" to scan your var files

## VaM Plugins (Optional)

If you want to use MMD scene loading features in VaM:
1. Open the `VaM_Plugins` folder
2. Copy the .cs files to your `VaM\Custom\Scripts\` directory
3. See VaM_Plugins\README.txt for details

## Requirements

- Windows 10/11 (64-bit)
- No additional runtime required (self-contained)

## Documentation

- README.md - Full documentation (English)
- README_CN.md - 完整文档 (中文)

## Support

GitHub: https://github.com/bustesoul/varManager
"@
    Set-Content -Path (Join-Path $target "INSTALL.txt") -Value $installGuide -Encoding UTF8
}

$doFlutter = @("all", "flutter") -contains $Project
$doBackend = @("all", "backend") -contains $Project
if ($Action -ne "clean") {
    $script:ProjectVersion = Get-ProjectVersion
    Sync-VersionFiles -Version $script:ProjectVersion
}

switch ($Action) {
    "clean" {
        if ($doFlutter) { Clean-Flutter }
        if ($doBackend) { Clean-Backend }
        if (Test-Path -LiteralPath $releaseRoot) {
            Write-Host "Cleaning release directory..."
            Remove-Item -LiteralPath $releaseRoot -Recurse -Force
        }
    }
    "build" {
        if ($doFlutter) { Build-Flutter "debug" }
        if ($doBackend) { Build-Backend "debug" }
    }
    "release" {
        if ($doFlutter) { Build-Flutter "release" }
        if ($doBackend) { Build-Backend "release" }
        if ($doFlutter) { Stage-FlutterRelease }
        if ($doBackend) { Stage-BackendRelease }
        Stage-VaMPlugins
        Assemble-ReleasePackage
        Write-Host "`nRelease package created at: release\varManager_$script:ProjectVersion"
        Write-Host "Package contents:"
        Write-Host "  - Flutter frontend (varmanager_flutter.exe)"
        Write-Host "  - Rust backend (varManager_backend.exe)"
        Write-Host "  - VaM plugins (VaM_Plugins\*.cs)"
        Write-Host "  - Documentation (README.md, README_CN.md, INSTALL.txt)"
    }
}

Write-Host "Done."
