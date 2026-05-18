#!/usr/bin/env pwsh
# PowerShell seed-based rocket renderer for parity testing
# Usage: pwsh -File _render_seed.ps1 <seed>

param([uint32]$Seed)

. "$PSScriptRoot/../../powershell/starcommand.ps1"

$script:_RKT_PRNG_STATE = $Seed
$colors = Invoke-GenRocketPalette

$global:_rkt_tip = $colors[0]
$global:_rkt_win = $colors[1]
$global:_rkt_bdy = $colors[2]
$global:_rkt_top = $colors[3]
$global:_rkt_sds = $colors[4]
$global:_rkt_flm = $colors[5]
$global:_rkt_star_mode = 'white'
$global:_rkt_terminal_theme = 'dark'
$global:_rocket_stars = Invoke-ComputeStarPositions

# Row 0 (blank)
Invoke-RenderRow 0 (' ' * 18) (' ' * 18)
[Console]::WriteLine()

for ($i = 0; $i -lt $global:RocketArt.Count; $i++) {
    Invoke-RenderRow ($i + 1) $global:RocketArt[$i].art $global:RocketArt[$i].role
    [Console]::WriteLine()
}

Invoke-RenderFlame
[Console]::WriteLine()

# Row 11 (blank)
Invoke-RenderRow 11 (' ' * 18) (' ' * 18)
[Console]::WriteLine()
