# WinBtrfs Uninstaller

## Overview
`btrfs-uninstall.exe` is a Windows executable that uninstalls the WinBtrfs filesystem driver from your system.

## What It Does
This uninstaller:
- ✅ Removes WinBtrfs devices
- ✅ Uninstalls driver packages
- ✅ Deletes service registration
- ✅ Removes shell extension registry entries
- ✅ Cleans up installed binaries
- ✅ Verifies administrator privileges
- ✅ Provides user-friendly GUI dialogs

## Requirements
- **Windows Vista or later** (x64)
- **Administrator privileges** (automatically checked)
- **PowerShell** (pre-installed on Windows 7+)
- **uninstall-winbtrfs.ps1** must be in the same directory

## Installation & Usage

### Quick Start
1. Download both files:
   - `btrfs-uninstall.exe`
   - `uninstall-winbtrfs.ps1`

2. Place them in the same directory

3. Right-click `btrfs-uninstall.exe` → "Run as Administrator"

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
The executable is a lightweight wrapper that:
1. Checks if running with admin privileges
2. Locates the PowerShell script in the same directory
3. Executes the script with the specified options
4. Displays the results via GUI dialogs

The actual uninstallation logic is in `uninstall-winbtrfs.ps1`, which handles:
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

### "Script not found" error
Ensure `uninstall-winbtrfs.ps1` is in the same directory as `btrfs-uninstall.exe`.

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
x86_64-w64-mingw32-gcc -O2 -municode -mwindows \
    src/uninstaller/btrfs-uninstall.c \
    -o btrfs-uninstall.exe \
    -lshell32
```

Or use Visual Studio on Windows with the provided source files.

## License
This tool is part of the WinBtrfs project and follows the same LGPL license.

## Related Files
- `btrfs-uninstall.exe` - This uninstaller executable (Windows GUI app)
- `uninstall-winbtrfs.ps1` - PowerShell script with uninstall logic
- `mkbtrfs.exe` - Tool for creating Btrfs filesystems (separate utility)

## Support
For issues with the WinBtrfs driver or uninstaller:
- GitHub: https://github.com/maharmstone/btrfs
- Report issues in the main WinBtrfs repository
