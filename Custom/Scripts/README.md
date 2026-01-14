# VaM Plugin Scripts

This directory contains C# scripts designed to run inside **Virt-A-Mate (VaM)** game engine.

## Included Scripts

### 1. loadscene.cs
**Scene loader with MMD support**

- Loads MMD (MikuMikuDance) models and animations
- Converts VMD motion data to VaM Timeline
- Supports PMX model import

**Dependencies:**
- VaM Unity engine APIs

### 2. MorphMerger.cs
**Morph merging utility**

- Merges character morphs
- Combines multiple morph presets
- Optimizes morph data

## Usage

### For VaM Users:
1. Copy these `.cs` files to your VaM installation:
   ```
   <VaM Installation>/Custom/Scripts/
   ```
2. Launch VaM
3. Find the plugins in the plugin list
4. VaM's Unity engine will compile these scripts automatically

## Technical Details

- **Language:** C# (Unity scripting)
- **Framework:** .NET 3.5 (Unity compatibility)
- **Runtime:** VaM Unity engine (runtime compilation)
- **No pre-compilation needed:** VaM compiles these scripts on load

## Source Code

These scripts are maintained as part of the varManager project:
- **Main Repository:** https://github.com/bustesoul/varManager

## Note

⚠️ **These scripts cannot run outside VaM** because they depend on Unity engine APIs that are only available in VaM's runtime environment.
