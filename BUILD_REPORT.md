# WinBtrfs Build Report

**Build Date:** May 10, 2026  
**Build System:** Fedora Linux 43 with MinGW-w64 cross-compiler  
**Target Platform:** Windows x86-64

## Successfully Built

### ✅ btrfs-uninstall.exe (271 KB)
- **Location:** `/home/travis/git/btrfs-uninstall/btrfs-uninstall.exe`
- **Type:** PE32+ executable for MS Windows (GUI application)
- **Architecture:** x86-64
- **Purpose:** Uninstaller for WinBtrfs driver - wraps the PowerShell uninstall script
- **Features:**
  - Checks for administrator privileges
  - Executes `uninstall-winbtrfs.ps1` automatically
  - Supports `-Force` and `-KeepDriverStore` options
  - Shows success/error messages via GUI dialogs
- **Requirements:** PowerShell must be available on target system
- **Status:** Ready to use on Windows systems

### ✅ mkbtrfs.exe (150 KB)
- **Location:** `/home/travis/git/btrfs-uninstall/mkbtrfs.exe`
- **Type:** PE32+ executable for MS Windows (console application)
- **Architecture:** x86-64
- **MD5:** cc48187be0fbe4381d0399a92337ea90
- **Purpose:** Command-line utility to create/format Btrfs filesystems on Windows
- **Status:** Ready to use on Windows systems

## Build Failures

### ❌ btrfs.sys (Kernel Driver)
**Reason:** Requires Windows Driver Development Kit (DDK) headers that are not available in MinGW
- Missing: `ntifs.h` and other kernel-mode headers
- **Solution:** Must be built using official Windows DDK/WDK with Visual Studio or EWDK

### ❌ shellbtrfs.dll (Shell Extension)
**Reason:** Header conflicts with modern MinGW-w64 15.2.1
- Conflict: `DUPLICATE_EXTENTS_DATA` structure already defined in `winioctl.h`
- Missing: `mountmgr.h` header file
- **Solution:** Requires older MinGW version or code updates to use system definitions

### ❌ ubtrfs.dll (Userspace Library)
**Reason:** Missing Windows-specific headers
- Missing: `ata.h` (ATA/ATAPI storage interface header)
- **Solution:** Requires Windows SDK headers

### ❌ test.exe (Test Suite)
**Reason:** Header conflicts with modern MinGW-w64
- Conflicts: `FILE_CASE_SENSITIVE_INFORMATION`, `FILE_STAT_INFORMATION` structures
- **Solution:** Disabled with `-DWITH_TEST=OFF` flag

## Build Environment

### Installed Tools
- CMake 3.31.11
- MinGW-w64 GCC 15.2.1
  - x86_64-w64-mingw32-gcc (64-bit target)
  - i686-w64-mingw32-gcc (32-bit target)
- MinGW-w64 G++ 15.2.1
- MinGW-w64 binutils 2.45.1

### Dependencies Built
- **zlib** (static library) - Compression library
- **zstd** (static library) - Zstandard compression library

## Usage Instructions

### btrfs-uninstall.exe (Uninstaller)
Transfer both `btrfs-uninstall.exe` and `uninstall-winbtrfs.ps1` to the same directory on Windows, then:

1. Right-click `btrfs-uninstall.exe` and select "Run as Administrator"
2. Follow the prompts to uninstall WinBtrfs
3. Reboot your system after completion

**Command-line options:**
```cmd
btrfs-uninstall.exe [-Force] [-KeepDriverStore] [-Help]
```

- `-Force` - Force removal of driver packages
- `-KeepDriverStore` - Skip driver package deletion
- `-Help` - Show help message

**Requirements:**
- Windows Vista or later
- Administrator privileges (enforced by the tool)
- PowerShell must be installed
- `uninstall-winbtrfs.ps1` must be in the same directory

### mkbtrfs.exe (Filesystem Creator)
Transfer `mkbtrfs.exe` to a Windows system to create Btrfs filesystems:

```cmd
mkbtrfs.exe [options] <device>
```

**Note:** This executable requires:
- Windows Vista or later (PE target: Windows 5.02+)
- Administrator privileges to format drives
- Target disk/partition to format

## Building on Windows (Recommended)

For complete build including the kernel driver and all components, use:
- **Visual Studio 2019/2022** with Windows Driver Kit (WDK)
- **Enterprise WDK (EWDK)** for command-line builds
- Follow the official WinBtrfs build instructions in README.md

The driver must be properly signed for use on modern Windows systems with Driver Signature Enforcement enabled.

## Notes

1. Cross-compilation from Linux using MinGW is only suitable for userspace utilities
2. The kernel driver (`btrfs.sys`) requires proper Windows development tools
3. For testing/development, official pre-built releases are available at: https://github.com/maharmstone/btrfs/releases
4. Building on Linux is useful for testing compilation but not recommended for production use

## Build Command Summary

```bash
# Install MinGW cross-compiler
sudo dnf install -y mingw64-gcc mingw64-gcc-c++ cmake

# Initialize submodules
git submodule update --init --recursive

# Configure and build
mkdir build && cd build
cmake -DCMAKE_TOOLCHAIN_FILE=../mingw-amd64.cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -DWITH_TEST=OFF \
      ..
cmake --build . -j$(nproc)
```
