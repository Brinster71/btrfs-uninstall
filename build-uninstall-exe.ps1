<#
.SYNOPSIS
    Builds a single-file WinBtrfs uninstaller executable.

.DESCRIPTION
    Embeds uninstall-winbtrfs.ps1 plus the WinBtrfs INF files into a small
    console executable. When the executable runs, it extracts those embedded
    files to a temporary directory and invokes Windows PowerShell with the
    embedded script. Arguments passed to the executable are forwarded to the
    script, so switches such as -Force, -KeepDriverStore, -WhatIf, and
    -Confirm still work.

.PARAMETER OutputPath
    Path for the generated executable. Defaults to .\uninstall-winbtrfs.exe.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File .\build-uninstall-exe.ps1

.EXAMPLE
    .\uninstall-winbtrfs.exe -Force
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = (Join-Path $PSScriptRoot 'uninstall-winbtrfs.exe')
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Convert-FileToBase64 {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required file not found: $Path"
    }

    return [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path).Path))
}

$scriptPath = Join-Path $PSScriptRoot 'uninstall-winbtrfs.ps1'
$btrfsInfPath = Join-Path $PSScriptRoot 'src\btrfs.inf'
$btrfsVolInfPath = Join-Path $PSScriptRoot 'src\btrfs-vol.inf'

$scriptBase64 = Convert-FileToBase64 -Path $scriptPath
$btrfsInfBase64 = Convert-FileToBase64 -Path $btrfsInfPath
$btrfsVolInfBase64 = Convert-FileToBase64 -Path $btrfsVolInfPath

$source = @"
using System;
using System.Diagnostics;
using System.IO;
using System.Text;

namespace WinBtrfsUninstaller
{
    internal static class Program
    {
        private const string ScriptBase64 = "$scriptBase64";
        private const string BtrfsInfBase64 = "$btrfsInfBase64";
        private const string BtrfsVolInfBase64 = "$btrfsVolInfBase64";

        private static int Main(string[] args)
        {
            string tempRoot = Path.Combine(Path.GetTempPath(), "winbtrfs-uninstall-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(tempRoot);

            try
            {
                string scriptPath = Path.Combine(tempRoot, "uninstall-winbtrfs.ps1");
                string infDir = Path.Combine(tempRoot, "src");
                Directory.CreateDirectory(infDir);

                WriteBase64File(scriptPath, ScriptBase64);
                WriteBase64File(Path.Combine(infDir, "btrfs.inf"), BtrfsInfBase64);
                WriteBase64File(Path.Combine(infDir, "btrfs-vol.inf"), BtrfsVolInfBase64);

                string powershell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),
                    @"WindowsPowerShell\v1.0\powershell.exe");
                if (!File.Exists(powershell))
                {
                    powershell = "powershell.exe";
                }

                string arguments = "-NoProfile -ExecutionPolicy Bypass -File " + Quote(scriptPath) +
                    " -InfPath " + Quote(Path.Combine(infDir, "btrfs.inf"));
                foreach (string arg in args)
                {
                    arguments += " " + Quote(arg);
                }

                using (Process process = new Process())
                {
                    process.StartInfo.FileName = powershell;
                    process.StartInfo.Arguments = arguments;
                    process.StartInfo.UseShellExecute = false;
                    process.Start();
                    process.WaitForExit();
                    return process.ExitCode;
                }
            }
            finally
            {
                try
                {
                    Directory.Delete(tempRoot, true);
                }
                catch
                {
                    // The uninstaller may schedule files for deletion or keep handles open briefly.
                    // Leaving this temporary directory behind is safer than masking the uninstall result.
                }
            }
        }

        private static void WriteBase64File(string path, string base64)
        {
            File.WriteAllBytes(path, Convert.FromBase64String(base64));
        }

        private static string Quote(string value)
        {
            if (String.IsNullOrEmpty(value))
            {
                return "\"\"";
            }

            StringBuilder builder = new StringBuilder();
            builder.Append('"');
            int backslashes = 0;

            foreach (char c in value)
            {
                if (c == '\\')
                {
                    backslashes++;
                }
                else if (c == '"')
                {
                    builder.Append('\\', backslashes * 2 + 1);
                    builder.Append('"');
                    backslashes = 0;
                }
                else
                {
                    builder.Append('\\', backslashes);
                    backslashes = 0;
                    builder.Append(c);
                }
            }

            builder.Append('\\', backslashes * 2);
            builder.Append('"');
            return builder.ToString();
        }
    }
}
"@

$outputFullPath = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
$outputDirectory = Split-Path -Parent $outputFullPath
if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

Add-Type -TypeDefinition $source -Language CSharp -OutputAssembly $outputFullPath -OutputType ConsoleApplication
Write-Host "Built $outputFullPath"
