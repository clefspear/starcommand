#!/usr/bin/env pwsh
# PowerShell rocket renderer for parity testing
# Usage: pwsh -File _render_pwsh.ps1 <h1> <h2> <h3> <h4> <h5> <h6>

. "$PSScriptRoot/../../powershell/starcommand.ps1"

function Normalize-Hex {
    param([object]$Value)
    $s = "$Value"
    if ($s -match '^[0-9]+$' -and $s.Length -lt 6) {
        $s = $s.PadLeft(6, '0')
    }
    return $s
}

$global:_rkt_tip = Normalize-Hex $args[0]
$global:_rkt_win = Normalize-Hex $args[1]
$global:_rkt_bdy = Normalize-Hex $args[2]
$global:_rkt_top = Normalize-Hex $args[3]
$global:_rkt_sds = Normalize-Hex $args[4]
$global:_rkt_flm = Normalize-Hex $args[5]
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
