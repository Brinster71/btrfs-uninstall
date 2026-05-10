<#
.SYNOPSIS
    Uninstalls WinBtrfs from Windows.

.DESCRIPTION
    Removes WinBtrfs devices, driver packages, service registration, shell
    extension registry entries, and installed binaries. Run from an elevated
    PowerShell session. A reboot is strongly recommended after this script
    completes, especially if btrfs.sys or shellbtrfs.dll were loaded.

.PARAMETER InfPath
    Optional path to btrfs.inf. If omitted, the script looks beside the script
    and in the repository's src directory.

.PARAMETER Force
    Forces removal of matching driver packages when pnputil supports it.

.PARAMETER KeepDriverStore
    Skips pnputil driver package deletion and only disables/removes the live
    service, registry entries, and copied binaries.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\uninstall-winbtrfs.ps1 -Force
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter()]
    [string]$InfPath,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$KeepDriverStore
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Step {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Description,
        [int[]]$AllowedExitCodes = @(0)
    )

    $commandLine = "$FilePath $($Arguments -join ' ')"
    if (-not $PSCmdlet.ShouldProcess($Description, $commandLine)) {
        return @()
    }

    Write-Host "+ $commandLine"
    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($output) {
        $output | ForEach-Object { Write-Host $_ }
    }

    if ($AllowedExitCodes -notcontains $exitCode) {
        Write-Warning "$Description exited with code $exitCode. Continuing because WinBtrfs may already be partially removed."
    }

    return $output
}

function Resolve-WinBtrfsInfPath {
    param([string]$RequestedPath)

    $candidates = @()
    if ($RequestedPath) {
        $candidates += $RequestedPath
    }
    if ($PSScriptRoot) {
        $candidates += (Join-Path $PSScriptRoot 'btrfs.inf')
        $candidates += (Join-Path $PSScriptRoot 'src\btrfs.inf')
    }
    $candidates += (Join-Path (Get-Location) 'btrfs.inf')
    $candidates += (Join-Path (Get-Location) 'src\btrfs.inf')

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $null
}

function New-DriverPackageRecord {
    return @{
        PublishedName = ''
        OriginalName = ''
        ProviderName = ''
        ClassName = ''
        DriverVersion = ''
        SignerName = ''
    }
}

function Get-PnpUtilDriverPackages {
    $output = Invoke-External -FilePath 'pnputil.exe' -Arguments @('/enum-drivers') -Description 'Enumerate driver packages' -AllowedExitCodes @(0)
    $packages = @()
    $current = New-DriverPackageRecord

    foreach ($line in $output) {
        $text = [string]$line
        if ([string]::IsNullOrWhiteSpace($text)) {
            if ($current.Count -gt 0) {
                $packages += [pscustomobject]$current
                $current = New-DriverPackageRecord
            }
            continue
        }

        if ($text -match '^\s*([^:]+):\s*(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            switch -Regex ($name) {
                '^Published Name$' { $current['PublishedName'] = $value; break }
                '^Original Name$' { $current['OriginalName'] = $value; break }
                '^Provider Name$' { $current['ProviderName'] = $value; break }
                '^Class Name$' { $current['ClassName'] = $value; break }
                '^Driver Version$' { $current['DriverVersion'] = $value; break }
                '^Signer Name$' { $current['SignerName'] = $value; break }
            }
        }
    }

    if ($current.Count -gt 0) {
        $packages += [pscustomobject]$current
    }

    return $packages | Where-Object {
        ($_.OriginalName -in @('btrfs.inf', 'btrfs-vol.inf')) -or
        (($_.ProviderName -eq 'Mark Harmstone') -and ($_.PublishedName -like 'oem*.inf') -and ($_.ClassName -eq 'Volume'))
    }
}

function Remove-RegistryPathIfPresent {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        if ($PSCmdlet.ShouldProcess($Path, 'Remove registry key')) {
            Remove-Item -LiteralPath $Path -Recurse -Force
            Write-Host "Removed registry key $Path"
        }
    }
}

function Add-PendingDeleteSupport {
    if ('WinBtrfsUninstall.NativeMethods' -as [type]) {
        return
    }

    $source = @'
using System;
using System.Runtime.InteropServices;

namespace WinBtrfsUninstall {
    public static class NativeMethods {
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, int dwFlags);
    }
}
'@
    Add-Type -TypeDefinition $source
}

function Remove-FileOrScheduleDelete {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }

    if (-not $PSCmdlet.ShouldProcess($Path, 'Remove installed file')) {
        return
    }

    try {
        Remove-Item -LiteralPath $Path -Force
        Write-Host "Removed $Path"
    }
    catch {
        Add-PendingDeleteSupport
        $moveFileDelayUntilReboot = 0x4
        $scheduled = [WinBtrfsUninstall.NativeMethods]::MoveFileEx($Path, $null, $moveFileDelayUntilReboot)
        if ($scheduled) {
            Write-Warning "$Path is in use and has been scheduled for deletion on reboot."
        }
        else {
            $lastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            Write-Warning "Could not remove or schedule deletion for $Path. Win32 error: $lastError"
        }
    }
}

$isWindowsHost = $true
if (Test-Path -LiteralPath 'Variable:IsWindows') {
    $isWindowsHost = $IsWindows
}
if (-not $isWindowsHost) {
    throw 'This script must be run on Windows.'
}

if (-not (Test-Administrator)) {
    throw 'Run this script from an elevated PowerShell session (Run as Administrator).'
}

Write-Warning 'Unmount or disconnect Btrfs volumes before continuing. A reboot is recommended when the script finishes.'

$resolvedInfPath = Resolve-WinBtrfsInfPath -RequestedPath $InfPath
if ($resolvedInfPath) {
    Write-Step "Running INF uninstall using $resolvedInfPath"
    Invoke-External -FilePath 'rundll32.exe' -Arguments @('setupapi.dll,InstallHinfSection', 'DefaultUninstall', '132', $resolvedInfPath) -Description 'Run btrfs.inf DefaultUninstall' -AllowedExitCodes @(0) | Out-Null
}
else {
    Write-Warning 'btrfs.inf was not found. Continuing with service, registry, driver-store, and file cleanup.'
}

Write-Step 'Removing WinBtrfs root devices when present'
$devices = @()
if (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue) {
    $devices = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {
        ($_.InstanceId -like 'ROOT\BTRFS\*') -or
        ($_.InstanceId -like 'BtrfsVolume*') -or
        ($_.FriendlyName -in @('Btrfs controller', 'Btrfs volume'))
    }
}
foreach ($device in $devices) {
    Invoke-External -FilePath 'pnputil.exe' -Arguments @('/remove-device', $device.InstanceId) -Description "Remove PnP device $($device.InstanceId)" -AllowedExitCodes @(0, 259) | Out-Null
}

Write-Step 'Disabling and deleting the btrfs service'
Invoke-External -FilePath 'sc.exe' -Arguments @('stop', 'btrfs') -Description 'Stop btrfs service' -AllowedExitCodes @(0, 1060, 1062, 1052) | Out-Null
Invoke-External -FilePath 'sc.exe' -Arguments @('config', 'btrfs', 'start=', 'disabled') -Description 'Disable btrfs service' -AllowedExitCodes @(0, 1060) | Out-Null
Invoke-External -FilePath 'sc.exe' -Arguments @('delete', 'btrfs') -Description 'Delete btrfs service' -AllowedExitCodes @(0, 1060, 1072) | Out-Null

if (-not $KeepDriverStore) {
    Write-Step 'Deleting WinBtrfs driver packages from the driver store'
    $packages = Get-PnpUtilDriverPackages
    foreach ($package in $packages) {
        $arguments = @('/delete-driver', $package.PublishedName, '/uninstall')
        if ($Force) {
            $arguments += '/force'
        }
        Invoke-External -FilePath 'pnputil.exe' -Arguments $arguments -Description "Delete driver package $($package.PublishedName)" -AllowedExitCodes @(0, 2, 3, 5) | Out-Null
    }
}

Write-Step 'Removing WinBtrfs shell extension registry entries'
$registryPaths = @(
    'Registry::HKEY_CLASSES_ROOT\*\ShellEx\PropertySheetHandlers\WinBtrfs',
    'Registry::HKEY_CLASSES_ROOT\Directory\Background\ShellEx\ContextMenuHandlers\WinBtrfs',
    'Registry::HKEY_CLASSES_ROOT\Drive\ShellEx\PropertySheetHandlers\WinBtrfs',
    'Registry::HKEY_CLASSES_ROOT\Folder\ShellEx\ContextMenuHandlers\WinBtrfs',
    'Registry::HKEY_CLASSES_ROOT\Folder\ShellEx\PropertySheetHandlers\WinBtrfs',
    'Registry::HKEY_CLASSES_ROOT\CLSID\{2690B74F-F353-422D-BB12-401581EEF8F0}',
    'Registry::HKEY_CLASSES_ROOT\CLSID\{2690B74F-F353-422D-BB12-401581EEF8F1}',
    'Registry::HKEY_CLASSES_ROOT\CLSID\{2690B74F-F353-422D-BB12-401581EEF8F2}',
    'Registry::HKEY_CLASSES_ROOT\CLSID\{2690B74F-F353-422D-BB12-401581EEF8F3}',
    'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\btrfs'
)
foreach ($path in $registryPaths) {
    Remove-RegistryPathIfPresent -Path $path
}

Write-Step 'Removing installed WinBtrfs binaries'
$systemRoot = $env:SystemRoot
$installedFiles = @(
    (Join-Path $systemRoot 'System32\drivers\btrfs.sys'),
    (Join-Path $systemRoot 'System32\shellbtrfs.dll'),
    (Join-Path $systemRoot 'System32\ubtrfs.dll'),
    (Join-Path $systemRoot 'System32\mkbtrfs.exe')
)
foreach ($file in $installedFiles) {
    Remove-FileOrScheduleDelete -Path $file
}

Write-Step 'WinBtrfs uninstall cleanup complete'
Write-Host 'Reboot Windows now to unload any remaining driver or shell-extension references.' -ForegroundColor Yellow
