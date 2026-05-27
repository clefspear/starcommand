# Created By: Peter Azmy
# starcommand.ps1 — Portable rocket greeting for PowerShell
# Implements xorshift32 PRNG for cross-shell deterministic output
# Works in PowerShell 5.1+ and PowerShell 7+

$script:RktVersion = if (Test-Path (Join-Path $PSScriptRoot 'docs/VERSION')) { (Get-Content (Join-Path $PSScriptRoot 'docs/VERSION') -Raw).Trim() } else { '0.0.0' }
$script:RktUpdateCache = Join-Path $HOME '.config/powershell/rocket_update_check'

function Invoke-UpdateCheckBackground {
    if ($env:STARCOMMAND_NO_UPDATE_CHECK) { return }
    if ($global:_RKT_AUTO_UPDATE_CHECK -ne 'yes') { return }

    $cacheDir = Split-Path $script:RktUpdateCache -Parent
    New-Item -ItemType Directory -Path $cacheDir -Force -ErrorAction SilentlyContinue | Out-Null

    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if (Test-Path $script:RktUpdateCache) {
        $lastCheck = [long](Get-Content $script:RktUpdateCache -TotalCount 1 -ErrorAction SilentlyContinue)
        $age = $now - $lastCheck
        if ($age -lt 604800) { return }
    }

    if (Test-Path $script:RktUpdateCache) {
        $cachedV = Get-Content $script:RktUpdateCache -Tail 1 -ErrorAction SilentlyContinue
        if ($cachedV -eq $script:RktVersion) {
            Remove-Item $script:RktUpdateCache -Force -ErrorAction SilentlyContinue
            return
        }
    }

    Invoke-LoadSettings
    $branch = 'main'
    if ($global:_rkt_channel -eq 'cantaloupe') { $branch = 'cantaloupe' }
    $url = "https://raw.githubusercontent.com/clefspear/starcommand/$branch/docs/VERSION"
    $null = Start-Job -ScriptBlock {
        param($url, $cacheFile, $now)
        try {
            if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
                $v = & curl.exe -fsSL --ssl-no-revoke --max-time 3 $url 2>$null
            } else {
                $v = (Invoke-WebRequest -Uri $url -TimeoutSec 3 -UseBasicParsing).Content.Trim()
            }
            "$now`n$v" | Out-File $cacheFile -Encoding ascii -Force
        } catch {}
    } -ArgumentList $url, $script:RktUpdateCache, $now
}

function Invoke-UpdateCheckNudge {
    if ($env:STARCOMMAND_NO_UPDATE_CHECK) { return }
    if (-not (Test-Path $script:RktUpdateCache)) { return }

    $lines = Get-Content $script:RktUpdateCache -ErrorAction SilentlyContinue
    if ($lines.Count -lt 2) { return }
    $cachedVersion = $lines[-1].Trim()
    if (-not $cachedVersion) { return }
    if ($cachedVersion -eq $script:RktVersion) { return }

    Set-RocketColor grey
    $changelogBranch = if ($global:_rkt_channel -eq 'cantaloupe') { 'cantaloupe' } else { 'main' }
    [Console]::WriteLine("(starcommand v$cachedVersion available — run 'star update' — https://github.com/clefspear/starcommand/blob/$changelogBranch/docs/CHANGELOG.md)")
    Set-RocketColor normal
}

# ── UTF-8 output encoding ──────────────────────────────────────────────────────────

# Ensure UTF-8 output so multi-byte chars (★, …, box-drawing) render correctly
# on Windows Terminal / Windows PowerShell, which default to legacy codepages.
if ([Console]::OutputEncoding.CodePage -ne 65001) {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
}
if ($OutputEncoding.CodePage -ne 65001) {
    $OutputEncoding = [System.Text.UTF8Encoding]::new()
}

# ── Portable PRNG ──────────────────────────────────────────────────────────────

$script:_RKT_PRNG_STATE = 0

function Invoke-XorShift32 {
    param([uint32]$State)
    $U32 = [uint64]4294967295
    $s = [uint64]$State
    $s = ($s -bxor ($s -shl 13)) -band $U32
    $s = ($s -bxor ($s -shr 17)) -band $U32
    $s = ($s -bxor ($s -shl 5)) -band $U32
    return [uint32]$s
}

function Set-PrngSeed {
    do {
        $script:_RKT_PRNG_STATE = [uint32](Get-Random -Maximum ([uint32]::MaxValue))
    } while ($script:_RKT_PRNG_STATE -eq 0)
}

function Get-PrngRange {
    param([int]$Min, [int]$Max)
    $script:_RKT_PRNG_STATE = Invoke-XorShift32 $script:_RKT_PRNG_STATE
    $range = $Max - $Min + 1
    return ($Min + ([int]($script:_RKT_PRNG_STATE % $range)))
}

function Get-RandomInt {
    param([uint32]$State, [int]$Min, [int]$Max)
    $next = Invoke-XorShift32 $State
    $range = $Max - $Min + 1
    $val = $Min + ([int]($next % $range))
    return @{ State = $next; Value = $val }
}

# ── Color utilities ────────────────────────────────────────────────────────────

$global:Esc = [char]27

function Set-RocketColor {
    param(
        [string]$Hex = '',
        [switch]$Bold,
        [switch]$Italics
    )
    if ($Hex -eq 'normal' -or $Hex -eq 'reset') {
        [Console]::Write("$global:Esc[m")
        return
    }
    $codes = @()
    if ($Bold) { $codes += '1' }
    if ($Italics) { $codes += '3' }
    if ($Hex -and $Hex.Length -ge 3) {
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
        if ($Hex.Length -eq 3) {
            $Hex = "$($Hex[0])$($Hex[0])$($Hex[1])$($Hex[1])$($Hex[2])$($Hex[2])"
        }
        if ($Hex.Length -ge 6) {
            $r = [int][Convert]::ToByte($Hex.Substring(0, 2), 16)
            $g = [int][Convert]::ToByte($Hex.Substring(2, 2), 16)
            $b = [int][Convert]::ToByte($Hex.Substring(4, 2), 16)
            $codes += "38;2;$r;$g;$b"
        }
    }
    if ($codes.Count -gt 0) {
        [Console]::Write("$global:Esc[$($codes -join ';')m")
    }
}

function Convert-HslToHex {
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
        $r = $c; $g = $x
    } elseif ($hi -lt 120) {
        $r = $x; $g = $c
    } elseif ($hi -lt 180) {
        $g = $c; $b = $x
    } elseif ($hi -lt 240) {
        $g = $x; $b = $c
    } elseif ($hi -lt 300) {
        $r = $x; $b = $c
    } else {
        $r = $c; $b = $x
    }
    $ri = [int][Math]::Round(($r + $m) * 255.0)
    $gi = [int][Math]::Round(($g + $m) * 255.0)
    $bi = [int][Math]::Round(($b + $m) * 255.0)
    return '{0:x2}{1:x2}{2:x2}' -f $ri, $gi, $bi
}

# ── Settings globals (persisted) ───────────────────────────────────────────────

$global:_rkt_random_star_mode = 'white'
$global:_rkt_favorite_star_mode = 'gold'
$global:_rkt_terminal_theme = 'dark'
$global:_rkt_favorite_weight = 20

# ── Globals (set on each greeting) ─────────────────────────────────────────────

$global:_rkt_tip = ''
$global:_rkt_win = ''
$global:_rkt_bdy = ''
$global:_rkt_top = ''
$global:_rkt_sds = ''
$global:_rkt_flm = ''
$global:_rocket_stars = @()
$global:_rkt_star_mode = 'white'
$global:_rkt_terminal_theme = 'dark'

# ── Rocket art ─────────────────────────────────────────────────────────────────

$global:RocketArt = @(
    @{ art = '        |         '; role = '        b         ' }
    @{ art = '       / \        '; role = '       t t        ' }
    @{ art = '      / _ \       '; role = '      t t t       ' }
    @{ art = '     |.o ''.|      '; role = '     swp wws      ' }
    @{ art = '     |''._.''|      '; role = '     swwwwws      ' }
    @{ art = '     |     |      '; role = '     b     b      ' }
    @{ art = '   ,''|  |  |`.    '; role = '   ssb  b  bss    ' }
    @{ art = '  /  |  |  |  \   '; role = '  s  b  b  b  s   ' }
    @{ art = '  |,-''--|--''-.|   '; role = '  bsssttbttsssb   ' }
)

$global:FlamePatterns = @(
    '\| ||', '|| |/', '\| |/', '|| ||', '*| |*', '~| ||', '|| |~', '\| /|'
)

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

# ── Star candidates ────────────────────────────────────────────────────────────

$script:_RKT_STAR_CANDIDATES = @(
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

# ── Star positions ─────────────────────────────────────────────────────────────

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
    $total = $script:_RKT_STAR_CANDIDATES.Count
    $allBytes = Invoke-PaletteBytes
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($b in $allBytes) {
        $i1 = $b % $total
        $i2 = ($b + 73) % $total
        foreach ($idx in @($i1, $i2)) {
            $pos = $script:_RKT_STAR_CANDIDATES[$idx]
            $null = $seen.Add($pos)
        }
    }
    return [string[]]@($seen | Sort-Object)
}

# ── Neon colors ────────────────────────────────────────────────────────────────

function Get-NeonColor {
    $idx = Get-PrngRange 0 ($global:NeonColors.Count - 1)
    return $global:NeonColors[$idx]
}

function Get-NeonColorLight {
    $idx = Get-PrngRange 0 ($global:NeonColorsLight.Count - 1)
    return $global:NeonColorsLight[$idx]
}

# ── Star color ─────────────────────────────────────────────────────────────────

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

# ── Rendering ──────────────────────────────────────────────────────────────────

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

# ── Palette generation ─────────────────────────────────────────────────────────

# DEPRECATED — HSL-based generator, kept as reference for color-theme previews.
function Invoke-GenRocketPaletteHsl {
    $h_base = Get-PrngRange 0 359
    $scheme = Get-PrngRange 0 4
    $sat = Get-PrngRange 65 90
    $light = Get-PrngRange 55 72

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
    return $colors
}

function Invoke-GenRocketPalette {
    return Invoke-GenRocketPalette24Bit
}

function Invoke-GenRocketPalette24Bit {
    $theme = if ($global:_rkt_terminal_theme) { $global:_rkt_terminal_theme } else { 'dark' }
    $colors = @()
    for ($i = 0; $i -lt 6; $i++) {
        do {
            $r = Get-PrngRange 0 255
            $g = Get-PrngRange 0 255
            $b = Get-PrngRange 0 255
            $brightness = [int]((299 * $r + 587 * $g + 114 * $b) / 1000)
        } while (($theme -eq 'light' -and $brightness -gt 200) -or ($theme -ne 'light' -and $brightness -lt 60))
        $colors += '{0:x2}{1:x2}{2:x2}' -f $r, $g, $b
    }
    return $colors
}

function Invoke-RecordHistory {
    $dir = Join-Path $HOME '.config/powershell'
    $file = Join-Path $dir 'rocket_history.txt'
    New-Item -ItemType Directory -Path $dir -Force -ErrorAction SilentlyContinue | Out-Null
    Add-Content -Path $file -Value ($args -join ' ')
    $lc = (Get-Content $file | Measure-Object).Count
    if ($lc -gt 100) {
        $lines = Get-Content $file
        $lines = $lines[-100..-1]
        Set-Content $file $lines
    }
}

function Invoke-RocketPickPalette {
    $favDir = Join-Path $HOME '.config/powershell'
    $fav_file = Join-Path $favDir 'rocket_favorites.txt'
    $colors = @()

    $roll = Get-PrngRange 1 100
    if ($roll -le $global:_rkt_favorite_weight -and (Test-Path $fav_file)) {
        $favs = Get-Content $fav_file
        if ($favs.Count -gt 0) {
            $randIdx = Get-PrngRange 0 ($favs.Count - 1)
            $colors = $favs[$randIdx] -split ' '
        }
    }

    if ($colors.Count -ne 6) {
        $colors = Invoke-GenRocketPalette
    }

    Invoke-RecordHistory @colors
    return $colors
}

# ── History / Favorites helpers ────────────────────────────────────────────────

function Test-PaletteIsFavorite {
    $favDir = Join-Path $HOME '.config/powershell'
    $fav_file = Join-Path $favDir 'rocket_favorites.txt'
    if (-not (Test-Path $fav_file)) { return $false }
    $palette = "$global:_rkt_tip $global:_rkt_win $global:_rkt_bdy $global:_rkt_top $global:_rkt_sds $global:_rkt_flm"
    $lines = Get-Content $fav_file
    return ($lines -contains $palette)
}

function Invoke-PrintStarRow {
    param([int]$N, [string]$Palette, [string]$Prefix = '')
    $cs = $Palette -split ' '
    if ($Prefix) {
        [Console]::Write($Prefix)
    } else {
        [Console]::Write("{0,4}. " -f $N)
    }
    Set-RocketColor $cs[0]; [Console]::Write('★ ')
    Set-RocketColor $cs[1]; [Console]::Write('★ ')
    Set-RocketColor $cs[2]; [Console]::Write('★ ')
    Set-RocketColor $cs[3]; [Console]::Write('★ ')
    Set-RocketColor $cs[4]; [Console]::Write('★ ')
    Set-RocketColor $cs[5]; [Console]::Write('★')
    Set-RocketColor normal
    [Console]::WriteLine("  $Palette")
}

function Test-ValidateHexes {
    $hexes = @()
    foreach ($raw in $args) {
        $cleaned = $raw -replace '^#', ''
        if ($cleaned -notmatch '^[0-9a-fA-F]{6}$') { return $null }
        $hexes += $cleaned
    }
    return $hexes
}

function Invoke-PreviewPalette {
    param([string]$H1, [string]$H2, [string]$H3, [string]$H4, [string]$H5, [string]$H6)
    $saved_tip = $global:_rkt_tip; $saved_win = $global:_rkt_win; $saved_bdy = $global:_rkt_bdy
    $saved_top = $global:_rkt_top; $saved_sds = $global:_rkt_sds; $saved_flm = $global:_rkt_flm
    $saved_stars = $global:_rocket_stars

    $global:_rkt_tip = $H1; $global:_rkt_win = $H2; $global:_rkt_bdy = $H3
    $global:_rkt_top = $H4; $global:_rkt_sds = $H5; $global:_rkt_flm = $H6
    $global:_rocket_stars = @()

    Invoke-RenderRow 1 '        |         ' '        b         '; [Console]::WriteLine()
    Invoke-RenderRow 2 '       / \        ' '       t t        '; [Console]::WriteLine()
    Invoke-RenderRow 3 '      / _ \       ' '      t t t       '; [Console]::WriteLine()
    Invoke-RenderRow 4 '     |.o ''.|      ' '     swp wws      '; [Console]::WriteLine()
    Invoke-RenderRow 5 '     |''._.''|      ' '     swwwwws      '; [Console]::WriteLine()
    Invoke-RenderRow 6 '     |     |      ' '     b     b      '; [Console]::WriteLine()
    Invoke-RenderRow 7 '   ,''|  |  |`.    ' '   ssb  b  bss    '; [Console]::WriteLine()
    Invoke-RenderRow 8 '  /  |  |  |  \   ' '  s  b  b  b  s   '; [Console]::WriteLine()
    Invoke-RenderRow 9 '  |,-''--|--''-.|   ' '  bsssttbttsssb   '; [Console]::WriteLine()
    Invoke-RenderFlame; [Console]::WriteLine()

    $global:_rkt_tip = $saved_tip; $global:_rkt_win = $saved_win; $global:_rkt_bdy = $saved_bdy
    $global:_rkt_top = $saved_top; $global:_rkt_sds = $saved_sds; $global:_rkt_flm = $saved_flm
    $global:_rocket_stars = $saved_stars
}

# ── Settings ───────────────────────────────────────────────────────────────────

function Invoke-LoadSettings {
    $cfg = Join-Path $HOME '.config/powershell/rocket_settings.ps1'
    $global:_rkt_random_star_mode = 'white'
    $global:_rkt_favorite_star_mode = 'gold'
    $global:_rkt_terminal_theme = 'dark'
    $global:_rkt_favorite_weight = 20
    $global:_rkt_channel = 'main'
    $global:_RKT_AUTO_UPDATE_CHECK = ''
    if (Test-Path $cfg) { . $cfg }
}

function Invoke-SaveSettings {
    $cfg = Join-Path $HOME '.config/powershell/rocket_settings.ps1'
    $dir = Split-Path $cfg -Parent
    New-Item -ItemType Directory -Path $dir -Force -ErrorAction SilentlyContinue | Out-Null
@"
`$global:_rkt_random_star_mode='$($global:_rkt_random_star_mode)'
`$global:_rkt_favorite_star_mode='$($global:_rkt_favorite_star_mode)'
`$global:_rkt_terminal_theme='$($global:_rkt_terminal_theme)'
`$global:_rkt_favorite_weight=$($global:_rkt_favorite_weight)
`$global:_rkt_channel='$($global:_rkt_channel)'
`$global:_RKT_AUTO_UPDATE_CHECK='$($global:_RKT_AUTO_UPDATE_CHECK)'
"@ | Set-Content $cfg
}

function Invoke-PrintOption {
    param([string]$Active)
    $opts = $args
    [Console]::Write('(')
    $first = $true
    foreach ($opt in $opts) {
        if (-not $first) { [Console]::Write(' | ') }
        $first = $false
        if ($opt -eq $Active) {
            Set-RocketColor -Bold -Italics
            [Console]::Write($opt)
            Set-RocketColor normal
        } else {
            [Console]::Write($opt)
        }
    }
    [Console]::Write(')')
}

# ── System info ────────────────────────────────────────────────────────────────

function Invoke-HwInfo {
    $cacheDir = Join-Path $HOME '.config/powershell'
    $cache = Join-Path $cacheDir 'rocket_hw_cache.ps1'
    New-Item -ItemType Directory -Path $cacheDir -Force -ErrorAction SilentlyContinue | Out-Null

    if ((Test-Path $cache) -and ((Get-Item $cache).LastWriteTime -gt (Get-Date).AddDays(-7))) {
        . $cache
        return
    }

    $os_type = [System.Environment]::OSVersion.Platform
    $os_str = "$([System.Environment]::OSVersion.VersionString)"

    $cpu_str = ''
    $mem_str = ''
    $bootTicks = 0

    if ($os_type -eq [System.PlatformID]::Win32NT) {
        try {
            $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
            if ($cs) {
                $cpu_str = "$($cs.NumberOfProcessors) processors, $($cs.NumberOfLogicalProcessors) logical"
                $mem_gb = [Math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
                $mem_str = "$mem_gb GB"
            }
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
            if ($os) { $bootTicks = $os.LastBootUpTime.Ticks }
        } catch {}
        if (-not $cpu_str) { $cpu_str = "$([System.Environment]::ProcessorCount) logical processors" }
    } else {
        try {
            $os_str = uname -sm
            $chip = uname -m
            $cpu_str = "$chip"
            if ($IsMacOS -or (uname -s) -eq 'Darwin') {
                $chip_name = sysctl -n machdep.cpu.brand_string 2>$null
                $cores = system_profiler SPHardwareDataType 2>$null | Select-String 'Total Number of Cores'
                if ($cores) {
                    $cores_n = ($cores.ToString() -split ':')[1].Trim()
                    $cpu_str = "$chip_name, $cores_n"
                }
                $mem_line = system_profiler SPHardwareDataType 2>$null | Select-String 'Memory:'
                if ($mem_line) {
                    $mem_str = ($mem_line.ToString() -split ':')[1].Trim()
                }
            } else {
                $cpuinfo = Get-Content /proc/cpuinfo -ErrorAction SilentlyContinue
                $procs = ($cpuinfo | Select-String 'processor\s+:' | Measure-Object).Count
                $cores = ($cpuinfo | Select-String 'cpu cores' | Select-Object -First 1).ToString()
                $cores_n = ($cores -split ':')[1].Trim()
                $model = ($cpuinfo | Select-String 'model name' | Select-Object -First 1).ToString()
                $model_n = ($model -split ':')[1].Trim()
                $cpu_str = "$procs processors, $cores_n cores, $model_n"
                $free = free -h 2>$null | Select-String 'Mem'
                if ($free) {
                    $mem_str = ($free.ToString() -split '\s+')[1]
                }
            }
        } catch {}
    }

@"
`$global:_rkt_os='$os_str'
`$global:_rkt_cpu='$cpu_str'
`$global:_rkt_mem='$mem_str'
`$global:_rkt_boot_tick=$bootTicks
"@ | Set-Content $cache
    . $cache
}

function Invoke-NetInfo {
    $cacheDir = Join-Path $HOME '.config/powershell'
    $cache = Join-Path $cacheDir 'rocket_net_cache.ps1'
    New-Item -ItemType Directory -Path $cacheDir -Force -ErrorAction SilentlyContinue | Out-Null

    if ((Test-Path $cache) -and ((Get-Item $cache).LastWriteTime -gt (Get-Date).AddDays(-7))) {
        . $cache
        return
    }

    $os_type = [System.Environment]::OSVersion.Platform
    $ip = ''
    $gw = ''

    if ($os_type -eq [System.PlatformID]::Win32NT -and (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue)) {
        try {
            $skipPattern = '^(lo|Loopback|docker|br-|veth|vmnet|vboxnet|utun|tun|tap|awdl|llw|anpi)'
            $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
            foreach ($adapter in $adapters) {
                if ($adapter.Name -match $skipPattern -or
                    $adapter.InterfaceDescription -match 'Loopback|Virtual|VMware|VirtualBox|Hyper-V|Docker') { continue }
                $addr = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                    Where-Object { $_.IPAddress -ne '127.0.0.1' } | Select-Object -First 1
                if ($addr) {
                    $ip = $addr.IPAddress
                    $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue |
                        Select-Object -First 1
                    if ($route) { $gw = $route.NextHop }
                    break
                }
            }
        } catch {}
    } else {
        try {
            if ($IsMacOS -or (uname -s) -eq 'Darwin') {
                $ip = ifconfig 2>$null | awk '
                    /^[a-zA-Z0-9]+:/ {
                        if (iface != "" && addr != "" && is_active == 1 && iface !~ /^(lo|lo0|docker|br-|veth|vmnet|vboxnet|utun|tun|tap|awdl|llw|anpi)/) { print addr; exit }
                        iface = $1; sub(/:$/, "", iface); addr = ""; is_active = 0
                    }
                    /inet / && !/127\.0\.0\.1/ { addr = $2 }
                    /status: active/ { is_active = 1 }
                    END { if (iface != "" && addr != "" && is_active == 1 && iface !~ /^(lo|lo0|docker|br-|veth|vmnet|vboxnet|utun|tun|tap|awdl|llw|anpi)/) print addr }
                '
                if ($ip) { $ip = $ip.Trim() }
                $gw = netstat -nr 2>$null | awk '/^default/ {print $2; exit}'
                if ($gw) { $gw = $gw.Trim() }
            } else {
                $ip = ip -o addr show 2>$null | awk '$3 == "inet" && $2 !~ /^(lo|docker|br-|veth|vmnet|vboxnet|utun|tun|tap|awdl|llw|anpi)/ && $4 !~ /^127\./ { split($4, a, "/"); print a[1]; exit }'
                if ($ip) { $ip = $ip.Trim() }
                $gw = ip route 2>$null | awk '/^default/ {print $3; exit}'
                if ($gw) { $gw = $gw.Trim() }
            }
        } catch {}
    }

@"
`$global:_rkt_ip='$ip'
`$global:_rkt_gw='$gw'
"@ | Set-Content $cache
    . $cache
}

# ── Star command ───────────────────────────────────────────────────────────────

function star {
    $favDir = Join-Path $HOME '.config/powershell'
    $fav_file = Join-Path $favDir 'rocket_favorites.txt'
    $hist_file = Join-Path $favDir 'rocket_history.txt'

    if ($args.Count -eq 0) {
        if (-not $global:_rkt_bdy) {
            [Console]::WriteLine('No active palette. Open a new tab first.')
            return
        }
        $palette = "$global:_rkt_tip $global:_rkt_win $global:_rkt_bdy $global:_rkt_top $global:_rkt_sds $global:_rkt_flm"
        if ((Test-Path $fav_file)) {
            $existing = Get-Content $fav_file
            if ($existing -contains $palette) {
                [Console]::WriteLine('Already in favorites.')
                return
            }
        }
        New-Item -ItemType Directory -Path $favDir -Force -ErrorAction SilentlyContinue | Out-Null
        Add-Content $fav_file $palette
        Set-RocketColor $global:_rkt_tip; [Console]::Write('★ ')
        Set-RocketColor $global:_rkt_win; [Console]::Write('★ ')
        Set-RocketColor $global:_rkt_bdy; [Console]::Write('★ ')
        Set-RocketColor $global:_rkt_top; [Console]::Write('★ ')
        Set-RocketColor $global:_rkt_sds; [Console]::Write('★ ')
        Set-RocketColor $global:_rkt_flm; [Console]::Write('★')
        Set-RocketColor normal
        $total = (Get-Content $fav_file | Measure-Object).Count
        [Console]::WriteLine("  saved! ($total total)")
        return
    }

    # Normalize aliases
    $cmd = $args[0]
    switch ($cmd) {
        'ls'   { $cmd = 'list' }
        'rm'   { $cmd = 'remove' }
        'hist' { $cmd = 'history' }
        'preview' { $cmd = 'show' }
        'browse'  { $cmd = 'explore' }
        'w'    { $cmd = 'weight' }
        'colors' { $cmd = 'color' }
        '-h'   { $cmd = 'help' }
        '--help' { $cmd = 'help' }
    }

    switch ($cmd) {
        'list' {
            if (-not (Test-Path $fav_file)) {
                [Console]::WriteLine("No favorites yet. Use 'star' to save the current palette.")
                return
            }
            $i = 1
            foreach ($line in (Get-Content $fav_file)) {
                Invoke-PrintStarRow $i $line
                $i++
            }
        }

        'remove' {
            if (-not (Test-Path $fav_file)) {
                [Console]::WriteLine('No favorites to remove.')
                return
            }
            $n = $args[1]
            if ($n -notmatch '^\d+$') {
                [Console]::WriteLine('Usage: star remove <number>')
                return
            }
            $lines = Get-Content $fav_file
            $total = $lines.Count
            $nVal = [int]$n
            if ($nVal -lt 1 -or $nVal -gt $total) {
                [Console]::WriteLine("Out of range. You have $total favorites.")
                return
            }
            $newLines = @()
            for ($idx = 0; $idx -lt $lines.Count; $idx++) {
                if ($idx -ne ($nVal - 1)) { $newLines += $lines[$idx] }
            }
            if ($newLines.Count -eq 0) {
                Remove-Item $fav_file
            } else {
                Set-Content $fav_file $newLines
            }
            [Console]::WriteLine("Removed #$n.")
        }

        'history' {
            if (-not (Test-Path $hist_file)) {
                [Console]::WriteLine('No history yet.')
                return
            }
            $lines = Get-Content $hist_file
            $total = $lines.Count

            if ($args[1] -eq 'clear') {
                Remove-Item $hist_file
                [Console]::WriteLine('History cleared.')
                return
            }

            if ($args.Count -ge 2) {
                if ($args[1] -notmatch '^\d+$') {
                    [Console]::WriteLine('Usage: star history [N | clear]')
                    return
                }
                $n = [int]$args[1]
                if ($n -lt 1 -or $n -gt $total) {
                    [Console]::WriteLine("Out of range. History has $total entries.")
                    return
                }
                $idx = $total - $n
                $palette = $lines[$idx]
                if ((Test-Path $fav_file)) {
                    $existing = Get-Content $fav_file
                    if ($existing -contains $palette) {
                        [Console]::WriteLine('Already in favorites.')
                        return
                    }
                }
                New-Item -ItemType Directory -Path $favDir -Force -ErrorAction SilentlyContinue | Out-Null
                Add-Content $fav_file $palette
                $cs = $palette -split ' '
                Set-RocketColor $cs[0]; [Console]::Write('★ ')
                Set-RocketColor $cs[1]; [Console]::Write('★ ')
                Set-RocketColor $cs[2]; [Console]::Write('★ ')
                Set-RocketColor $cs[3]; [Console]::Write('★ ')
                Set-RocketColor $cs[4]; [Console]::Write('★ ')
                Set-RocketColor $cs[5]; [Console]::Write('★')
                Set-RocketColor normal
                [Console]::WriteLine("  saved to favorites from history #$n!")
                return
            }

            $limit = 20
            $shown = 0
            for ($i = $total - 1; $i -ge 0; $i--) {
                if ($shown -ge $limit) { break }
                $displayN = $total - $i
                if ($displayN -eq 1) {
                    Invoke-PrintStarRow $displayN $lines[$i] '(Current) 1. '
                } else {
                    Invoke-PrintStarRow $displayN $lines[$i] ("       {0,4}. " -f $displayN)
                }
                $shown++
            }
            if ($total -gt $limit) {
                [Console]::WriteLine()
                [Console]::WriteLine("(showing last $limit of $total; full log at $hist_file)")
            }
        }

        'show' {
            if ($args.Count -lt 7) {
                [Console]::WriteLine('Usage: star show <h1> <h2> <h3> <h4> <h5> <h6>')
                [Console]::WriteLine('Renders a mini rocket preview with the given 6-color palette.')
                [Console]::WriteLine('Order: porthole, window, body, top, window-sides, flame.')
                return
            }
            $hexes = Test-ValidateHexes $args[1..6]
            if (-not $hexes) {
                [Console]::WriteLine('Invalid hex code. Each must be 6 hex digits (e.g., ff0066 or #ff0066).')
                return
            }
            [Console]::WriteLine()
            Set-RocketColor $hexes[0]; [Console]::Write('  ★ Porthole      '); Set-RocketColor normal; [Console]::WriteLine("  $($hexes[0])")
            Set-RocketColor $hexes[1]; [Console]::Write('  ★ Window        '); Set-RocketColor normal; [Console]::WriteLine("  $($hexes[1])")
            Set-RocketColor $hexes[2]; [Console]::Write('  ★ Body          '); Set-RocketColor normal; [Console]::WriteLine("  $($hexes[2])")
            Set-RocketColor $hexes[3]; [Console]::Write('  ★ Top           '); Set-RocketColor normal; [Console]::WriteLine("  $($hexes[3])")
            Set-RocketColor $hexes[4]; [Console]::Write('  ★ Window-sides  '); Set-RocketColor normal; [Console]::WriteLine("  $($hexes[4])")
            Set-RocketColor $hexes[5]; [Console]::Write('  ★ Flame         '); Set-RocketColor normal; [Console]::WriteLine("  $($hexes[5])")
            [Console]::WriteLine()
            Invoke-PreviewPalette $hexes[0] $hexes[1] $hexes[2] $hexes[3] $hexes[4] $hexes[5]
            [Console]::WriteLine()
            [Console]::WriteLine("  star add $($hexes -join ' ')")
            [Console]::WriteLine('  (^ run that to save to favorites)')
        }

        'add' {
            if ($args.Count -lt 7) {
                [Console]::WriteLine('Usage: star add <h1> <h2> <h3> <h4> <h5> <h6> [<h1>..<h6> ...]')
                [Console]::WriteLine('Order: porthole, window, body, top, window-sides, flame.')
                return
            }
            $hexCount = $args.Count - 1
            if ($hexCount % 6 -ne 0) {
                [Console]::WriteLine("star add: expected a multiple of 6 hex codes, got $hexCount")
                return
            }
            $paletteCount = $hexCount / 6
            $allHexes = Test-ValidateHexes $args[1..($args.Count - 1)]
            if (-not $allHexes) {
                [Console]::WriteLine('Invalid hex code. Each must be 6 hex digits (e.g., ff0066 or #ff0066).')
                return
            }
            New-Item -ItemType Directory -Path $favDir -Force -ErrorAction SilentlyContinue | Out-Null
            for ($j = 0; $j -lt $paletteCount; $j++) {
                $idx = $j * 6
                $palette = "$($allHexes[$idx]) $($allHexes[$idx+1]) $($allHexes[$idx+2]) $($allHexes[$idx+3]) $($allHexes[$idx+4]) $($allHexes[$idx+5])"
                Add-Content $fav_file $palette
            }
            $total = (Get-Content $fav_file | Measure-Object).Count
            $start = $total - $paletteCount + 1
            for ($j = 0; $j -lt $paletteCount; $j++) {
                $idx = $j * 6
                $palette = "$($allHexes[$idx]) $($allHexes[$idx+1]) $($allHexes[$idx+2]) $($allHexes[$idx+3]) $($allHexes[$idx+4]) $($allHexes[$idx+5])"
                Invoke-PrintStarRow 0 $palette "Added favorite #$($start + $j): "
            }
        }

        'explore' {
            $n = 5
            if ($args.Count -ge 2 -and $args[1] -match '^\d+$') {
                $n = [int]$args[1]
            }

            $hasRockets = $false
            $rktAlive = $false
            $rktCol = 0
            $rktDir = 1
            $rktFrame = 0
            $rktSubframe = 0
            $rktFlameIdx = 0
            $rktNextLaunch = 125
            if ($n -ge 250) {
                $hasRockets = $true
                Invoke-LoadSettings
            }
            $rktAnsi = 97
            if ($global:_rkt_terminal_theme -eq 'light') { $rktAnsi = 30 }
            if (-not $global:Esc) { $global:Esc = [char]27 }

            $rktSeen = [System.Collections.Generic.HashSet[string]]::new()

            [Console]::WriteLine()
            for ($i = 1; $i -le $n; $i++) {
                Set-PrngSeed
                if ($hasRockets -and $rktAlive -and $rktSubframe -eq 0) {
                    $rktFlameIdx = Get-PrngRange 0 1
                }
                $p = @()
                do {
                    $p = Invoke-GenRocketPalette
                    $rktPalStr = "$($p[0]) $($p[1]) $($p[2]) $($p[3]) $($p[4]) $($p[5])"
                } while (-not $rktSeen.Add($rktPalStr))
                [Console]::Write("{0,4}. " -f $i)
                if ($hasRockets -and $rktAlive) {
                    $rktRow = ''
                    if ($rktSubframe -eq 0) {
                        $rktRow = ' ^ '
                    } elseif ($rktSubframe -eq 1) {
                        $rktRow = '/_\'
                    } else {
                        if ($rktFlameIdx -eq 0) { $rktRow = ' v ' } else { $rktRow = ' * ' }
                    }
                    if (-not $rktRow) { $rktRow = '' }
                    if (-not $rktAnsi) { $rktAnsi = 97 }
                    for ($s = 0; $s -lt 6; $s++) {
                        if ($s -eq $rktCol) {
                            [Console]::Write("$global:Esc[0m$global:Esc[$($rktAnsi)m$rktRow$global:Esc[0m")
                        } else {
                            Set-RocketColor $p[$s]; [Console]::Write('★')
                            if ($s -lt 5) {
                                $skipSpace = ($s -eq $rktCol - 1) -or ($rktCol -eq 0 -and $s -eq 1)
                                if (-not $skipSpace) { [Console]::Write(' ') }
                            }
                        }
                    }
                } else {
                    Set-RocketColor $p[0]; [Console]::Write('★ ')
                    Set-RocketColor $p[1]; [Console]::Write('★ ')
                    Set-RocketColor $p[2]; [Console]::Write('★ ')
                    Set-RocketColor $p[3]; [Console]::Write('★ ')
                    Set-RocketColor $p[4]; [Console]::Write('★ ')
                    Set-RocketColor $p[5]; [Console]::Write('★')
                }
                Set-RocketColor normal
                [Console]::WriteLine("  $($p[0]) $($p[1]) $($p[2]) $($p[3]) $($p[4]) $($p[5])")
                $null = $true
                if ($hasRockets) {
                    if ($rktAlive) {
                        $rktSubframe++
                        if ($rktSubframe -ge 3) {
                            $rktSubframe = 0
                            $rktFrame++
                            if ($rktFrame -ge 24) {
                                $rktAlive = $false
                                $rktNextLaunch = $i + 200
                            } else {
                                $rktNc = $rktCol + $rktDir
                                if ($rktNc -lt 0 -or $rktNc -gt 4) {
                                    $rktDir = -$rktDir
                                    $rktNc = $rktCol + $rktDir
                                }
                                $rktCol = $rktNc
                            }
                        }
                    } elseif ($i -ge $rktNextLaunch -and $n - $i -ge 72) {
                        $rktAlive = $true
                        $rktCol = 3
                        $rktFrame = 0
                        $rktSubframe = 0
                        $rktFlameIdx = 0
                        $rktDir = Get-PrngRange 0 1
                        if ($rktDir -eq 0) { $rktDir = -1 }
                    }
                }
            }
            [Console]::WriteLine()
            [Console]::WriteLine('  star show <h1>..<h6>   preview a full rocket')
            [Console]::WriteLine('  star add  <h1>..<h6> [<h1>..<h6> ...]   save palette(s) to favorites')
        }

        'weight' {
            Invoke-LoadSettings
            if ($args.Count -eq 1) {
                [Console]::WriteLine("Favorite weight: $global:_rkt_favorite_weight%")
                [Console]::WriteLine()
                [Console]::WriteLine('  Roughly 20 out of every 100 new shells will roll')
                [Console]::WriteLine('  a saved favorite. The rest generate fresh palettes.')
                [Console]::WriteLine()
                [Console]::WriteLine('Usage: star weight <0-100>')
                [Console]::WriteLine('  0    = never use favorites (always fresh)')
                [Console]::WriteLine('  100  = always use favorites')
                return
            }
            $n = $args[1]
            if ($n -notmatch '^\d+$') {
                [Console]::WriteLine('Weight must be a number between 0 and 100.')
                return
            }
            $nVal = [int]$n
            if ($nVal -lt 0 -or $nVal -gt 100) {
                [Console]::WriteLine('Weight must be between 0 and 100.')
                return
            }
            $global:_rkt_favorite_weight = $nVal
            Invoke-SaveSettings
            [Console]::WriteLine("Set favorite weight to $n%.")
        }

        'color' {
            Invoke-LoadSettings
            if ($args.Count -eq 1) {
                if (-not $global:_rkt_bdy) {
                    [Console]::WriteLine('No active palette. Open a new tab first.')
                    return
                }
                [Console]::WriteLine()
                Set-RocketColor $global:_rkt_tip; [Console]::Write('  ★ Porthole      '); Set-RocketColor normal; [Console]::WriteLine("  $global:_rkt_tip")
                Set-RocketColor $global:_rkt_win; [Console]::Write('  ★ Window        '); Set-RocketColor normal; [Console]::WriteLine("  $global:_rkt_win")
                Set-RocketColor $global:_rkt_bdy; [Console]::Write('  ★ Body          '); Set-RocketColor normal; [Console]::WriteLine("  $global:_rkt_bdy")
                Set-RocketColor $global:_rkt_top; [Console]::Write('  ★ Top           '); Set-RocketColor normal; [Console]::WriteLine("  $global:_rkt_top")
                Set-RocketColor $global:_rkt_sds; [Console]::Write('  ★ Window-sides  '); Set-RocketColor normal; [Console]::WriteLine("  $global:_rkt_sds")
                Set-RocketColor $global:_rkt_flm; [Console]::Write('  ★ Flame         '); Set-RocketColor normal; [Console]::WriteLine("  $global:_rkt_flm")
                [Console]::WriteLine()
                Invoke-PreviewPalette $global:_rkt_tip $global:_rkt_win $global:_rkt_bdy $global:_rkt_top $global:_rkt_sds $global:_rkt_flm
                return
            }

            if ($args[1] -eq 'reset') {
                $global:_rkt_random_star_mode = 'white'
                $global:_rkt_favorite_star_mode = 'gold'
                $global:_rkt_terminal_theme = 'dark'
                Invoke-SaveSettings
                [Console]::WriteLine('Reset: theme=dark, random=white, favorite=gold')
                return
            }

            if ($args.Count -lt 3) {
                [Console]::WriteLine('Usage: star color <theme|random|favorite> <value>')
                return
            }

            $ctx = $args[1]; $val = $args[2]
            if ($ctx -eq 'favorites') { $ctx = 'favorite' }
            if ($ctx -eq 'fav') { $ctx = 'favorite' }
            switch ($ctx) {
                'theme' {
                    if ($val -ne 'dark' -and $val -ne 'light') {
                        [Console]::WriteLine("Theme must be 'dark' or 'light'.")
                        return
                    }
                    $global:_rkt_terminal_theme = $val
                    Invoke-SaveSettings
                    [Console]::WriteLine("Set terminal theme to $val.")
                }
                'random' {
                    if ($val -ne 'white' -and $val -ne 'gold' -and $val -ne 'neon') {
                        [Console]::WriteLine("Random mode must be 'white' or 'neon'.")
                        return
                    }
                    $global:_rkt_random_star_mode = $val
                    Invoke-SaveSettings
                    if ($val -eq 'gold') { [Console]::WriteLine("Set random-palette stars to $val. :)") }
                    else { [Console]::WriteLine("Set random-palette stars to $val.") }
                }
                'favorite' {
                    if ($val -ne 'white' -and $val -ne 'gold' -and $val -ne 'neon') {
                        [Console]::WriteLine("Favorite mode must be 'gold' or 'neon'.")
                        return
                    }
                    $global:_rkt_favorite_star_mode = $val
                    Invoke-SaveSettings
                    if ($val -eq 'white') { [Console]::WriteLine("Set favorite-palette stars to $val. :)") }
                    else { [Console]::WriteLine("Set favorite-palette stars to $val.") }
                }
                default {
                    [Console]::WriteLine("Context must be 'theme', 'random', or 'favorite'.")
                }
            }
        }

        'update' {
            if ($args.Count -ge 2 -and $args[1] -eq 'cantaloupe') {
                Invoke-LoadSettings
                $global:_rkt_channel = 'cantaloupe'
                Invoke-SaveSettings
                [Console]::WriteLine("Switched to cantaloupe channel. Use 'star update' to pull the latest cantaloupe build.")
                return
            }
            if ($args.Count -ge 2 -and $args[1] -eq 'stable') {
                Invoke-LoadSettings
                $global:_rkt_channel = 'main'
                Invoke-SaveSettings
                [Console]::WriteLine('Switched to the stable channel.')
                return
            }
            if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue) -and -not (Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue)) {
                [Console]::WriteLine('curl or Invoke-WebRequest is required for star update.')
                return
            }
            Invoke-LoadSettings
            $branch = 'main'
            if ($global:_rkt_channel -eq 'cantaloupe') { $branch = 'cantaloupe' }
            $remoteVersion = ''
            $versionUrl = "https://raw.githubusercontent.com/clefspear/starcommand/$branch/docs/VERSION"
            if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
                $remoteVersion = & curl.exe -fsSL --ssl-no-revoke --max-time 5 $versionUrl 2>$null
            } else {
                try { $remoteVersion = (Invoke-WebRequest -Uri $versionUrl -TimeoutSec 5 -UseBasicParsing).Content.Trim() } catch {}
            }
            if (-not $remoteVersion) {
                [Console]::WriteLine('Failed to check for updates. Visit https://github.com/clefspear/starcommand/releases')
                return
            }
            try {
                $remoteVer = [System.Version]::Parse($remoteVersion)
                $localVer = [System.Version]::Parse($script:RktVersion)
                $isNewer = $remoteVer -gt $localVer
            } catch {
                $isNewer = $remoteVersion -ne $script:RktVersion
            }
            if (-not $isNewer) {
                if ($remoteVersion -eq $script:RktVersion) {
                    [Console]::WriteLine("starcommand is already up to date (v$script:RktVersion).")
                } else {
                    [Console]::WriteLine("Remote version ($remoteVersion) is older than installed ($script:RktVersion).")
                }
                return
            }
            [Console]::WriteLine("starcommand v$remoteVersion is available. Update now? [y/n]")
            $response = [Console]::ReadLine()
            if ($response -ne 'y' -and $response -ne 'Y') {
                [Console]::WriteLine('Update cancelled.')
                return
            }
            $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Source }
            if (-not $scriptPath -or -not (Test-Path $scriptPath)) {
                [Console]::WriteLine('Cannot determine script path. Update manually.')
                return
            }
            $tempFile = [System.IO.Path]::GetTempFileName()
            $dlUrl = "https://raw.githubusercontent.com/clefspear/starcommand/$branch/powershell/starcommand.ps1"
            [Console]::WriteLine("Downloading: $dlUrl")
            $httpCode = ""
            try {
                if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
                    $result = & curl.exe -sS -L --ssl-no-revoke --max-time 10 -w '%{http_code}' -o $tempFile $dlUrl 2>$null
                    $curlExit = $LASTEXITCODE
                    $httpCode = $result
                } else {
                    $response = Invoke-WebRequest -Uri $dlUrl -TimeoutSec 10 -UseBasicParsing -OutFile $tempFile
                    $httpCode = $response.StatusCode
                    $curlExit = 0
                }
                [Console]::WriteLine("HTTP $httpCode, curl exit $curlExit")
                if ($httpCode -ne "200" -and $httpCode -ne 200) {
                    [Console]::WriteLine('Download failed. Update aborted.')
                    Remove-Item $tempFile -ErrorAction SilentlyContinue
                    return
                }
                $scriptDir = Split-Path $scriptPath -Parent
                $versionUrl = "https://raw.githubusercontent.com/clefspear/starcommand/$branch/docs/VERSION"
                $tempVersion = [System.IO.Path]::GetTempFileName()
                $versionOk = $false
                try {
                    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
                        $vh = & curl.exe -sS -L --ssl-no-revoke --max-time 10 -w '%{http_code}' -o $tempVersion $versionUrl 2>$null
                        if ($vh -eq '200') { $versionOk = $true }
                    } else {
                        $vr = Invoke-WebRequest -Uri $versionUrl -TimeoutSec 10 -UseBasicParsing -OutFile $tempVersion
                        if ($vr.StatusCode -eq 200) { $versionOk = $true }
                    }
                } catch {}
                if (-not $versionOk) {
                    [Console]::WriteLine('Failed to download VERSION file. Update aborted.')
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                    Remove-Item $tempVersion -Force -ErrorAction SilentlyContinue
                    return
                }
                Copy-Item $scriptPath "$scriptPath.bak" -Force
                Move-Item $tempFile $scriptPath -Force
                $docsDir = Join-Path $scriptDir 'docs'
                New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
                Move-Item $tempVersion (Join-Path $docsDir 'VERSION') -Force
                [Console]::WriteLine("Updated to v$remoteVersion. Open a new tab to take effect.")
                Remove-Item $script:RktUpdateCache -Force -ErrorAction SilentlyContinue
            } catch {
                [Console]::WriteLine('Download failed. Update aborted.')
                Remove-Item $tempFile -ErrorAction SilentlyContinue
            }
        }

        'help' {
            Invoke-LoadSettings
            if ($global:_rkt_channel -eq 'cantaloupe') {
                [Console]::WriteLine("starcommand v$script:RktVersion-cantaloupe")
            } else {
                [Console]::WriteLine("starcommand v$script:RktVersion")
            }
            [Console]::WriteLine()
            [Console]::WriteLine('star                          save current palette to favorites')
            [Console]::WriteLine('star list                     show all favorites')
            [Console]::WriteLine('star remove N                 delete favorite #N')
            [Console]::WriteLine()
            [Console]::WriteLine('star history                  show last 20 palettes (most recent first)')
            [Console]::WriteLine('star history N                save palette #N from history to favorites')
            [Console]::WriteLine('star history clear            wipe history')
            [Console]::WriteLine()
            [Console]::WriteLine('star show H1..H6              preview a custom palette (mini rocket)')
            [Console]::WriteLine('star add  H1..H6 [H1..H6 ...] add one or more palettes to favorites')
            [Console]::WriteLine('star explore [N]              browse N random palettes (default 5)')
            [Console]::WriteLine()
            [Console]::WriteLine('star color                    show current palette preview')
            [Console]::Write('star color theme <d|l>        terminal theme: ')
            Invoke-PrintOption $global:_rkt_terminal_theme 'dark' 'light'
            [Console]::WriteLine()
            [Console]::Write('star color random <mode>      random-palette stars: ')
            Invoke-PrintOption $global:_rkt_random_star_mode 'white' 'neon'
            [Console]::WriteLine()
            [Console]::Write('star color favorite <mode>    favorite-palette stars: ')
            Invoke-PrintOption $global:_rkt_favorite_star_mode 'gold' 'neon'
            [Console]::WriteLine()
            [Console]::Write('star weight <0-100>           ratio of favorites to random rockets. Currently: ')
            Set-RocketColor -Bold -Italics
            [Console]::Write("$global:_rkt_favorite_weight%")
            Set-RocketColor normal
            [Console]::WriteLine()
            [Console]::WriteLine('star color reset              restore defaults')
            [Console]::WriteLine()
            [Console]::WriteLine('star update                   update to the latest version')
            if ($global:_rkt_channel -eq 'cantaloupe') {
                [Console]::WriteLine('star update stable            switch back to the stable channel')
            }
            [Console]::WriteLine('star supernova                 remove starcommand from this system')
            [Console]::WriteLine()
            [Console]::WriteLine("  Favorites: $fav_file")
            [Console]::WriteLine("  History:   $hist_file (last 100 launches)")
            [Console]::WriteLine("  Settings:  $(Join-Path $HOME '.config/powershell/rocket_settings.ps1')")
        }

        'supernova' {
            [Console]::WriteLine('Are you sure you want to uninstall starcommand? [y/N]')
            $response = [Console]::ReadLine()
            if ($response -ne 'y' -and $response -ne 'Y') {
                [Console]::WriteLine('Uninstall cancelled.')
                return
            }
            [Console]::WriteLine('Keep your favorites and history? [Y/n]')
            $response = [Console]::ReadLine()
            $keep = $true
            if ($response -eq 'n' -or $response -eq 'N') { $keep = $false }

            $profilePath = $PROFILE.CurrentUserAllHosts
            if (Test-Path $profilePath) {
                $content = Get-Content $profilePath -Raw
                $cleaned = [regex]::Replace($content, "(?s)\r?\n?# >>> starcommand >>>.*?# <<< starcommand <<<\r?\n?", '')
                Set-Content -Path $profilePath -Value $cleaned.TrimEnd()
            }
            $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Source }
            if ($scriptPath -and (Test-Path $scriptPath)) { Remove-Item $scriptPath -Force }
            Remove-Item $script:RktUpdateCache -Force -ErrorAction SilentlyContinue

            $profileDir = Split-Path $PROFILE.CurrentUserAllHosts -Parent
            if ($keep) {
                [Console]::WriteLine("starcommand uninstalled. Favorites, history, and settings kept at $profileDir")
            } else {
                Remove-Item -Force -ErrorAction SilentlyContinue -Path @(
                    (Join-Path $profileDir 'rocket_favorites.txt'),
                    (Join-Path $profileDir 'rocket_history.txt'),
                    (Join-Path $profileDir 'rocket_settings.ps1')
                )
                [Console]::WriteLine('starcommand has been uninstalled.')
            }
        }

        default {
            [Console]::WriteLine("Unknown subcommand: $cmd")
            [Console]::WriteLine('Try: star, star list, star show, star add, star explore, star color, star weight, star update, star supernova, star help')
        }
    }
}

# ── Greeting helpers ───────────────────────────────────────────────────────────

function Write-WelcomeMessage {
    $cols = Get-TerminalCols
    $prefixLen = 19
    $available = $cols - $prefixLen - 2
    $value = "Welcome Aboard, Captain $(whoami)!"
    if ($value.Length -gt $available) {
        [Console]::Write($value.Substring(0, $available - 1) + "…")
    } else {
        [Console]::Write('Welcome Aboard, ')
        Set-RocketColor $global:_rkt_bdy
        [Console]::Write('Captain ')
        Set-RocketColor 'FFF'
        [Console]::Write((whoami))
    }
    Set-RocketColor normal
}

function Get-PortableUptime {
    try {
        # Fast path: cached boot tick from Invoke-HwInfo
        if ($global:_rkt_boot_tick -and $global:_rkt_boot_tick -gt 0) {
            $bootTime = [DateTime]::new($global:_rkt_boot_tick)
            $u = (Get-Date) - $bootTime
            return ('{0}d {1}h {2}m' -f $u.Days, $u.Hours, $u.Minutes)
        }
        # Fast fallback via Environment.TickCount (avoids WMI)
        $bootTime = [DateTime]::Now.AddMilliseconds(-[Environment]::TickCount)
        $u = (Get-Date) - $bootTime
        if ($u.TotalDays -lt 49) {
            return ('{0}d {1}h {2}m' -f $u.Days, $u.Hours, $u.Minutes)
        }
        # PowerShell 7+ has Get-Uptime built in (cross-platform)
        if (Get-Command Get-Uptime -ErrorAction SilentlyContinue) {
            $u = Get-Uptime
            return ('{0}d {1}h {2}m' -f $u.Days, $u.Hours, $u.Minutes)
        }
        # Windows PowerShell 5.1 fallback via CIM
        if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $u = (Get-Date) - $os.LastBootUpTime
            return ('{0}d {1}h {2}m' -f $u.Days, $u.Hours, $u.Minutes)
        }
        # Linux/macOS fallback to the uptime binary
        $raw = & uptime 2>$null
        if ($LASTEXITCODE -eq 0 -and $raw) {
            $piece = $raw | Select-String -Pattern '(up |,)' |
                     ForEach-Object { ($_ -split 'up ')[-1] -split ',' | Select-Object -First 1 }
            if ($piece) { return $piece.ToString().Trim() }
        }
    } catch {}
    return 'unknown'
}

function Write-DateInfo {
    $cols = Get-TerminalCols
    $prefixLen = 19
    $available = $cols - $prefixLen - 2
    $up_time = Get-PortableUptime
    $value = "Today is $(Get-Date -Format 'yyyy.MM.dd'), we are up and running for $up_time."
    if ($value.Length -gt $available) {
        [Console]::Write($value.Substring(0, $available - 1) + "…")
    } else {
        [Console]::Write('Today is ')
        Set-RocketColor cyan
        [Console]::Write((Get-Date -Format 'yyyy.MM.dd'))
        Set-RocketColor normal
        [Console]::Write(', we are up and running for ')
        Set-RocketColor cyan
        [Console]::Write($up_time)
        Set-RocketColor normal
        [Console]::Write('.')
    }
    Set-RocketColor normal
}

function Get-TerminalCols {
    $width = $Host.UI.RawUI.WindowSize.Width
    if ($width -le 0) { return 80 }
    return $width
}

function Write-OSInfo {
    $cols = Get-TerminalCols
    $prefixLen = 28
    $available = $cols - $prefixLen - 2
    $value = $global:_rkt_os
    Set-RocketColor yellow
    [Console]::Write("`tOS: ")
    Set-RocketColor '0F0'
    if ($value.Length -gt $available) {
        [Console]::Write($value.Substring(0, $available - 1) + "…")
    } else {
        [Console]::Write($value)
    }
    Set-RocketColor normal
}

function Write-CpuInfo {
    $cols = Get-TerminalCols
    $prefixLen = 29
    $available = $cols - $prefixLen - 2
    $value = $global:_rkt_cpu
    Set-RocketColor yellow
    [Console]::Write("`tCPU: ")
    Set-RocketColor '0F0'
    if ($value.Length -gt $available) {
        [Console]::Write($value.Substring(0, $available - 1) + "…")
    } else {
        [Console]::Write($value)
    }
    Set-RocketColor normal
}

function Write-MemInfo {
    $cols = Get-TerminalCols
    $prefixLen = 32
    $available = $cols - $prefixLen - 2
    $value = $global:_rkt_mem
    Set-RocketColor yellow
    [Console]::Write("`tMemory: ")
    Set-RocketColor '0F0'
    if ($value.Length -gt $available) {
        [Console]::Write($value.Substring(0, $available - 1) + "…")
    } else {
        [Console]::Write($value)
    }
    Set-RocketColor normal
}

function Write-NetInfo {
    $cols = Get-TerminalCols
    $prefixLen = 29
    $available = $cols - $prefixLen - 2
    $value = "IP Address: $global:_rkt_ip, Default Gateway: $global:_rkt_gw"
    Set-RocketColor yellow
    [Console]::Write("`tNet: ")
    Set-RocketColor '0F0'
    if ($value.Length -gt $available) {
        [Console]::Write($value.Substring(0, $available - 1) + "…")
    } else {
        [Console]::Write($value)
    }
    Set-RocketColor normal
}

# ── Main greeting ──────────────────────────────────────────────────────────────

function Invoke-Starcommand {
    param(
        [uint32]$OverrideSeed = 0,
        [string[]]$OverridePalette = @()
    )

    if ($OverrideSeed -ne 0) {
        $script:_RKT_PRNG_STATE = $OverrideSeed
    } else {
        Set-PrngSeed
    }

    Invoke-LoadSettings

    $colors = @()
    if ($OverridePalette.Count -eq 6) {
        $colors = $OverridePalette
    } else {
        $colors = Invoke-RocketPickPalette
    }

    $global:_rkt_tip = $colors[0]
    $global:_rkt_win = $colors[1]
    $global:_rkt_bdy = $colors[2]
    $global:_rkt_top = $colors[3]
    $global:_rkt_sds = $colors[4]
    $global:_rkt_flm = $colors[5]
    $global:_rocket_stars = Invoke-ComputeStarPositions

    if (Test-PaletteIsFavorite) {
        $global:_rkt_star_mode = $global:_rkt_favorite_star_mode
    } else {
        $global:_rkt_star_mode = $global:_rkt_random_star_mode
    }

    if (-not $global:_RKT_AUTO_UPDATE_CHECK) {
        [Console]::Write('starcommand: Allow starcommand to check Github periodically for future updates? [Y/N] ')
        $response = [Console]::ReadLine()
        if ($response -eq 'y' -or $response -eq 'Y') {
            $global:_RKT_AUTO_UPDATE_CHECK = 'yes'
        } else {
            $global:_RKT_AUTO_UPDATE_CHECK = 'no'
        }
        Invoke-SaveSettings
    }
    Invoke-HwInfo
    Invoke-NetInfo
    Invoke-UpdateCheckBackground

    [Console]::WriteLine()

    Invoke-RenderRow 0 (' ' * 18) (' ' * 18)
    [Console]::WriteLine()

    Invoke-RenderRow 1 '        |         ' '        b         '
    [Console]::Write(' '); Write-WelcomeMessage; [Console]::WriteLine()

    Invoke-RenderRow 2 '       / \        ' '       t t        '
    [Console]::WriteLine()

    Invoke-RenderRow 3 '      / _ \       ' '      t t t       '
    [Console]::Write(' '); Write-DateInfo; [Console]::WriteLine()

    Invoke-RenderRow 4 '     |.o ''.|      ' '     swp wws      '
    [Console]::WriteLine()

    Invoke-RenderRow 5 '     |''._.''|      ' '     swwwwws      '
    [Console]::WriteLine(' Space Vessel:')

    Invoke-RenderRow 6 '     |     |      ' '     b     b      '
    [Console]::Write(' '); Write-OSInfo; [Console]::WriteLine()

    Invoke-RenderRow 7 '   ,''|  |  |`.    ' '   ssb  b  bss    '
    [Console]::Write(' '); Write-CpuInfo; [Console]::WriteLine()

    Invoke-RenderRow 8 '  /  |  |  |  \   ' '  s  b  b  b  s   '
    [Console]::Write(' '); Write-MemInfo; [Console]::WriteLine()

    Invoke-RenderRow 9 '  |,-''--|--''-.|   ' '  bsssttbttsssb   '
    [Console]::Write(' '); Write-NetInfo; [Console]::WriteLine()

    Invoke-RenderFlame
    [Console]::WriteLine()

    Invoke-RenderRow 11 (' ' * 18) (' ' * 18)
    [Console]::WriteLine()

    [Console]::WriteLine()
    Set-RocketColor grey
    [Console]::WriteLine('Have a Nice Trip!')
    Set-RocketColor normal
    Invoke-UpdateCheckNudge
}

# Export functions for testing
$exported = @(
    'Invoke-XorShift32',
    'Set-RocketColor', 'Convert-HslToHex', 'Invoke-RenderRow', 'Invoke-RenderFlame',
    'Invoke-PaletteBytes', 'Invoke-ComputeStarPositions', 'Invoke-GenRocketPalette',
    'Invoke-Starcommand', 'Get-StarColorForMode', 'Get-PrngRange', 'Set-PrngSeed',
    'Invoke-RecordHistory', 'Invoke-RocketPickPalette', 'Test-PaletteIsFavorite',
    'Invoke-PrintStarRow', 'Test-ValidateHexes', 'Invoke-PreviewPalette',
    'Invoke-LoadSettings', 'Invoke-SaveSettings', 'Invoke-PrintOption',
    'Invoke-HwInfo', 'Invoke-NetInfo', 'star'
)

# If the script is dot-sourced, just define functions (no auto-run)
# If run directly, execute once
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Starcommand
}
