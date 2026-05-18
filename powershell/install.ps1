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

# 4. Make sure the profile exists, then add a dot-source line if it isn't there
$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir  = Split-Path -Parent $profilePath
if (-not (Test-Path $profileDir))  { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
if (-not (Test-Path $profilePath)) { New-Item -ItemType File      -Path $profilePath -Force | Out-Null }

$dotSourceLine = ". `"$starcommandPath`""
$existing = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
if ($existing -notmatch [regex]::Escape($dotSourceLine)) {
    Add-Content -Path $profilePath -Value "`r`n$dotSourceLine"
}

# 5. Load it into the current session too, so the user doesn't have to restart
. $starcommandPath
Invoke-Starcommand

Write-Host "starcommand installed to $starcommandPath" -ForegroundColor Green
Write-Host "Run 'Invoke-Starcommand' to display your rocket greeting." -ForegroundColor Green
