# Development Setup Guide

## Installing Dependencies

This addon uses `.pkgmeta` to manage external library dependencies. The `.pkgmeta` file is processed by packaging tools to automatically download and include the correct versions of libraries.

### For Local Development Setup

We provide convenient setup scripts to clone and manage libraries locally:

#### Windows (PowerShell)
```powershell
# Clone/setup all libraries
.\setup-libs.ps1

# Update all existing libraries
.\setup-libs.ps1 -Update

# Clean up / remove all local libraries
.\setup-libs.ps1 -Clean
```

#### Linux/macOS (Bash)
```bash
# Clone/setup all libraries
./setup-libs.sh

# Update all existing libraries
./setup-libs.sh -u

# Clean up / remove all local libraries
./setup-libs.sh -c
```

### Using the CurseForge Packager

If you're packaging the addon for release, use the CurseForge packager (or equivalent tooling) to process the `.pkgmeta` file:

```bash
# This will automatically download and place all externals defined in .pkgmeta
# The packager will create a complete addon package with all dependencies
```

### Manual Development Setup

For local development, you can manually download the libraries to the `Libs/` directory, or use your preferred package management tool that supports `.pkgmeta` processing.

Libraries will be fetched from these repository URLs:
- **LibStub**: https://github.com/zerosnake0/LibStub
- **CallbackHandler-1.0**: https://github.com/zerosnake0/CallbackHandler-1.0
- **LibDataBroker-1.1**: https://github.com/tekkub/libdatabroker-1-1
- **LibDBIcon-1.0**: https://github.com/zerosnake0/LibDBIcon-1.0
- **Ace3**: https://github.com/WoWUIDev/Ace3

## New Features

### Minimap Icon
- The addon now displays a minimap icon (Gilded Crest) in the minimap
- Left-click the icon to toggle the checklist window
- The minimap icon state is managed by LibDBIcon and can be configured per character

### Improved SavedVariables
- Uses Ace3's AceDB-3.0 system for robust profile management
- Better support for per-character and account-wide settings
- Automatic migration from old SavedVariables format

### Better Options Panel  
- Ace3's configuration framework provides a more robust options interface
- Enhanced support for slash commands and option configuration

## File Structure

```
LariasWeeklyChecklist/
├── Libs/
│   ├── LibStub/                 (populated by pkgmeta)
│   ├── CallbackHandler-1.0/     (populated by pkgmeta)
│   ├── Ace3/                    (populated by pkgmeta)
│   ├── LibDataBroker-1.1/       (populated by pkgmeta)
│   └── LibDBIcon-1.0/           (populated by pkgmeta)
├── Locales/
│   ├── enUS.lua
│   ├── enUS_Data.lua
│   └── ...
├── data/
├── scripts/
├── LariasWeeklyChecklist.toc
├── LariasWeeklyChecklist.lua
├── LariasWeeklyChecklist_Constants.lua
├── LariasWeeklyChecklist_Currency.lua
├── .pkgmeta                     (dependency configuration)
└── README.md
```

## About .pkgmeta

The `.pkgmeta` file is the standard configuration file for WoW addon packaging tools. It specifies:

1. **externals**: External repository URLs for libraries
2. **ignore**: Files/directories to exclude from packaged releases
3. **game-versions**: Supported WoW versions for release

Tools like the CurseForge Packager automatically process this file to download the latest versions of all external libraries and create a complete, ready-to-use addon package.

## Setup Scripts

Two convenient setup scripts are provided to manage libraries locally for development:

### setup-libs.ps1 (Windows PowerShell)
Automates cloning and updating libraries for Windows development.

**Features:**
- Automatically checks for Git installation
- Creates the `Libs/` directory if needed
- Clones libraries if they don't exist
- Updates libraries with `-Update` switch
- Cleans up libraries with `-Clean` switch
- Color-coded output for clarity

**Requirements:**
- PowerShell 3.0 or later
- Git installed and available in PATH

### setup-libs.sh (Linux/macOS Bash)
Automates cloning and updating libraries for Unix-like systems.

**Features:**
- Automatically checks for Git installation
- Creates the `Libs/` directory if needed
- Clones libraries if they don't exist
- Updates libraries with `-u` or `--update` option
- Cleans up libraries with `-c` or `--clean` option
- Help information with `-h` or `--help`

**Requirements:**
- Bash shell
- Git installed and available in PATH

**Making the script executable:**
```bash
chmod +x setup-libs.sh
```

## Minimap Icon Configuration

The minimap icon automatically initializes on player login with the default "show" state. Users can control visibility through:

1. **Right-click the minimap icon** - Opens configuration menu (if LibDBIcon provides this)
2. **Addon options panel** - Future enhancement to add minimap visibility toggle

The icon display state is stored per-character and will persist across sessions.
