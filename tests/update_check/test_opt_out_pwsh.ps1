#!/usr/bin/env pwsh
$scriptDir = Split-Path -Parent $PSScriptRoot
$repoDir = Split-Path -Parent $scriptDir

$cacheDir = Join-Path $HOME '.config/powershell'
$null = New-Item -ItemType Directory -Path $cacheDir -Force -ErrorAction SilentlyContinue
'0', '9.9.9' | Out-File (Join-Path $cacheDir 'rocket_update_check') -Encoding ascii

$pass = $true

# Test 1: nudge appears without env var
$env:STARCOMMAND_NO_UPDATE_CHECK = $null
$output = & pwsh -NoProfile -Command ". (Join-Path '$repoDir' 'powershell/starcommand.ps1'); Invoke-Starcommand" 2>&1
if ($output -match 'v9.9.9 available') {
    Write-Host 'Test 1 PASS: nudge appears without env var'
} else {
    Write-Host 'Test 1 FAIL: nudge missing'
    $pass = $false
}

# Test 2: nudge suppressed with env var
$env:STARCOMMAND_NO_UPDATE_CHECK = '1'
$output = & pwsh -NoProfile -Command ". (Join-Path '$repoDir' 'powershell/starcommand.ps1'); Invoke-Starcommand" 2>&1
if ($output -match 'v9.9.9 available') {
    Write-Host 'Test 2 FAIL: nudge present despite opt-out'
    $pass = $false
} else {
    Write-Host 'Test 2 PASS: nudge suppressed with env var'
}

Remove-Item (Join-Path $cacheDir 'rocket_update_check') -Force -ErrorAction SilentlyContinue

if (-not $pass) { exit 1 }
Write-Host 'All tests passed'
