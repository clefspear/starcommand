# starcommand.ps1 — Portable rocket greeting for PowerShell
# Implements xorshift32 PRNG for cross-shell deterministic output
# Works in PowerShell 5.1+ and PowerShell 7+

# ── Portable PRNG ──────────────────────────────────────────────────────────────

function Invoke-XorShift32 {
    <#
    .SYNOPSIS
        Advance xorshift32 state, return next 32-bit output
    .PARAMETER State
        Current PRNG state (uint32)
    #>
    param([uint32]$State)
    $U32 = [uint64]4294967295  # 0xFFFFFFFF
    $s = [uint64]$State
    $s = ($s -bxor ($s -shl 13)) -band $U32
    $s = ($s -bxor ($s -shr 17)) -band $U32
    $s = ($s -bxor ($s -shl 5)) -band $U32
    return [uint32]$s
}

function Invoke-Djb2 {
    <#
    .SYNOPSIS
        DJB2 hash of a string, returns 32-bit unsigned
    #>
    param([string]$InputString)
    $U32 = [uint64]4294967295  # 0xFFFFFFFF
    $h = [uint64]5381
    foreach ($c in $InputString.ToCharArray()) {
        $b = [uint64][byte][char]$c
        $h = (($h -shl 5) + $h + $b) -band $U32
    }
    $h32 = [uint32]$h
    if ($h32 -eq 0) { $h32 = 1 }
    return $h32
}

function Get-RocketSeed {
    <#
    .SYNOPSIS
        Compute session seed from hostname + date via DJB2
    #>
    $hostname = & hostname 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $hostname) { $hostname = "localhost" }
    $hostname = $hostname.Split('.')[0]  # short name
    $dateStr = Get-Date -Format "yyyy.MM.dd"
    $seedStr = "$hostname.$dateStr"
    return (Invoke-Djb2 $seedStr), $seedStr
}

function Get-RandomInt {
    <#
    .SYNOPSIS
        Return random integer in [min, max] from PRNG state
    .PARAMETER State
        Current PRNG state (will be advanced)
    .PARAMETER Min
        Minimum value (inclusive)
    .PARAMETER Max
        Maximum value (inclusive)
    .OUTPUTS
        Hashtable with State (uint32) and Value (int)
    #>
    param([uint32]$State, [int]$Min, [int]$Max)
    $next = Invoke-XorShift32 $State
    $range = $Max - $Min + 1
    $val = $Min + ([int]($next % $range))
    return @{ State = $next; Value = $val }
}

# ── Color utilities ────────────────────────────────────────────────────────────

$global:Esc = [char]27

function Set-RocketColor {
    <#
    .SYNOPSIS
        Output ANSI 24-bit color escape for a 6-digit hex color, or reset
        Uses [Console]::Write for stdout capture in all PowerShell versions.
    #>
    param([string]$Hex)
    if ($Hex -eq 'normal' -or $Hex -eq 'reset') {
        [Console]::Write("$global:Esc[m")
        return
    }
    # Handle named colors (mapped from fish/zsh)
    $named = @{
        'grey'   = '808080'
        'cyan'   = '00FFFF'
        'yellow' = 'FFFF00'
        '0F0'    = '00FF00'
        'FFF'    = 'FFFFFF'
    }
    if ($named.ContainsKey($Hex)) {
        $Hex = $named[$Hex]
    }
    # Expand 3-char hex
    if ($Hex.Length -eq 3) {
        $Hex = "$($Hex[0])$($Hex[0])$($Hex[1])$($Hex[1])$($Hex[2])$($Hex[2])"
    }
    $r = [int][Convert]::ToByte($Hex.Substring(0, 2), 16)
    $g = [int][Convert]::ToByte($Hex.Substring(2, 2), 16)
    $b = [int][Convert]::ToByte($Hex.Substring(4, 2), 16)
    [Console]::Write("$global:Esc[38;2;$r;$g;$b"+"m")
}

function Convert-HslToHex {
    <#
    .SYNOPSIS
        HSL (H=0-360, S=0-100, L=0-100) to 6-digit hex string
    #>
    param([double]$H, [double]$S, [double]$L)
    $sat = $S / 100.0
    $light = $L / 100.0
    $c = (1.0 - [Math]::Abs(2.0 * $light - 1.0)) * $sat
    $hp = $H / 60.0
    $x = $c * (1.0 - [Math]::Abs(($hp - 2.0 * [Math]::Floor($hp / 2.0)) - 1.0))
    $m = $light - $c / 2.0
    $hi = [int][Math]::Floor($H)
    $r = 0.0; $g = 0.0; $b = 0.0
    if ($hi -lt 60) {
        $r = $c; $g = $x; $b = 0.0
    } elseif ($hi -lt 120) {
        $r = $x; $g = $c; $b = 0.0
    } elseif ($hi -lt 180) {
        $r = 0.0; $g = $c; $b = $x
    } elseif ($hi -lt 240) {
        $r = 0.0; $g = $x; $b = $c
    } elseif ($hi -lt 300) {
        $r = $x; $g = 0.0; $b = $c
    } else {
        $r = $c; $g = 0.0; $b = $x
    }
    $ri = [int][Math]::Round(($r + $m) * 255.0)
    $gi = [int][Math]::Round(($g + $m) * 255.0)
    $bi = [int][Math]::Round(($b + $m) * 255.0)
    return "{0:x2}{1:x2}{2:x2}" -f $ri, $gi, $bi
}

# ── Globals (set on each greeting) ─────────────────────────────────────────────
# Use global scope so _render_pwsh.ps1 and starcommand.ps1 share the same vars
$global:_rkt_tip = ""
$global:_rkt_win = ""
$global:_rkt_bdy = ""
$global:_rkt_top = ""
$global:_rkt_sds = ""
$global:_rkt_flm = ""
$global:_rocket_stars = @()
$global:_rkt_star_mode = "white"
$global:_rkt_favorite_star_mode = "gold"
$global:_rkt_random_star_mode = "white"
$global:_rkt_terminal_theme = "dark"
$global:_rkt_favorite_weight = 20

# ── Rocket rendering ──────────────────────────────────────────────────────────

$global:RocketArt = @(
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

$global:FlamePatterns = @(
    '\| ||', '|| |/', '\| |/', '|| ||', '*| |*', '~| ||', '|| |~', '\| /|'
)

function Invoke-RenderRow {
    param([int]$LineNum, [string]$Art, [string]$Role)
    for ($col = 0; $col -lt 18; $col++) {
        $char = $Art[$col]
        $key = "$LineNum`:$col"
        if ($char -ne ' ') {
            $r = $Role[$col]
            switch ($r) {
                'p' { Set-RocketColor $global:_rkt_tip }
                'w' { Set-RocketColor $global:_rkt_win }
                'b' { Set-RocketColor $global:_rkt_bdy }
                't' { Set-RocketColor $global:_rkt_top }
                's' { Set-RocketColor $global:_rkt_sds }
                'f' { Set-RocketColor $global:_rkt_flm }
            }
            [Console]::Write($char)
            Set-RocketColor normal
        } elseif ($global:_rocket_stars -contains $key) {
            Set-RocketColor (Get-StarColorForMode)
            [Console]::Write('*')
            Set-RocketColor normal
        } else {
            [Console]::Write(' ')
        }
    }
}

function Invoke-RenderFlame {
    $allBytes = Invoke-PaletteBytes
    $idx = $allBytes[0] % $global:FlamePatterns.Count
    $pattern = $global:FlamePatterns[$idx]
    [Console]::Write('      ')
    Set-RocketColor $global:_rkt_flm
    [Console]::Write($pattern)
    Set-RocketColor normal
}

function Get-StarColorForMode {
    switch ($global:_rkt_star_mode) {
        'gold' {
            if ($global:_rkt_terminal_theme -eq 'light') { return 'B8860B' }
            else { return 'FFE600' }
        }
        'neon' {
            if ($global:_rkt_terminal_theme -eq 'light') { return Get-NeonColorLight }
            else { return Get-NeonColor }
        }
        default {
            if ($global:_rkt_terminal_theme -eq 'light') { return '333333' }
            else { return 'FFFFFF' }
        }
    }
}

# ── Palette generation ─────────────────────────────────────────────────────────

function Invoke-GenRocketPalette {
    param([uint32]$State)
    $result = Get-RandomInt $State 0 359
    $h_base = $result.Value; $state = $result.State
    $result = Get-RandomInt $state 0 4
    $scheme = $result.Value; $state = $result.State
    $result = Get-RandomInt $state 65 90
    $sat = $result.Value; $state = $result.State
    $result = Get-RandomInt $state 55 72
    $light = $result.Value; $state = $result.State

    $offs = switch ($scheme) {
        0 { @(0, 60, 120, 180, 240, 300) }
        1 { @(0, 50, 110, 180, 230, 290) }
        2 { @(0, 70, 130, 200, 250, 310) }
        3 { @(0, 45, 115, 180, 235, 295) }
        default { @(0, 65, 125, 190, 245, 310) }
    }
    $colors = @()
    foreach ($off in $offs) {
        $h = ($h_base + $off) % 360
        $colors += Convert-HslToHex $h $sat $light
    }
    return @{ State = $state; Colors = $colors }
}

function Invoke-PaletteBytes {
    $bytes = @()
    foreach ($color in @($global:_rkt_tip, $global:_rkt_win, $global:_rkt_bdy,
                         $global:_rkt_top, $global:_rkt_sds, $global:_rkt_flm)) {
        for ($i = 0; $i -lt 6; $i += 2) {
            $hex = $color.Substring($i, 2)
            $bytes += [byte][Convert]::ToByte($hex, 16)
        }
    }
    return $bytes
}

function Invoke-ComputeStarPositions {
    if (-not $global:_RKT_STAR_CANDIDATES) {
        $global:_RKT_STAR_CANDIDATES = @(
            '0:0','0:1','0:2','0:3','0:4','0:5','0:6','0:7','0:8','0:9','0:10','0:11','0:12','0:13','0:14','0:15','0:16','0:17'
            '1:0','1:1','1:2','1:3','1:4','1:5','1:6','1:7','1:9','1:10','1:11','1:12','1:13','1:14','1:15','1:16','1:17'
            '2:0','2:1','2:2','2:3','2:4','2:5','2:6','2:10','2:11','2:12','2:13','2:14','2:15','2:16','2:17'
            '3:0','3:1','3:2','3:3','3:4','3:5','3:11','3:12','3:13','3:14','3:15','3:16','3:17'
            '4:0','4:1','4:2','4:3','4:4','4:12','4:13','4:14','4:15','4:16','4:17'
            '5:0','5:1','5:2','5:3','5:4','5:12','5:13','5:14','5:15','5:16','5:17'
            '6:0','6:1','6:2','6:3','6:4','6:6','6:7','6:8','6:9','6:10','6:12','6:13','6:14','6:15','6:16','6:17'
            '7:0','7:1','7:2','7:6','7:7','7:9','7:10','7:14','7:15','7:16','7:17'
            '8:0','8:1','8:3','8:4','8:6','8:7','8:9','8:10','8:12','8:13','8:15','8:16','8:17'
            '9:0','9:1','9:15','9:16','9:17'
            '11:0','11:1','11:2','11:3','11:4','11:5','11:6','11:7','11:8','11:9','11:10','11:11','11:12','11:13','11:14','11:15','11:16','11:17'
        )
    }
    $total = $global:_RKT_STAR_CANDIDATES.Count
    $allBytes = Invoke-PaletteBytes
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($b in $allBytes) {
        $i1 = $b % $total
        $i2 = ($b + 73) % $total
        foreach ($idx in @($i1, $i2)) {
            $pos = $global:_RKT_STAR_CANDIDATES[$idx]
            $null = $seen.Add($pos)
        }
    }
    return [string[]]@($seen | Sort-Object)
}

# ── Neon colors ────────────────────────────────────────────────────────────────

$global:NeonColors = @(
    'FF0033','FF3300','FF6600','FF9900','FFBB00','FFDD00','FFFF00',
    'CCFF00','99FF00','66FF00','33FF00','00FF33','00FF66','00FF99',
    '00FFCC','00FFFF','00CCFF','0099FF','0066FF','0033FF','3300FF',
    '6600FF','9900FF','CC00FF','FF00FF','FF00CC','FF0099','FF0066'
)

$global:NeonColorsLight = @(
    'CC0029','CC2900','CC5200','CC7A00','CC9500','B8860B','AAAA00',
    '88AA00','668800','448800','228822','228B22','008844','008866',
    '008B7F','008B8B','0077AA','1E6FB8','0055CC','0033AA','2200AA',
    '4B0082','6622AA','7B1FA2','A020A0','AA0088','AD1457','AA0044'
)

function Get-NeonColor {
    return $global:NeonColors[(Get-Random -Minimum 0 -Maximum $global:NeonColors.Count)]
}

function Get-NeonColorLight {
    return $global:NeonColorsLight[(Get-Random -Minimum 0 -Maximum $global:NeonColorsLight.Count)]
}

# ── History / Favorites (stub — system-dependent, not needed for parity) ────

function Invoke-RocketPickPalette {
    param([uint32]$State)
    $result = Invoke-GenRocketPalette $State
    return $result
}

# ── System info (stub for parity testing) ──────────────────────────────────────
# Full version with actual system calls in the greeting below

# ── Main greeting ──────────────────────────────────────────────────────────────

function Invoke-Starcommand {
    param(
        [uint32]$OverrideSeed = 0,
        [string[]]$OverridePalette = @()
    )

    # Seed
    if ($OverrideSeed -ne 0) {
        $seed = $OverrideSeed
        $seedStr = "override"
    } else {
        $seedInfo = Get-RocketSeed
        $seed = $seedInfo[0]
        $seedStr = $seedInfo[1]
    }

    $state = $seed

    # Palette
    if ($OverridePalette.Count -eq 6) {
        $colors = $OverridePalette
    } else {
        $result = Invoke-RocketPickPalette $state
        $colors = $result.Colors
        $state = $result.State
    }

    $global:_rkt_tip = $colors[0]
    $global:_rkt_win = $colors[1]
    $global:_rkt_bdy = $colors[2]
    $global:_rkt_top = $colors[3]
    $global:_rkt_sds = $colors[4]
    $global:_rkt_flm = $colors[5]
    $global:_rocket_stars = Invoke-ComputeStarPositions

    # Render the rocket (simplified for testing, no system info)
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
}

# Export functions for testing
$exported = @(
    'Invoke-XorShift32', 'Invoke-Djb2', 'Get-RocketSeed', 'Get-RandomInt',
    'Set-RocketColor', 'Convert-HslToHex', 'Invoke-RenderRow', 'Invoke-RenderFlame',
    'Invoke-PaletteBytes', 'Invoke-ComputeStarPositions', 'Invoke-GenRocketPalette',
    'Invoke-Starcommand', 'Get-StarColorForMode'
)

# If the script is dot-sourced, just define functions (no auto-run)
# If run directly, execute once
if ($MyInvocation.InvocationName -eq '.') {
    # Dot-sourced — functions are now available
} else {
    Invoke-Starcommand
}
