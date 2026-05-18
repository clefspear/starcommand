#!/usr/bin/env pwsh
# PowerShell seed-based rocket renderer for parity testing
# Usage: pwsh -File _render_seed.ps1 <seed>

param([uint32]$Seed)

. "$PSScriptRoot/../../powershell/starcommand.ps1"

$result = Invoke-GenRocketPalette $Seed
$state = $result.State
$colors = $result.Colors

$global:_rkt_tip = $colors[0]
$global:_rkt_win = $colors[1]
$global:_rkt_bdy = $colors[2]
$global:_rkt_top = $colors[3]
$global:_rkt_sds = $colors[4]
$global:_rkt_flm = $colors[5]
$global:_rkt_star_mode = "white"
$global:_rkt_terminal_theme = "dark"
$global:_rocket_stars = Invoke-ComputeStarPositions

$RocketArt = @(
    @{ art = "        |         "; role = "        b         " }
    @{ art = "       / \        "; role = "       t t        " }
    @{ art = "      / _ \       "; role = "      t t t       " }
    @{ art = "     |.o '.|      "; role = "     swp wws      " }
    @{ art = "     |'._.'|      "; role = "     swwwwws      " }
    @{ art = "     |     |      "; role = "     b     b      " }
    @{ art = "   ,'|  |  |``.    "; role = "   ssb  b  bss    " }
    @{ art = "  /  |  |  |  \   "; role = "  s  b  b  b  s   " }
    @{ art = "  |,-'--|--'-.|   "; role = "  bsssttbttsssb   " }
)

# Row 0 (blank)
Invoke-RenderRow 0 (' ' * 18) (' ' * 18)
[Console]::WriteLine()

for ($i = 0; $i -lt $RocketArt.Count; $i++) {
    Invoke-RenderRow ($i + 1) $RocketArt[$i].art $RocketArt[$i].role
    [Console]::WriteLine()
}

Invoke-RenderFlame
[Console]::WriteLine()

# Row 11 (blank)
Invoke-RenderRow 11 (' ' * 18) (' ' * 18)
[Console]::WriteLine()
