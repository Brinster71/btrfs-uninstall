/*
 * WinBtrfs Uninstaller (Standalone)
 * Embeds the PowerShell uninstall script directly in the executable
 */

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

// Embedded PowerShell script
static const char* EMBEDDED_SCRIPT = 
#include "embedded-script.h"
;

static BOOL IsElevated(void) {
    BOOL elevated = FALSE;
    HANDLE token = NULL;
    
    if (OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) {
        TOKEN_ELEVATION elevation;
        DWORD size = sizeof(TOKEN_ELEVATION);
        
        if (GetTokenInformation(token, TokenElevation, &elevation, sizeof(elevation), &size)) {
            elevated = elevation.TokenIsElevated;
        }
        CloseHandle(token);
    }
    
    return elevated;
}

static void ShowError(const WCHAR* message) {
    MessageBoxW(NULL, message, L"WinBtrfs Uninstaller Error", MB_OK | MB_ICONERROR);
}

static void ShowUsage(void) {
    const WCHAR* usage = 
        L"WinBtrfs Uninstaller\n\n"
        L"This tool uninstalls the WinBtrfs driver from your system.\n\n"
        L"Usage:\n"
        L"  btrfs-uninstall.exe [options]\n\n"
        L"Options:\n"
        L"  -Force              Force removal of driver packages\n"
        L"  -KeepDriverStore    Skip driver package deletion\n"
        L"  -Help               Show this help message\n\n"
        L"Note: Administrator privileges are required.\n"
        L"A system reboot is recommended after uninstallation.";
    
    MessageBoxW(NULL, usage, L"WinBtrfs Uninstaller", MB_OK | MB_ICONINFORMATION);
}

int wmain(int argc, WCHAR* argv[]) {
    WCHAR tempPath[MAX_PATH];
    WCHAR scriptPath[MAX_PATH];
    WCHAR cmdLine[4096];
    BOOL force = FALSE;
    BOOL keepDriverStore = FALSE;
    BOOL showHelp = FALSE;
    FILE* fp;
    int i;
    
    // Check for help flag
    for (i = 1; i < argc; i++) {
        if (_wcsicmp(argv[i], L"-help") == 0 || _wcsicmp(argv[i], L"--help") == 0 ||
            _wcsicmp(argv[i], L"-?") == 0 || _wcsicmp(argv[i], L"/?") == 0) {
            showHelp = TRUE;
            break;
        }
        if (_wcsicmp(argv[i], L"-force") == 0) {
            force = TRUE;
        }
        if (_wcsicmp(argv[i], L"-keepdriverstore") == 0) {
            keepDriverStore = TRUE;
        }
    }
    
    if (showHelp) {
        ShowUsage();
        return 0;
    }
    
    // Check if running as administrator
    if (!IsElevated()) {
        ShowError(L"Administrator privileges required.\n\n"
                  L"Please run this program as Administrator.");
        return 1;
    }
    
    // Get temp path
    if (GetTempPathW(MAX_PATH, tempPath) == 0) {
        ShowError(L"Failed to get temp path.");
        return 1;
    }
    
    // Create temp script file path
    _snwprintf(scriptPath, MAX_PATH, L"%s\\winbtrfs-uninstall-%d.ps1", tempPath, GetCurrentProcessId());
    
    // Write embedded script to temp file
    fp = _wfopen(scriptPath, L"wb");
    if (!fp) {
        ShowError(L"Failed to create temporary PowerShell script.");
        return 1;
    }
    
    fwrite(EMBEDDED_SCRIPT, 1, strlen(EMBEDDED_SCRIPT), fp);
    fclose(fp);
    
    // Build PowerShell command line
    _snwprintf(cmdLine, 4096, 
               L"powershell.exe -ExecutionPolicy Bypass -NoProfile -File \"%s\"%s%s",
               scriptPath,
               force ? L" -Force" : L"",
               keepDriverStore ? L" -KeepDriverStore" : L"");
    
    // Execute PowerShell script
    STARTUPINFOW si = {0};
    PROCESS_INFORMATION pi = {0};
    si.cb = sizeof(si);
    
    wprintf(L"Starting WinBtrfs uninstaller...\n");
    wprintf(L"Command: %s\n\n", cmdLine);
    
    if (!CreateProcessW(NULL, cmdLine, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) {
        DeleteFileW(scriptPath);
        ShowError(L"Failed to start PowerShell.\n\n"
                  L"Ensure PowerShell is installed and accessible.");
        return 1;
    }
    
    // Wait for the process to complete
    WaitForSingleObject(pi.hProcess, INFINITE);
    
    DWORD exitCode = 0;
    GetExitCodeProcess(pi.hProcess, &exitCode);
    
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    
    // Clean up temp script file
    DeleteFileW(scriptPath);
    
    if (exitCode == 0) {
        MessageBoxW(NULL,
                    L"WinBtrfs uninstallation completed.\n\n"
                    L"A system reboot is strongly recommended.",
                    L"Uninstall Complete",
                    MB_OK | MB_ICONINFORMATION);
    } else {
        WCHAR errorMsg[256];
        _snwprintf(errorMsg, 256, 
                   L"Uninstallation script exited with code: %lu\n\n"
                   L"Check the console output for details.",
                   exitCode);
        ShowError(errorMsg);
    }
    
    return exitCode;
}
