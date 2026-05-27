#!/usr/bin/env pwsh
# Created By: Peter Azmy
# Install starcommand.ps1 into PowerShell profile via remote download.
# Works on Windows PowerShell 5.1 and PowerShell 7+ (Windows / macOS / Linux).

$ErrorActionPreference = 'Stop'

$repo    = 'clefspear/starcommand'
$branch  = 'main'
$rawBase = "https://raw.githubusercontent.com/$repo/$branch/powershell"

# 1. Detect platform. Windows PowerShell 5.1 doesn't define $IsWindows,
#    so treat a null value as Windows.
$isWindowsHost = if ($null -eq $IsWindows) { $true } else { [bool]$IsWindows }

# 2. Pick a stable install location for starcommand.ps1.
#    Anchor it to the same directory as the user's PowerShell profile so it
#    naturally lives next to .config/powershell on macOS/Linux and
#    Documents\PowerShell (or WindowsPowerShell on 5.1) on Windows.
$profileBaseDir = Split-Path -Parent $PROFILE.CurrentUserAllHosts
$installDir     = Join-Path $profileBaseDir (Join-Path 'Scripts' 'starcommand')

if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}
$starcommandPath = Join-Path $installDir 'starcommand.ps1'

# 3. Download starcommand.ps1 and VERSION
Invoke-WebRequest -UseBasicParsing -Uri "$rawBase/starcommand.ps1" -OutFile $starcommandPath
$versionUrl = "https://raw.githubusercontent.com/$repo/$branch/docs/VERSION"
Invoke-WebRequest -UseBasicParsing -Uri $versionUrl -OutFile (Join-Path $installDir 'VERSION')

# 4. Ensure execution policy allows scripts. Execution policy is a Windows-only
#    concept; PS7 on macOS/Linux ignores it, so skip there to avoid a noisy
#    "operation not supported on this platform" message on some builds.
if ($isWindowsHost) {
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($currentPolicy -in 'Restricted', 'Undefined') {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    }
}

# 5. Make sure the profile exists, then write a fenced starcommand block.
#    Fence markers make the block idempotent: re-running this installer
#    replaces the old block instead of appending duplicates.
$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir  = Split-Path -Parent $profilePath
if (-not (Test-Path $profileDir))  { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
if (-not (Test-Path $profilePath)) { New-Item -ItemType File      -Path $profilePath -Force | Out-Null }

$beginMarker = '# >>> starcommand >>>'
$endMarker   = '# <<< starcommand <<<'
$profileBlock = @"
$beginMarker
. "$starcommandPath"
Invoke-Starcommand
$endMarker
"@

$existing = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
if (-not $existing) { $existing = '' }

# Strip any prior starcommand block (fenced or legacy bare dot-source)
$fencedPattern = "(?s)\r?\n?$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))\r?\n?"
$cleaned = [regex]::Replace($existing, $fencedPattern, '')
$legacyLine = ". `"$starcommandPath`""
$cleaned = ($cleaned -split "`r?`n" | Where-Object { $_.Trim() -ne $legacyLine.Trim() }) -join "`r`n"
$cleaned = $cleaned.TrimEnd()

$separator = if ($cleaned) { "`r`n`r`n" } else { '' }
Set-Content -Path $profilePath -Value ($cleaned + $separator + $profileBlock + "`r`n")

# 6. Load it into the current session too, so the user doesn't have to restart
. $starcommandPath
Invoke-Starcommand

Write-Host ""
Write-Host "Type 'star help' for commands." -ForegroundColor Green
