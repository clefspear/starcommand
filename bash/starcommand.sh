#!/usr/bin/env bash
# Created By: Peter Azmy
# starcommand.sh — Portable rocket greeting for Bash
# Implements xorshift32 PRNG for cross-shell deterministic output

_RKT_VERSION="1.2.3-cantaloupe"
_RKT_UPDATE_CACHE="$HOME/.config/bash/rocket_update_check"

_rkt_update_check_background() {
    [[ -n ${STARCOMMAND_NO_UPDATE_CHECK:-} ]] && return
    [[ "${_RKT_AUTO_UPDATE_CHECK:-}" == "yes" ]] || return
    [[ -t 1 ]] || return
    mkdir -p "$HOME/.config/bash"
    local now=$(date +%s)
    if [[ -f "$_RKT_UPDATE_CACHE" ]]; then
        local last_check
        IFS= read -r last_check < "$_RKT_UPDATE_CACHE"
        local age=$((now - last_check))
        [[ $age -lt 604800 ]] && return
    fi
    if [[ -f "$_RKT_UPDATE_CACHE" ]]; then
        local cached_v
        cached_v=$(tail -1 "$_RKT_UPDATE_CACHE" 2>/dev/null)
        if [[ "$cached_v" == "$_RKT_VERSION" ]]; then
            rm -f "$_RKT_UPDATE_CACHE"
            return
        fi
    fi
    local branch="main"
    _rkt_load_settings
    [[ "$_rkt_channel" == "cantaloupe" ]] && branch="cantaloupe"
    ( curl -fsSL --max-time 3 "https://raw.githubusercontent.com/clefspear/starcommand/${branch}/VERSION" 2>/dev/null \
        | { IFS= read -r v; printf '%s\n%s\n' "$now" "${v:-}"; } \
        > "$_RKT_UPDATE_CACHE" ) 2>/dev/null &
    disown
}

_rkt_update_check_nudge() {
    [[ -n ${STARCOMMAND_NO_UPDATE_CHECK:-} ]] && return
    [[ -f "$_RKT_UPDATE_CACHE" ]] || return
    local cached_version
    cached_version=$(tail -1 "$_RKT_UPDATE_CACHE" 2>/dev/null)
    [[ -n $cached_version ]] || return
    [[ "$cached_version" != "$_RKT_VERSION" ]] || return
    rkt_set_color grey
    echo "(starcommand v$cached_version available — run 'star update' — https://github.com/clefspear/starcommand/blob/main/CHANGELOG.md)"
    rkt_set_color normal
}

# ── Portable PRNG ──────────────────────────────────────────────────────────────

_RKT_PRNG_STATE=0
_RKT_PRNG_RET=

rkt_xorshift32() {
    local s=$1
    s=$(( (s ^ (s << 13)) & 0xFFFFFFFF ))
    s=$(( (s ^ (s >> 17)) & 0xFFFFFFFF ))
    s=$(( (s ^ (s << 5))  & 0xFFFFFFFF ))
    echo $s
}

rkt_prng_seed() {
    while :; do
        _RKT_PRNG_STATE=$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')
        [ "$_RKT_PRNG_STATE" -ne 0 ] && break
    done
}

rkt_prng_range() {
    local min=$1 max=$2 range
    _RKT_PRNG_STATE=$(( ( (_RKT_PRNG_STATE ^ (_RKT_PRNG_STATE << 13)) & 0xFFFFFFFF ) ))
    _RKT_PRNG_STATE=$(( ( (_RKT_PRNG_STATE ^ (_RKT_PRNG_STATE >> 17)) & 0xFFFFFFFF ) ))
    _RKT_PRNG_STATE=$(( ( (_RKT_PRNG_STATE ^ (_RKT_PRNG_STATE << 5)) & 0xFFFFFFFF ) ))
    range=$((max - min + 1))
    _RKT_PRNG_RET=$((min + (_RKT_PRNG_STATE % range)))
}

# ── Color utilities ────────────────────────────────────────────────────────────

rkt_set_color() {
    local bold=false italic=false
    local -a args=()
    for arg in "$@"; do
        case "$arg" in
            --bold) bold=true ;;
            --italics) italic=true ;;
            normal|reset) printf '\e[m'; return ;;
            *) args+=("$arg") ;;
        esac
    done
    local -a codes=()
    $bold && codes+=('1')
    $italic && codes+=('3')
    if (( ${#args[@]} > 0 )); then
        local hex="${args[0]}"
        case $hex in
            grey)   hex=808080 ;;
            cyan)   hex=00FFFF ;;
            yellow) hex=FFFF00 ;;
            0F0)    hex=00FF00 ;;
            FFF)    hex=FFFFFF ;;
        esac
        if [[ ${#hex} -eq 3 ]]; then
            hex="${hex:0:1}${hex:0:1}${hex:1:1}${hex:1:1}${hex:2:1}${hex:2:1}"
        fi
        local r=$((16#${hex:0:2}))
        local g=$((16#${hex:2:2}))
        local b=$((16#${hex:4:2}))
        codes+=("38;2;$r;$g;$b")
    fi
    local IFS=';'
    printf '\e[%sm' "${codes[*]}"
}

rkt_hsl_to_hex() {
    local h=$1 s=$2 l=$3
    awk -v h="$1" -v s="$2" -v l="$3" 'BEGIN {
        sat = s / 100
        light = l / 100
        c = (1 - (2*light - 1 < 0 ? -(2*light - 1) : (2*light - 1))) * sat
        hp = h / 60
        t = hp - 2 * int(hp / 2)
        td = t - 1
        x = c * (1 - (td < 0 ? -td : td))
        m = light - c / 2
        hi = int(h)
        if (hi < 60) { r = c; g = x; b = 0 }
        else if (hi < 120) { r = x; g = c; b = 0 }
        else if (hi < 180) { r = 0; g = c; b = x }
        else if (hi < 240) { r = 0; g = x; b = c }
        else if (hi < 300) { r = x; g = 0; b = c }
        else { r = c; g = 0; b = x }
        ri = int((r + m) * 255 + 0.5)
        gi = int((g + m) * 255 + 0.5)
        bi = int((b + m) * 255 + 0.5)
        printf "%02x%02x%02x\n", ri, gi, bi
    }'
}

# ── Settings globals (persisted) ───────────────────────────────────────────────

_rkt_random_star_mode=white
_rkt_favorite_star_mode=gold
_rkt_terminal_theme=dark
_rkt_favorite_weight=20
_rkt_channel=main

# ── Globals (set on each greeting) ─────────────────────────────────────────────

_RKT_TIP=
_RKT_WIN=
_RKT_BDY=
_RKT_TOP=
_RKT_SDS=
_RKT_FLM=
_RKT_STAR_MODE=white
_RKT_TERMINAL_THEME=dark
_RKT_PALETTE_BYTES=()

# ── Rocket art ─────────────────────────────────────────────────────────────────

ROCKET_ART=(
    "        |         "
    "       / \\        "
    "      / _ \\       "
    "     |.o '.|      "
    "     |'._.'|      "
    "     |     |      "
    "   ,'|  |  |\`.    "
    "  /  |  |  |  \\   "
    "  |,-'--|--'-.|   "
)

ROCKET_ROLE=(
    "        b         "
    "       t t        "
    "      t t t       "
    "     swp wws      "
    "     swwwwws      "
    "     b     b      "
    "   ssb  b  bss    "
    "  s  b  b  b  s   "
    "  bsssttbttsssb   "
)

FLAME_PATTERNS=(
    '\| ||' '|| |/' '\| |/' '|| ||' '*| |*' '~| ||' '|| |~' '\| /|'
)

NEON_COLORS=(
    FF0033 FF3300 FF6600 FF9900 FFBB00 FFDD00 FFFF00
    CCFF00 99FF00 66FF00 33FF00 00FF33 00FF66 00FF99
    00FFCC 00FFFF 00CCFF 0099FF 0066FF 0033FF 3300FF
    6600FF 9900FF CC00FF FF00FF FF00CC FF0099 FF0066
)

NEON_COLORS_LIGHT=(
    CC0029 CC2900 CC5200 CC7A00 CC9500 B8860B AAAA00
    88AA00 668800 448800 228822 228B22 008844 008866
    008B7F 008B8B 0077AA 1E6FB8 0055CC 0033AA 2200AA
    4B0082 6622AA 7B1FA2 A020A0 AA0088 AD1457 AA0044
)

# ── Star candidates ────────────────────────────────────────────────────────────

_RKT_STAR_CANDIDATES=(
    0:0 0:1 0:2 0:3 0:4 0:5 0:6 0:7 0:8 0:9 0:10 0:11 0:12 0:13 0:14 0:15 0:16 0:17
    1:0 1:1 1:2 1:3 1:4 1:5 1:6 1:7 1:9 1:10 1:11 1:12 1:13 1:14 1:15 1:16 1:17
    2:0 2:1 2:2 2:3 2:4 2:5 2:6 2:10 2:11 2:12 2:13 2:14 2:15 2:16 2:17
    3:0 3:1 3:2 3:3 3:4 3:5 3:11 3:12 3:13 3:14 3:15 3:16 3:17
    4:0 4:1 4:2 4:3 4:4 4:12 4:13 4:14 4:15 4:16 4:17
    5:0 5:1 5:2 5:3 5:4 5:12 5:13 5:14 5:15 5:16 5:17
    6:0 6:1 6:2 6:3 6:4 6:6 6:7 6:8 6:9 6:10 6:12 6:13 6:14 6:15 6:16 6:17
    7:0 7:1 7:2 7:6 7:7 7:9 7:10 7:14 7:15 7:16 7:17
    8:0 8:1 8:3 8:4 8:6 8:7 8:9 8:10 8:12 8:13 8:15 8:16 8:17
    9:0 9:1 9:15 9:16 9:17
    11:0 11:1 11:2 11:3 11:4 11:5 11:6 11:7 11:8 11:9 11:10 11:11 11:12 11:13 11:14 11:15 11:16 11:17
)

# ── Star positions ─────────────────────────────────────────────────────────────

rkt_palette_bytes() {
    local color
    for color in "$_RKT_TIP" "$_RKT_WIN" "$_RKT_BDY" "$_RKT_TOP" "$_RKT_SDS" "$_RKT_FLM"; do
        echo $((16#${color:0:2}))
        echo $((16#${color:2:2}))
        echo $((16#${color:4:2}))
    done
}

rkt_compute_star_positions() {
    local total=${#_RKT_STAR_CANDIDATES[@]}
    local b i1 i2 cand seen="::"
    for b in "${_RKT_PALETTE_BYTES[@]}"; do
        i1=$((b % total))
        i2=$(((b + 73) % total))
        for cand in "${_RKT_STAR_CANDIDATES[$i1]}" "${_RKT_STAR_CANDIDATES[$i2]}"; do
            [[ $seen == *"::$cand::"* ]] && continue
            seen+="$cand::"
            echo "$cand"
        done
    done
}

rkt_is_star() {
    local key=$1 s
    for s in "${_ROCKET_STARS[@]}"; do
        [[ $s == "$key" ]] && return 0
    done
    return 1
}

# ── Neon colors ────────────────────────────────────────────────────────────────

_rkt_neon_color() {
    rkt_prng_range 1 ${#NEON_COLORS[@]}
    _RKT_PRNG_RET="${NEON_COLORS[$((_RKT_PRNG_RET - 1))]}"
}

_rkt_neon_color_light() {
    rkt_prng_range 1 ${#NEON_COLORS_LIGHT[@]}
    _RKT_PRNG_RET="${NEON_COLORS_LIGHT[$((_RKT_PRNG_RET - 1))]}"
}

# ── Star color ─────────────────────────────────────────────────────────────────

rkt_star_color_for_mode() {
    case $_RKT_STAR_MODE in
        gold)
            if [[ $_RKT_TERMINAL_THEME == light ]]; then
                _RKT_PRNG_RET=B8860B
            else
                _RKT_PRNG_RET=FFE600
            fi
            ;;
        neon)
            if [[ $_RKT_TERMINAL_THEME == light ]]; then
                _rkt_neon_color_light
            else
                _rkt_neon_color
            fi
            ;;
        *)
            if [[ $_RKT_TERMINAL_THEME == light ]]; then
                _RKT_PRNG_RET=333333
            else
                _RKT_PRNG_RET=FFFFFF
            fi
            ;;
    esac
}

# ── Rendering ──────────────────────────────────────────────────────────────────

rkt_render_row() {
    local line_num=$1 art=$2 role=$3
    local col char r key
    for ((col=0; col<18; col++)); do
        char="${art:$col:1}"
        key="$line_num:$col"
        if [[ $char != " " ]]; then
            r="${role:$col:1}"
            case $r in
                p) rkt_set_color "$_RKT_TIP" ;;
                w) rkt_set_color "$_RKT_WIN" ;;
                b) rkt_set_color "$_RKT_BDY" ;;
                t) rkt_set_color "$_RKT_TOP" ;;
                s) rkt_set_color "$_RKT_SDS" ;;
                f) rkt_set_color "$_RKT_FLM" ;;
            esac
            echo -n "$char"
            rkt_set_color normal
        elif rkt_is_star "$key"; then
            rkt_star_color_for_mode
            rkt_set_color "$_RKT_PRNG_RET"
            echo -n '*'
            rkt_set_color normal
        else
            echo -n ' '
        fi
    done
}

rkt_render_flame() {
    local idx pattern
    idx=$((_RKT_PALETTE_BYTES[0] % ${#FLAME_PATTERNS[@]}))
    pattern=${FLAME_PATTERNS[$idx]}
    echo -n '      '
    rkt_set_color "$_RKT_FLM"
    echo -n "$pattern"
    rkt_set_color normal
}

# ── Palette generation ─────────────────────────────────────────────────────────

rkt_gen_rocket_palette() {
    local h_base scheme sat light offs h
    rkt_prng_range 0 359; h_base=$_RKT_PRNG_RET
    rkt_prng_range 0 4;   scheme=$_RKT_PRNG_RET
    rkt_prng_range 65 90; sat=$_RKT_PRNG_RET
    rkt_prng_range 55 72; light=$_RKT_PRNG_RET

    case $scheme in
        0) offs=(0 60 120 180 240 300) ;;
        1) offs=(0 50 110 180 230 290) ;;
        2) offs=(0 70 130 200 250 310) ;;
        3) offs=(0 45 115 180 235 295) ;;
        *) offs=(0 65 125 190 245 310) ;;
    esac

    for off in "${offs[@]}"; do
        h=$(((h_base + off) % 360))
        echo "$h $sat $light"
    done | awk '{
        h = $1; s = $2; l_in = $3
        sat = s / 100
        light = l_in / 100
        c = (1 - (2*light - 1 < 0 ? -(2*light - 1) : 2*light - 1)) * sat
        hp = h / 60
        t = hp - 2 * int(hp / 2)
        td = t - 1
        x = c * (1 - (td < 0 ? -td : td))
        m = light - c / 2
        hi = int(h)
        if (hi < 60) { r = c; g = x; b = 0 }
        else if (hi < 120) { r = x; g = c; b = 0 }
        else if (hi < 180) { r = 0; g = c; b = x }
        else if (hi < 240) { r = 0; g = x; b = c }
        else if (hi < 300) { r = x; g = 0; b = c }
        else { r = c; g = 0; b = x }
        ri = int((r + m) * 255 + 0.5)
        gi = int((g + m) * 255 + 0.5)
        bi = int((b + m) * 255 + 0.5)
        printf "%02x%02x%02x\n", ri, gi, bi
    }'
}

_rocket_record_history() {
    local file="$HOME/.config/bash/rocket_history.txt"
    local lock="$file.lock"
    mkdir -p "$(dirname "$file")"
    local waited=0
    while ! mkdir "$lock" 2>/dev/null; do
        sleep 0.05
        waited=$((waited + 1))
        (( waited < 20 )) || return 1
    done
    trap 'rmdir "$lock" 2>/dev/null' EXIT
    echo "$*" >> "$file"
    local lc=$(wc -l < "$file" | tr -d ' ')
    if (( lc > 100 )); then
        tail -n 100 "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    fi
    rmdir "$lock" 2>/dev/null
    trap - EXIT
}

_rocket_pick_palette() {
    local fav_file="$HOME/.config/bash/rocket_favorites.txt"
    local -a colors=()

    rkt_prng_range 1 100
    if (( _RKT_PRNG_RET <= _rkt_favorite_weight )) && [[ -f "$fav_file" ]]; then
        local -a favs=()
        while IFS= read -r line; do favs+=("$line"); done < "$fav_file"
        if (( ${#favs[@]} > 0 )); then
            rkt_prng_range 1 ${#favs[@]}
            local rand_idx=$((_RKT_PRNG_RET - 1))
            colors=(${favs[$rand_idx]})
        fi
    fi

    if (( ${#colors[@]} != 6 )); then
        colors=($(rkt_gen_rocket_palette))
    fi

    _rocket_record_history "${colors[@]}"

    printf '%s\n' "${colors[@]}"
}

# ── History / Favorites helpers ────────────────────────────────────────────────

_palette_is_favorite() {
    local fav_file="$HOME/.config/bash/rocket_favorites.txt"
    [[ ! -f "$fav_file" ]] && return 1
    local palette="$_RKT_TIP $_RKT_WIN $_RKT_BDY $_RKT_TOP $_RKT_SDS $_RKT_FLM"
    grep -Fxq "$palette" "$fav_file"
}

_rocket_print_star_row() {
    local n="$1" palette="$2"
    local -a cs=($palette)
    if (( $# >= 3 )); then
        printf '%s' "$3"
    else
        printf "%3d. " "$n"
    fi
    rkt_set_color "${cs[0]}"; echo -n "★ "
    rkt_set_color "${cs[1]}"; echo -n "★ "
    rkt_set_color "${cs[2]}"; echo -n "★ "
    rkt_set_color "${cs[3]}"; echo -n "★ "
    rkt_set_color "${cs[4]}"; echo -n "★ "
    rkt_set_color "${cs[5]}"; echo -n "★"
    rkt_set_color normal
    echo "  $palette"
}

_star_validate_hexes() {
    local -a hexes=()
    local raw cleaned
    for raw in "$@"; do
        cleaned="${raw#\#}"
        if [[ ! "$cleaned" =~ ^[0-9a-fA-F]{6}$ ]]; then
            return 1
        fi
        hexes+=("$cleaned")
    done
    printf '%s\n' "${hexes[@]}"
}

_star_preview_palette() {
    local h1="$1" h2="$2" h3="$3" h4="$4" h5="$5" h6="$6"
    local saved_tip="$_RKT_TIP" saved_win="$_RKT_WIN" saved_bdy="$_RKT_BDY"
    local saved_top="$_RKT_TOP" saved_sds="$_RKT_SDS" saved_flm="$_RKT_FLM"
    local -a saved_stars=("${_ROCKET_STARS[@]}")

    _RKT_TIP=$h1; _RKT_WIN=$h2; _RKT_BDY=$h3
    _RKT_TOP=$h4; _RKT_SDS=$h5; _RKT_FLM=$h6
    _ROCKET_STARS=()

    rkt_render_row 1 "        |         " "        b         "; echo
    rkt_render_row 2 "       / \\        " "       t t        "; echo
    rkt_render_row 3 "      / _ \\       " "      t t t       "; echo
    rkt_render_row 4 "     |.o '.|      " "     swp wws      "; echo
    rkt_render_row 5 "     |'._.'|      " "     swwwwws      "; echo
    rkt_render_row 6 "     |     |      " "     b     b      "; echo
    rkt_render_row 7 "   ,'|  |  |\`.    " "   ssb  b  bss    "; echo
    rkt_render_row 8 "  /  |  |  |  \\   " "  s  b  b  b  s   "; echo
    rkt_render_row 9 "  |,-'--|--'-.|   " "  bsssttbttsssb   "; echo
    rkt_render_flame; echo

    _RKT_TIP=$saved_tip; _RKT_WIN=$saved_win; _RKT_BDY=$saved_bdy
    _RKT_TOP=$saved_top; _RKT_SDS=$saved_sds; _RKT_FLM=$saved_flm
    _ROCKET_STARS=("${saved_stars[@]}")
}

# ── Settings ───────────────────────────────────────────────────────────────────

_rkt_load_settings() {
    local cfg="$HOME/.config/bash/rocket_settings.sh"
    _rkt_random_star_mode=white
    _rkt_favorite_star_mode=gold
    _rkt_terminal_theme=dark
    _rkt_favorite_weight=20
    _rkt_channel=main
    _RKT_AUTO_UPDATE_CHECK=""
    [[ -f "$cfg" ]] && source "$cfg"
}

_rkt_save_settings() {
    local cfg="$HOME/.config/bash/rocket_settings.sh"
    mkdir -p "$(dirname "$cfg")"
    printf '_rkt_random_star_mode=%s\n'   "$_rkt_random_star_mode"    > "$cfg"
    printf '_rkt_favorite_star_mode=%s\n' "$_rkt_favorite_star_mode" >> "$cfg"
    printf '_rkt_terminal_theme=%s\n'     "$_rkt_terminal_theme"     >> "$cfg"
    printf '_rkt_favorite_weight=%s\n'    "$_rkt_favorite_weight"    >> "$cfg"
    printf '_rkt_channel=%s\n'            "$_rkt_channel"            >> "$cfg"
    printf '_RKT_AUTO_UPDATE_CHECK=%s\n'  "$_RKT_AUTO_UPDATE_CHECK"  >> "$cfg"
}

_rkt_print_option() {
    local active="$1"
    shift
    local -a opts=("$@")
    echo -n "("
    local first=1 opt
    for opt in "${opts[@]}"; do
        if (( first == 0 )); then
            echo -n " | "
        fi
        first=0
        if [[ "$active" == "$opt" ]]; then
            rkt_set_color --bold --italics
            echo -n "$opt"
            rkt_set_color normal
        else
            echo -n "$opt"
        fi
    done
    echo -n ")"
}

# ── System info ────────────────────────────────────────────────────────────────

_rkt_hw_info() {
    local cache="$HOME/.config/bash/rocket_hw_cache.sh"
    if [[ -f "$cache" ]] && [[ -n $(find "$cache" -mmin -1440 2>/dev/null) ]]; then
        source "$cache"
        return
    fi
    mkdir -p "$(dirname "$cache")"
    local os_type=$(uname -s)
    local os_str=$(uname -sm)
    local cpu_str="" mem_str=""
    if [[ "$os_type" == "Darwin" ]]; then
        local chip_name=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
        local hw_info=$(system_profiler SPHardwareDataType 2>/dev/null)
        local cores_n=$(echo "$hw_info" | grep "Total Number of Cores" | cut -d ":" -f2 | tr -d ' ')
        cpu_str="$chip_name, $cores_n"
        mem_str=$(echo "$hw_info" | grep "Memory:" | cut -d ":" -f 2 | tr -d " ")
    elif [[ "$os_type" == "Linux" ]]; then
        local procs_n=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null)
        local cores_n=$(grep "cpu cores" /proc/cpuinfo 2>/dev/null | head -1 | cut -d ":" -f2 | tr -d " ")
        local cpu_type=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d ":" -f2)
        cpu_str="$procs_n processors, $cores_n cores, $cpu_type"
        if [[ -r /proc/meminfo ]]; then
            local mem_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo | tr -d ' \n')
            if [[ -n $mem_kb ]]; then
                mem_str=$(awk -v k="$mem_kb" 'BEGIN{printf "%.0fGB", k/1024/1024}')
            fi
        fi
        if [[ -z $mem_str ]]; then
            mem_str=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
        fi
        if [[ -r /etc/os-release ]]; then
            local pretty=$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"')
            local arch=$(uname -m)
            if [[ -n $pretty ]]; then
                os_str="$pretty $arch"
            fi
        fi
    fi
    printf '_rkt_os="%s"\n'  "$os_str"  > "$cache"
    printf '_rkt_cpu="%s"\n' "$cpu_str" >> "$cache"
    printf '_rkt_mem="%s"\n' "$mem_str" >> "$cache"
    source "$cache"
}

_rkt_net_info() {
    local cache="$HOME/.config/bash/rocket_net_cache.sh"
    if [[ -f "$cache" ]] && [[ -n $(find "$cache" -mmin -5 2>/dev/null) ]]; then
        source "$cache"
        return
    fi
    mkdir -p "$(dirname "$cache")"
    local os_type=$(uname -s)
    local ip="" gw=""
    if [[ "$os_type" == "Darwin" ]]; then
        ip=$(ifconfig 2>/dev/null | awk '
            /^[a-zA-Z0-9]+:/ {
                if (iface != "" && addr != "" && is_active == 1 && iface !~ /^(lo|lo0|docker|br-|veth|vmnet|vboxnet|utun|tun|tap|awdl|llw|anpi)/) { print addr; exit }
                iface = $1; sub(/:$/, "", iface); addr = ""; is_active = 0
            }
            /inet / && !/127\.0\.0\.1/ { addr = $2 }
            /status: active/ { is_active = 1 }
            END { if (iface != "" && addr != "" && is_active == 1 && iface !~ /^(lo|lo0|docker|br-|veth|vmnet|vboxnet|utun|tun|tap|awdl|llw|anpi)/) print addr }
        ')
        gw=$(netstat -nr 2>/dev/null | awk '/^default/ {print $2; exit}')
    elif [[ "$os_type" == "Linux" ]]; then
        ip=$(ip -o addr show 2>/dev/null | awk '$3 == "inet" && $2 !~ /^(lo|docker|br-|veth|vmnet|vboxnet|utun|tun|tap|awdl|llw|anpi)/ && $4 !~ /^127\./ { split($4, a, "/"); print a[1]; exit }')
        gw=$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}')
    fi
    printf '_rkt_ip="%s"\n' "$ip" > "$cache"
    printf '_rkt_gw="%s"\n' "$gw" >> "$cache"
    source "$cache"
}

# ── Explore animation ─────────────────────────────────────────────────────────

_RKT_ROCKET_PIDS=()

rkt_rocket_cleanup() {
    local pid
    for pid in "${_RKT_ROCKET_PIDS[@]}"; do
        kill "$pid" 2>/dev/null
    done
    _RKT_ROCKET_PIDS=()
    rkt_set_color normal
    printf '\e[?25h'
}

rkt_launch_rocket() {
    local i=$1
    local prefix=$(printf "%3d. " "$i")
    local prefix_len=${#prefix}
    local r hex
    rkt_prng_range 0 5; local col_idx=$_RKT_PRNG_RET
    local term_col=$((prefix_len + 1 + col_idx * 2))
    local term_rows=$(tput lines 2>/dev/null || echo 24)
    local term_cols=$(tput cols 2>/dev/null || echo 80)
    local start_row=$((term_rows > 2 ? term_rows - 1 : term_rows))
    local dir
    rkt_prng_range 0 1; dir=$_RKT_PRNG_RET
    [[ $dir -eq 0 ]] && dir=-1

    local rhex="FFFFFF"; local red=255; local green=255; local blue=255
    if [[ "$_RKT_TERMINAL_THEME" == "light" ]]; then
        rhex="333333"; red=51; green=51; blue=51
    fi

    (
        local row=$start_row
        local col=$term_col
        local d=$dir
        local moved=false

        # Initial body draw at start position (no flame)
        printf '\e[s\e[%d;%dH\e[38;2;%d;%d;%dm|\e[m\e[u' "$row" "$col" "$red" "$green" "$blue"

        while (( row > 1 )); do
            sleep 0.1

            # Clear old body and flame
            if $moved; then
                printf '\e[s\e[%d;%dH \e[%d;%dH \e[u' "$row" "$col" "$((row+1))" "$col"
            else
                printf '\e[s\e[%d;%dH \e[u' "$row" "$col"
            fi

            # Move up one, bounce left/right
            local nr=$((row - 1))
            local nc=$((col + d))
            if (( nc < 2 || nc >= term_cols )); then
                d=$(( -d ))
                nc=$((col + d))
            fi
            row=$nr; col=$nc
            moved=true

            # Draw body
            printf '\e[s\e[%d;%dH\e[38;2;%d;%d;%dm|\e[m\e[u' "$row" "$col" "$red" "$green" "$blue"

            # Flame flickers 3-4 times
            local nf=3
            rkt_prng_range 3 4; nf=$_RKT_PRNG_RET
            local fi
            for ((fi=0; fi<nf; fi++)); do
                sleep 0.025
                local rb ch
                rb=$(od -An -N1 -tu1 /dev/urandom 2>/dev/null | tr -d ' ')
                rb=$(( rb % 3 ))
                case $rb in
                    0) ch='^' ;; 1) ch='*' ;; *) ch='v' ;;
                esac
                printf '\e[s\e[%d;%dH\e[38;2;%d;%d;%dm%s\e[m\e[u' "$((row+1))" "$col" "$red" "$green" "$blue" "$ch"
            done
        done

        # Clear final position at top
        printf '\e[s\e[%d;%dH \e[%d;%dH \e[u' 1 "$col" 2 "$col"
    ) &
    _RKT_ROCKET_PIDS+=($!)
}

# ── Star command ───────────────────────────────────────────────────────────────

star() {
    local fav_file="$HOME/.config/bash/rocket_favorites.txt"
    local hist_file="$HOME/.config/bash/rocket_history.txt"

    if (( $# == 0 )); then
        if [[ -z ${_RKT_BDY:-} ]]; then
            echo "No active palette. Open a new tab first."
            return 1
        fi
        local palette="$_RKT_TIP $_RKT_WIN $_RKT_BDY $_RKT_TOP $_RKT_SDS $_RKT_FLM"
        if [[ -f "$fav_file" ]] && grep -Fxq "$palette" "$fav_file"; then
            echo "Already in favorites."
            return 0
        fi
        mkdir -p "$(dirname "$fav_file")"
        echo "$palette" >> "$fav_file"
        rkt_set_color "$_RKT_TIP"; echo -n "★ "
        rkt_set_color "$_RKT_WIN"; echo -n "★ "
        rkt_set_color "$_RKT_BDY"; echo -n "★ "
        rkt_set_color "$_RKT_TOP"; echo -n "★ "
        rkt_set_color "$_RKT_SDS"; echo -n "★ "
        rkt_set_color "$_RKT_FLM"; echo -n "★"
        rkt_set_color normal
        local total=$(wc -l < "$fav_file" | tr -d ' ')
        printf '  saved! (%s total)\n' "$total"
        return 0
    fi

    case "$1" in
        list|ls)
            if [[ ! -f "$fav_file" ]]; then
                echo "No favorites yet. Use 'star' to save the current palette."
                return 0
            fi
            local i=1
            while IFS= read -r line; do
                _rocket_print_star_row "$i" "$line"
                ((i++))
            done < "$fav_file"
            ;;

        remove|rm)
            if [[ ! -f "$fav_file" ]]; then
                echo "No favorites to remove."
                return 1
            fi
            local n="$2"
            if [[ ! "$n" =~ ^[0-9]+$ ]]; then
                echo "Usage: star remove <number>"
                return 1
            fi
            local -a lines=()
            while IFS= read -r line; do lines+=("$line"); done < "$fav_file"
            local total=${#lines[@]}
            if (( n < 1 || n > total )); then
                echo "Out of range. You have $total favorites."
                return 1
            fi
            local -a new_lines=()
            local idx
            for ((idx=0; idx<${#lines[@]}; idx++)); do
                if (( idx != n - 1 )); then
                    new_lines+=("${lines[$idx]}")
                fi
            done
            if (( ${#new_lines[@]} == 0 )); then
                rm "$fav_file"
            else
                printf '%s\n' "${new_lines[@]}" > "$fav_file"
            fi
            echo "Removed #$n."
            ;;

        history|hist)
            if [[ ! -f "$hist_file" ]]; then
                echo "No history yet."
                return 0
            fi
            local -a lines=()
            while IFS= read -r line; do lines+=("$line"); done < "$hist_file"
            local total=${#lines[@]}

            if [[ "$2" == "clear" ]]; then
                rm "$hist_file"
                echo "History cleared."
                return 0
            fi

            if (( $# >= 2 )); then
                if [[ ! "$2" =~ ^[0-9]+$ ]]; then
                    echo "Usage: star history [N | clear]"
                    return 1
                fi
                local n="$2"
                if (( n < 1 || n > total )); then
                    echo "Out of range. History has $total entries."
                    return 1
                fi
                local idx=$((total - n))
                local palette="${lines[$idx]}"
                if [[ -f "$fav_file" ]] && grep -Fxq "$palette" "$fav_file"; then
                    echo "Already in favorites."
                    return 0
                fi
                mkdir -p "$(dirname "$fav_file")"
                echo "$palette" >> "$fav_file"
                local -a cs=($palette)
                rkt_set_color "${cs[0]}"; echo -n "★ "
                rkt_set_color "${cs[1]}"; echo -n "★ "
                rkt_set_color "${cs[2]}"; echo -n "★ "
                rkt_set_color "${cs[3]}"; echo -n "★ "
                rkt_set_color "${cs[4]}"; echo -n "★ "
                rkt_set_color "${cs[5]}"; echo -n "★"
                rkt_set_color normal
                printf '  saved to favorites from history #%s!\n' "$n"
                return 0
            fi

            local limit=20
            local shown=0
            local display_n
            for ((i=total-1; i>=0; i--)); do
                (( shown >= limit )) && break
                display_n=$((total - i))
                if (( display_n == 1 )); then
                    _rocket_print_star_row "$display_n" "${lines[$i]}" "(Current) 1. "
                else
                    _rocket_print_star_row "$display_n" "${lines[$i]}" "$(printf '        %3d. ' "$display_n")"
                fi
                ((shown++))
            done
            if (( total > limit )); then
                echo ""
                echo "(showing last $limit of $total; full log at $hist_file)"
            fi
            ;;

        show|preview)
            if (( $# < 7 )); then
                echo "Usage: star show <h1> <h2> <h3> <h4> <h5> <h6>"
                echo "Renders a mini rocket preview with the given 6-color palette."
                echo "Order: porthole, window, body, top, window-sides, flame."
                return 1
            fi
            local -a hexes
            if ! hexes=($(_star_validate_hexes "$2" "$3" "$4" "$5" "$6" "$7")); then
                echo "Invalid hex code. Each must be 6 hex digits (e.g., ff0066 or #ff0066)."
                return 1
            fi
            echo ""
            rkt_set_color "${hexes[0]}"; echo -n "  ★ Porthole      "; rkt_set_color normal; echo "  ${hexes[0]}"
            rkt_set_color "${hexes[1]}"; echo -n "  ★ Window        "; rkt_set_color normal; echo "  ${hexes[1]}"
            rkt_set_color "${hexes[2]}"; echo -n "  ★ Body          "; rkt_set_color normal; echo "  ${hexes[2]}"
            rkt_set_color "${hexes[3]}"; echo -n "  ★ Top           "; rkt_set_color normal; echo "  ${hexes[3]}"
            rkt_set_color "${hexes[4]}"; echo -n "  ★ Window-sides  "; rkt_set_color normal; echo "  ${hexes[4]}"
            rkt_set_color "${hexes[5]}"; echo -n "  ★ Flame         "; rkt_set_color normal; echo "  ${hexes[5]}"
            echo ""
            _star_preview_palette "${hexes[0]}" "${hexes[1]}" "${hexes[2]}" "${hexes[3]}" "${hexes[4]}" "${hexes[5]}"
            echo ""
            printf '  star add %s %s %s %s %s %s\n' "${hexes[0]}" "${hexes[1]}" "${hexes[2]}" "${hexes[3]}" "${hexes[4]}" "${hexes[5]}"
            echo "  (^ run that to save to favorites)"
            ;;

        add)
            if (( $# < 7 )); then
                echo "Usage: star add <h1> <h2> <h3> <h4> <h5> <h6> [<h1>..<h6> ...]"
                echo "Order: porthole, window, body, top, window-sides, flame."
                return 1
            fi
            local hex_count=$(($# - 1))
            if (( hex_count % 6 != 0 )); then
                echo "star add: expected a multiple of 6 hex codes, got $hex_count"
                return 1
            fi
            local palette_count=$((hex_count / 6))
            shift
            local -a all_hexes=()
            local raw cleaned pos=0
            for raw in "$@"; do
                pos=$((pos + 1))
                cleaned="${raw#\#}"
                if [[ ! "$cleaned" =~ ^[0-9a-fA-F]{6}$ ]]; then
                    echo "Invalid hex code at position $pos: $raw. Each must be 6 hex digits (e.g., ff0066 or #ff0066)."
                    return 1
                fi
                all_hexes+=("$cleaned")
            done
            mkdir -p "$(dirname "$fav_file")"
            local j idx palette
            for ((j=0; j<palette_count; j++)); do
                idx=$((j * 6))
                palette="${all_hexes[$idx]} ${all_hexes[$((idx+1))]} ${all_hexes[$((idx+2))]} ${all_hexes[$((idx+3))]} ${all_hexes[$((idx+4))]} ${all_hexes[$((idx+5))]}"
                echo "$palette" >> "$fav_file"
            done
            local total=$(wc -l < "$fav_file" | tr -d ' ')
            local start=$((total - palette_count + 1))
            for ((j=0; j<palette_count; j++)); do
                idx=$((j * 6))
                palette="${all_hexes[$idx]} ${all_hexes[$((idx+1))]} ${all_hexes[$((idx+2))]} ${all_hexes[$((idx+3))]} ${all_hexes[$((idx+4))]} ${all_hexes[$((idx+5))]}"
                _rocket_print_star_row "" "$palette" "Added favorite #$((start + j)): "
            done
            ;;

        explore|browse)
            local n=5
            if (( $# >= 2 )) && [[ "$2" =~ ^[0-9]+$ ]]; then
                n="$2"
            fi
            local has_rockets=false
            if (( n >= 800 )); then
                has_rockets=true
                _rkt_load_settings
                _RKT_ROCKET_PIDS=()
                _RKT_TERMINAL_THEME=$_rkt_terminal_theme
                trap 'rkt_rocket_cleanup; trap - INT; printf "\e[?25h"; kill -INT $$' INT
            fi
            echo ""
            local i
            for ((i=1; i<=n; i++)); do
                rkt_prng_seed
                local -a p=($(rkt_gen_rocket_palette))
                printf "%3d. " "$i"
                rkt_set_color "${p[0]}"; echo -n "★ "
                rkt_set_color "${p[1]}"; echo -n "★ "
                rkt_set_color "${p[2]}"; echo -n "★ "
                rkt_set_color "${p[3]}"; echo -n "★ "
                rkt_set_color "${p[4]}"; echo -n "★ "
                rkt_set_color "${p[5]}"; echo -n "★"
                rkt_set_color normal
                printf '  %s %s %s %s %s %s\n' "${p[0]}" "${p[1]}" "${p[2]}" "${p[3]}" "${p[4]}" "${p[5]}"
                if $has_rockets && (( i % 150 == 0 )); then
                    rkt_launch_rocket "$i"
                fi
            done
            if $has_rockets; then
                trap - INT
                rkt_rocket_cleanup
            fi
            echo ""
            echo "  star show <h1>..<h6>   preview a full rocket"
            echo "  star add  <h1>..<h6> [<h1>..<h6> ...]   save palette(s) to favorites"
            ;;

        weight|w)
            _rkt_load_settings
            if (( $# == 1 )); then
                echo "Favorite weight: $_rkt_favorite_weight%"
                echo ""
                echo "  Roughly $_rkt_favorite_weight out of every 100 new shells will roll"
                echo "  a saved favorite. The rest generate fresh palettes."
                echo ""
                echo "Usage: star weight <0-100>"
                echo "  0    = never use favorites (always fresh)"
                echo "  100  = always use favorites"
                return 0
            fi
            local n="$2"
            if [[ ! "$n" =~ ^[0-9]+$ ]]; then
                echo "Weight must be a number between 0 and 100."
                return 1
            fi
            if (( n < 0 || n > 100 )); then
                echo "Weight must be between 0 and 100."
                return 1
            fi
            _rkt_favorite_weight=$n
            _rkt_save_settings
            echo "Set favorite weight to $n%."
            ;;

        color|colors)
            _rkt_load_settings
            if (( $# == 1 )); then
                if [[ -z ${_RKT_BDY:-} ]]; then
                    echo "No active palette. Open a new tab first."
                    return 1
                fi
                echo ""
                rkt_set_color "$_RKT_TIP"; echo -n "  ★ Porthole      "; rkt_set_color normal; echo "  $_RKT_TIP"
                rkt_set_color "$_RKT_WIN"; echo -n "  ★ Window        "; rkt_set_color normal; echo "  $_RKT_WIN"
                rkt_set_color "$_RKT_BDY"; echo -n "  ★ Body          "; rkt_set_color normal; echo "  $_RKT_BDY"
                rkt_set_color "$_RKT_TOP"; echo -n "  ★ Top           "; rkt_set_color normal; echo "  $_RKT_TOP"
                rkt_set_color "$_RKT_SDS"; echo -n "  ★ Window-sides  "; rkt_set_color normal; echo "  $_RKT_SDS"
                rkt_set_color "$_RKT_FLM"; echo -n "  ★ Flame         "; rkt_set_color normal; echo "  $_RKT_FLM"
                echo ""
                _star_preview_palette "$_RKT_TIP" "$_RKT_WIN" "$_RKT_BDY" "$_RKT_TOP" "$_RKT_SDS" "$_RKT_FLM"
                return 0
            fi

            if [[ "$2" == "reset" ]]; then
                _rkt_random_star_mode=white
                _rkt_favorite_star_mode=gold
                _rkt_terminal_theme=dark
                _rkt_save_settings
                echo "Reset: theme=dark, random=white, favorite=gold"
                return 0
            fi

            if (( $# < 3 )); then
                echo "Usage: star color <theme|random|favorite> <value>"
                return 1
            fi

            local ctx="$2" val="$3"
            case "$ctx" in
                theme)
                    if [[ "$val" != dark && "$val" != light ]]; then
                        echo "Theme must be 'dark' or 'light'."
                        return 1
                    fi
                    _rkt_terminal_theme="$val"
                    _rkt_save_settings
                    echo "Set terminal theme to $val."
                    ;;
                random)
                    if [[ "$val" != white && "$val" != gold && "$val" != neon ]]; then
                        echo "Random mode must be 'white' or 'neon'."
                        return 1
                    fi
                    _rkt_random_star_mode="$val"
                    _rkt_save_settings
                    if [[ "$val" == gold ]]; then
                        echo "Set random-palette stars to $val. :)"
                    else
                        echo "Set random-palette stars to $val."
                    fi
                    ;;
                favorite|favorites|fav)
                    if [[ "$val" != white && "$val" != gold && "$val" != neon ]]; then
                        echo "Favorite mode must be 'gold' or 'neon'."
                        return 1
                    fi
                    _rkt_favorite_star_mode="$val"
                    _rkt_save_settings
                    if [[ "$val" == white ]]; then
                        echo "Set favorite-palette stars to $val. :)"
                    else
                        echo "Set favorite-palette stars to $val."
                    fi
                    ;;
                *)
                    echo "Context must be 'theme', 'random', or 'favorite'."
                    return 1
                    ;;
            esac
            ;;

        update)
            if [[ "$2" == "cantaloupe" ]]; then
                _rkt_load_settings
                _rkt_channel=cantaloupe
                _rkt_save_settings
                echo "Switched to cantaloupe channel. Use 'star update' to pull the latest cantaloupe build."
                return 0
            fi
            if [[ "$2" == "stable" ]]; then
                _rkt_load_settings
                _rkt_channel=main
                _rkt_save_settings
                echo "Switched to the stable channel."
                return 0
            fi
            if ! command -v curl >/dev/null 2>&1; then
                echo "curl is required for star update."
                return 1
            fi
            _rkt_load_settings
            local branch="main"
            [[ "$_rkt_channel" == "cantaloupe" ]] && branch="cantaloupe"
            local remote_version=$(curl -fsSL --max-time 5 "https://raw.githubusercontent.com/clefspear/starcommand/${branch}/VERSION" 2>/dev/null)
            if [[ -z $remote_version ]]; then
                echo "Failed to check for updates. Visit https://github.com/clefspear/starcommand/releases"
                return 1
            fi
            if [[ "$remote_version" == "$_RKT_VERSION" ]]; then
                echo "starcommand is already up to date (v$_RKT_VERSION)."
                return 0
            fi
            echo "starcommand v$remote_version is available. Update now? [y/n]"
            read -r _rkt_response
            if [[ "$_rkt_response" != "y" && "$_rkt_response" != "Y" ]]; then
                echo "Update cancelled."
                return 0
            fi
            local script_path="${BASH_SOURCE[0]}"
            if [[ -z $script_path ]]; then
                echo "Cannot determine script path. Update manually."
                return 1
            fi
            local temp_file
            temp_file=$(mktemp 2>/dev/null) || temp_file="/tmp/starcommand_update.$$"
            local dl_url="https://raw.githubusercontent.com/clefspear/starcommand/${branch}/bash/starcommand.sh"
            echo "Downloading: $dl_url"
            local http_code
            http_code=$(curl -sS -L --max-time 10 -w '%{http_code}' -o "$temp_file" "$dl_url" 2>/dev/null)
            local curl_exit=$?
            echo "HTTP $http_code, curl exit $curl_exit"
            if [[ "$http_code" != "200" ]]; then
                echo "Download failed. Update aborted."
                rm -f "$temp_file"
                return 1
            fi
            cp "$script_path" "${script_path}.bak"
            mv "$temp_file" "$script_path"
            echo "Updated to v$remote_version. Open a new tab to take effect."
            rm -f "$_RKT_UPDATE_CACHE"
            ;;

        help|-h|--help)
            _rkt_load_settings
            if [[ "$_rkt_channel" == "cantaloupe" ]]; then
                echo "starcommand v${_RKT_VERSION}-cantaloupe"
            else
                echo "starcommand v$_RKT_VERSION"
            fi
            echo ""
            echo "star                          save current palette to favorites"
            echo "star list                     show all favorites"
            echo "star remove N                 delete favorite #N"
            echo ""
            echo "star history                  show last 20 palettes (most recent first)"
            echo "star history N                save palette #N from history to favorites"
            echo "star history clear            wipe history"
            echo ""
echo "star show H1..H6              preview a custom palette (mini rocket)"
echo "star add  H1..H6 [H1..H6 ...] add one or more palettes to favorites"
echo "star explore [N]              browse N random palettes (default 5)"
            echo ""
            echo "star color                    show current palette preview"
            echo -n "star color theme <d|l>        terminal theme: "
            _rkt_print_option "$_rkt_terminal_theme" dark light
            echo
            echo -n "star color random <mode>      random-palette stars: "
            _rkt_print_option "$_rkt_random_star_mode" white neon
            echo
            echo -n "star color favorite <mode>    favorite-palette stars: "
            _rkt_print_option "$_rkt_favorite_star_mode" gold neon
            echo
            echo -n "star weight <0-100>           ratio of favorites to random rockets. Currently: "
            rkt_set_color --bold --italics
            echo -n "$_rkt_favorite_weight%"
            rkt_set_color normal
            echo
            echo "star color reset              restore defaults"
            echo ""
            echo "star update                   update to the latest version"
            if [[ "$_rkt_channel" == "cantaloupe" ]]; then
                echo "star update stable            switch back to the stable channel"
            fi
                echo "star supernova                 remove starcommand from this system"
            echo ""
            echo "  Favorites: $fav_file"
            echo "  History:   $hist_file (last 100 launches)"
            echo "  Settings:  $HOME/.config/bash/rocket_settings.sh"
            ;;

        supernova)
            echo "Are you sure you want to uninstall starcommand? [y/N]"
            read -r _rkt_response
            if [[ "$_rkt_response" != "y" && "$_rkt_response" != "Y" ]]; then
                echo "Uninstall cancelled."
                return 0
            fi
            echo "Keep your favorites and history? [Y/n]"
            read -r _rkt_response
            local keep=true
            if [[ "$_rkt_response" == "n" || "$_rkt_response" == "N" ]]; then
                keep=false
            fi
            local sed_opt="-i"
            [[ "$(uname -s)" == "Darwin" ]] && sed_opt="-i ''"
            for f in "$HOME/.bashrc" "$HOME/.bash_profile"; do
                [[ -f "$f" ]] && eval sed "$sed_opt" '/starcommand\.sh/d; /# >>> starcommand >>>/,/# <<< starcommand <<</d' "$f"
            done
            local script_path="${BASH_SOURCE[0]}"
            [[ -n "$script_path" && -f "$script_path" ]] && rm -f "$script_path"
            rm -f "$_RKT_UPDATE_CACHE"
            if $keep; then
                echo "starcommand uninstalled. Favorites, history, and settings kept at ~/.config/bash/"
            else
                rm -f "$HOME/.config/bash/rocket_favorites.txt" "$HOME/.config/bash/rocket_history.txt" "$HOME/.config/bash/rocket_settings.sh"
                echo "starcommand has been uninstalled."
            fi
            return 0
            ;;

        *)
            echo "Unknown subcommand: $1"
            echo "Try: star, star list, star show, star add, star explore, star color, star weight, star update, star supernova, star help"
            return 1
            ;;
    esac
}

# ── Greeting helpers ───────────────────────────────────────────────────────────

welcome_message() {
    local cols prefix_len available value
    cols=$(_rkt_cols)
    prefix_len=19
    available=$((cols - prefix_len - 2))
    value="Welcome Aboard, Captain $(whoami)!"
    if [[ ${#value} -gt $available ]]; then
        echo -n "${value:0:$((available - 1))}…"
    else
        echo -n "Welcome Aboard, "
        rkt_set_color "$_RKT_BDY"
        echo -n "Captain "
        rkt_set_color FFF
        echo -n "$(whoami)!"
    fi
    rkt_set_color normal
}

show_date_info() {
    local cols prefix_len available value up_time
    cols=$(_rkt_cols)
    prefix_len=19
    available=$((cols - prefix_len - 2))
    up_time=$(uptime | awk -F '(up |,)' '{print $2}' | sed 's/^ *//g')
    value="Today is $(date +%Y.%m.%d), we are up and running for $up_time."
    if [[ ${#value} -gt $available ]]; then
        echo -n "${value:0:$((available - 1))}…"
    else
        echo -n "Today is "
        rkt_set_color cyan
        echo -n "$(date +%Y.%m.%d)"
        rkt_set_color normal
        echo -n ", we are up and running for "
        rkt_set_color cyan
        echo -n "$up_time"
        rkt_set_color normal
        echo -n "."
    fi
    rkt_set_color normal
}

_rkt_cols() {
    tput cols 2>/dev/null || echo 80
}

show_os_info() {
    local cols prefix_len available value
    cols=$(_rkt_cols)
    prefix_len=28
    available=$((cols - prefix_len - 2))
    value="$_rkt_os"
    rkt_set_color yellow
    echo -en "\tOS: "
    rkt_set_color 0F0
    if [[ ${#value} -gt $available ]]; then
        echo -n "${value:0:$((available - 1))}…"
    else
        echo -n "$value"
    fi
    rkt_set_color normal
}

show_cpu_info() {
    local cols prefix_len available value
    cols=$(_rkt_cols)
    prefix_len=29
    available=$((cols - prefix_len - 2))
    value="$_rkt_cpu"
    rkt_set_color yellow
    echo -en "\tCPU: "
    rkt_set_color 0F0
    if [[ ${#value} -gt $available ]]; then
        echo -n "${value:0:$((available - 1))}…"
    else
        echo -n "$value"
    fi
    rkt_set_color normal
}

show_mem_info() {
    local cols prefix_len available value
    cols=$(_rkt_cols)
    prefix_len=32
    available=$((cols - prefix_len - 2))
    value="$_rkt_mem"
    rkt_set_color yellow
    echo -en "\tMemory: "
    rkt_set_color 0F0
    if [[ ${#value} -gt $available ]]; then
        echo -n "${value:0:$((available - 1))}…"
    else
        echo -n "$value"
    fi
    rkt_set_color normal
}

show_net_info() {
    local cols prefix_len available value
    cols=$(_rkt_cols)
    prefix_len=29
    available=$((cols - prefix_len - 2))
    value="IP Address: $_rkt_ip, Default Gateway: $_rkt_gw"
    rkt_set_color yellow
    echo -en "\tNet: "
    rkt_set_color 0F0
    if [[ ${#value} -gt $available ]]; then
        echo -n "${value:0:$((available - 1))}…"
    else
        echo -n "$value"
    fi
    rkt_set_color normal
}

# ── Main greeting ──────────────────────────────────────────────────────────────

rkt_starcommand() {
    if [[ $1 == "--seed" && -n $2 ]]; then
        _RKT_PRNG_STATE=$2
    elif [[ $1 != "--greeting" ]]; then
        rkt_prng_seed
    fi

    _rkt_load_settings
    if [[ -z "${_RKT_AUTO_UPDATE_CHECK:-}" ]]; then
        echo -n "starcommand: Allow starcommand to check Github periodically for future updates? [Y/N] "
        read -r _rkt_response
        if [[ "$_rkt_response" == "y" || "$_rkt_response" == "Y" ]]; then
            _RKT_AUTO_UPDATE_CHECK="yes"
        else
            _RKT_AUTO_UPDATE_CHECK="no"
        fi
        _rkt_save_settings
    fi
    _RKT_TERMINAL_THEME=$_rkt_terminal_theme

    local -a colors
    colors=($(_rocket_pick_palette))
    _RKT_TIP=${colors[0]}
    _RKT_WIN=${colors[1]}
    _RKT_BDY=${colors[2]}
    _RKT_TOP=${colors[3]}
    _RKT_SDS=${colors[4]}
    _RKT_FLM=${colors[5]}

    _RKT_PALETTE_BYTES=(
        $((16#${_RKT_TIP:0:2})) $((16#${_RKT_TIP:2:2})) $((16#${_RKT_TIP:4:2}))
        $((16#${_RKT_WIN:0:2})) $((16#${_RKT_WIN:2:2})) $((16#${_RKT_WIN:4:2}))
        $((16#${_RKT_BDY:0:2})) $((16#${_RKT_BDY:2:2})) $((16#${_RKT_BDY:4:2}))
        $((16#${_RKT_TOP:0:2})) $((16#${_RKT_TOP:2:2})) $((16#${_RKT_TOP:4:2}))
        $((16#${_RKT_SDS:0:2})) $((16#${_RKT_SDS:2:2})) $((16#${_RKT_SDS:4:2}))
        $((16#${_RKT_FLM:0:2})) $((16#${_RKT_FLM:2:2})) $((16#${_RKT_FLM:4:2}))
    )

    _ROCKET_STARS=($(rkt_compute_star_positions))

    if _palette_is_favorite; then
        _RKT_STAR_MODE=$_rkt_favorite_star_mode
    else
        _RKT_STAR_MODE=$_rkt_random_star_mode
    fi

    local show_sysinfo=false
    if [[ $1 == "--greeting" || $1 == "" || $1 == "--seed" ]]; then
        show_sysinfo=true
    fi

    if $show_sysinfo; then
        _rkt_hw_info
        _rkt_net_info
    fi

    _rkt_update_check_background

    echo ""

    rkt_render_row 0 "                  " "                  "
    echo

    if $show_sysinfo; then
        rkt_render_row 1 "        |         " "        b         "
        echo -n " "; welcome_message; echo

        rkt_render_row 2 "       / \\        " "       t t        "
        echo

        rkt_render_row 3 "      / _ \\       " "      t t t       "
        echo -n " "; show_date_info; echo

        rkt_render_row 4 "     |.o '.|      " "     swp wws      "
        echo

        rkt_render_row 5 "     |'._.'|      " "     swwwwws      "
        echo " Space Vessel:"

        rkt_render_row 6 "     |     |      " "     b     b      "
        echo -n " "; show_os_info; echo

        rkt_render_row 7 "   ,'|  |  |\`.    " "   ssb  b  bss    "
        echo -n " "; show_cpu_info; echo

        rkt_render_row 8 "  /  |  |  |  \\   " "  s  b  b  b  s   "
        echo -n " "; show_mem_info; echo

        rkt_render_row 9 "  |,-'--|--'-.|   " "  bsssttbttsssb   "
        echo -n " "; show_net_info; echo
    else
        for ((i=0; i<${#ROCKET_ART[@]}; i++)); do
            rkt_render_row $((i+1)) "${ROCKET_ART[$i]}" "${ROCKET_ROLE[$i]}"
            echo
        done
    fi

    rkt_render_flame
    echo

    rkt_render_row 11 "                  " "                  "
    echo

    if $show_sysinfo; then
        echo
        rkt_set_color grey
        echo "Have a Nice Trip!"
        rkt_set_color normal
        _rkt_update_check_nudge
    fi
}

# If the script is sourced, just define functions (no auto-run)
# If run directly, execute once
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    rkt_starcommand "$@"
fi

# Auto-run in interactive shells
if [[ $- == *i* ]] && [[ -t 1 ]]; then
    rkt_starcommand
fi
