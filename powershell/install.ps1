#!/usr/bin/env pwsh
# Install starcommand.ps1 into PowerShell profile via remote download

$ErrorActionPreference = 'Stop'

$repo    = 'clefspear/starcommand'
$branch  = 'main'
$rawBase = "https://raw.githubusercontent.com/$repo/$branch/powershell"

# 1. Pick a stable install location for starcommand.ps1
$installDir = Join-Path $env:USERPROFILE 'Documents\WindowsPowerShell\Scripts\starcommand'
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}
$starcommandPath = Join-Path $installDir 'starcommand.ps1'

# 2. Download starcommand.ps1 to that location
Invoke-WebRequest -UseBasicParsing -Uri "$rawBase/starcommand.ps1" -OutFile $starcommandPath

# 3. Ensure execution policy allows running scripts
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -in 'Restricted', 'Undefined') {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
}

# 4. Make sure the profile exists, then write a fenced starcommand block.
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

# 5. Load it into the current session too, so the user doesn't have to restart
. $starcommandPath
Invoke-Starcommand

Write-Host ""
Write-Host "Type 'star help' for commands." -ForegroundColor Green
