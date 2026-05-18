#!/usr/bin/env pwsh
# PRNG parity test for PowerShell starcommand port
# Verifies xorshift32 matches prng_reference.txt exactly

# Import the PRNG module
. "$PSScriptRoot/../../powershell/starcommand.ps1"

$refFile = "$PSScriptRoot/../prng_reference.txt"
$ref = Get-Content $refFile

$allPassed = $true

# Parse seeds from reference file
$currentSeed = 0
$expected = @()
$lineNum = 0

function Test-Seed {
    param($seedName, $seedVal, $expectedVals)
    Write-Host "Testing $seedName..."
    $state = [uint32]$seedVal
    for ($i = 0; $i -lt 20; $i++) {
        $state = Invoke-XorShift32 $state
        if ([uint32]$state -ne [uint32]$expectedVals[$i]) {
            Write-Host "  FAIL at #$($i+1): got $([uint32]$state), expected $([uint32]$expectedVals[$i])" -ForegroundColor Red
            return $false
        }
    }
    Write-Host "  PASS" -ForegroundColor Green
    return $true
}

# Parse reference file manually for robustness
$lines = Get-Content $refFile
$i = 0
while ($i -lt $lines.Count) {
    $line = $lines[$i]
    if ($line -match '^seed=(\d+)$') {
        $seedName = $line
        $seedVal = [uint32]("$($Matches[1])")
        $i++
        $vals = @()
        for ($j = 0; $j -lt 20; $j++) {
            if ($i -lt $lines.Count -and $lines[$i] -match '^\s+\d+:\s+(\d+)$') {
                $vals += [uint32]("$($Matches[1])")
                $i++
            }
        }
        if (-not (Test-Seed $seedName $seedVal $vals)) {
            $allPassed = $false
        }
    } else {
        $i++
    }
}

# Also test DJB2
Write-Host "Testing DJB2 hash..."
$djbResult = Invoke-Djb2 "myhost.2026.05.18"
if ($djbResult -eq 125233131) {
    Write-Host "  PASS (got $djbResult)" -ForegroundColor Green
} else {
    Write-Host "  FAIL: got $djbResult, expected 125233131" -ForegroundColor Red
    $allPassed = $false
}

if ($allPassed) {
    Write-Host "`nAll PRNG parity tests PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nSome tests FAILED" -ForegroundColor Red
    exit 1
}
