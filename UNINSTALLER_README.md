# WinBtrfs Uninstaller

## Overview
`btrfs-uninstall.exe` is a **standalone** Windows executable that uninstalls the WinBtrfs filesystem driver from your system. The PowerShell uninstall script is embedded directly in the executable - no external files required!

## What It Does
This uninstaller:
- ✅ Removes WinBtrfs devices
- ✅ Uninstalls driver packages
- ✅ Deletes service registration
- ✅ Removes shell extension registry entries
- ✅ Cleans up installed binaries
- ✅ Verifies administrator privileges
- ✅ Provides user-friendly GUI dialogs
- ✅ **Fully self-contained - no external files needed**

## Requirements
- **Windows Vista or later** (x64)
- **Administrator privileges** (automatically checked)
- **PowerShell** (pre-installed on Windows 7+)

## Installation & Usage

### Quick Start
1. Download `btrfs-uninstall.exe` (just one file!)

2. Right-click `btrfs-uninstall.exe` → "Run as Administrator"

3. Follow the prompts

4. Reboot your system after uninstallation completes

### Command-Line Options
```cmd
btrfs-uninstall.exe [options]
```

**Available options:**
- `-Force` - Force removal of matching driver packages (when supported by pnputil)
- `-KeepDriverStore` - Skip driver package deletion, only remove service and binaries
- `-Help` or `-?` - Display help message

### Examples
```cmd
# Standard uninstall
btrfs-uninstall.exe

# Force removal of drivers
btrfs-uninstall.exe -Force

# Keep driver in driver store
btrfs-uninstall.exe -KeepDriverStore
```

## How It Works
The executable contains everything needed:
1. Checks if running with admin privileges
2. Extracts the embedded PowerShell script to a temporary file
3. Executes the script with the specified options
4. Automatically cleans up the temporary file
5. Displays the results via GUI dialogs

The PowerShell script (embedded inside) handles:
- Device removal via PnP manager
- Driver package cleanup with pnputil
- Service deletion
- Registry cleanup
- File removal

## Important Notes
- **⚠️ A system reboot is strongly recommended** after uninstallation, especially if `btrfs.sys` or `shellbtrfs.dll` were loaded
- The uninstaller does not delete Btrfs filesystem data on your drives
- You may need to manually remove any Btrfs partitions after uninstalling the driver

## Troubleshooting

### "Administrator privileges required" error
Right-click the executable and select "Run as Administrator".

### "Failed to start PowerShell" error
PowerShell is required but not found. Install PowerShell from Microsoft.

### Exit codes
- `0` - Success
- `1` - Error (check error dialogs or console output)
- Other - PowerShell script exit code

## Building from Source
Compiled using MinGW-w64 on Linux:
```bash
# Generate embedded script header
cat uninstall-winbtrfs.ps1 | \
    sed 's/\\/\\\\/g; s/"/\\"/g; s/^/"/; s/$/\\n"/' \
    > src/uninstaller/embedded-script.h

# Compile standalone executable
x86_64-w64-mingw32-gcc -O2 -municode -mwindows \
    src/uninstaller/btrfs-uninstall-standalone.c \
    -o btrfs-uninstall.exe \
    -lshell32
```

Or use Visual Studio on Windows with the provided source files.

## License
This tool is part of the WinBtrfs project and follows the same LGPL license.

## Related Files
- `btrfs-uninstall.exe` - This standalone uninstaller executable (Windows GUI app with embedded PowerShell script)
- `uninstall-winbtrfs.ps1` - PowerShell script (embedded in the executable, also available separately in the repository)
- `mkbtrfs.exe` - Tool for creating Btrfs filesystems (separate utility)

## Support
For issues with the WinBtrfs driver or uninstaller:
- GitHub: https://github.com/maharmstone/btrfs
- Report issues in the main WinBtrfs repository
