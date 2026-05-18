#!/usr/bin/env pwsh
# Install starcommand.ps1 into PowerShell profile
# Usage: pwsh -File install.ps1 [-ProfilePath <path>] [-WhatIf]

param(
    [string]$ProfilePath,
    [switch]$WhatIf
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ProfilePath) { $ProfilePath = $PROFILE }

$starcommandPath = Join-Path $scriptDir "starcommand.ps1"
if (-not (Test-Path $starcommandPath)) {
    Write-Error "starcommand.ps1 not found at: $starcommandPath"
    exit 1
}

$profileDir = Split-Path -Parent $ProfilePath
if (-not (Test-Path $profileDir)) {
    if ($WhatIf) {
        Write-Host "Would create directory: $profileDir"
    } else {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
}

$dotSourceLine = ". '$starcommandPath'"

if (Test-Path $ProfilePath) {
    $profileContent = Get-Content $ProfilePath -Raw
    if ($profileContent -match [regex]::Escape($dotSourceLine)) {
        Write-Host "starcommand.ps1 already installed in $ProfilePath" -ForegroundColor Yellow
        . $starcommandPath
        exit 0
    }
    $profileContent = $profileContent.TrimEnd() + "`r`n`r`n"
} else {
    $profileContent = ""
}

$profileContent += "# starcommand - cross-shell rocket greeting`r`n"
$profileContent += $dotSourceLine + "`r`n"

if ($WhatIf) {
    Write-Host "Would write to $ProfilePath :"
    Write-Host $profileContent
} else {
    $profileContent | Out-File $ProfilePath -Encoding utf8
    . $starcommandPath
    Write-Host "starcommand.ps1 installed to $ProfilePath" -ForegroundColor Green
    Write-Host "Run 'Invoke-Starcommand' to display your rocket greeting." -ForegroundColor Cyan
}