#!/usr/bin/env bash
# starcommand.sh — Portable rocket greeting for Bash
# Implements xorshift32 PRNG for cross-shell deterministic output

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

rkt_djb2() {
    local str=$1 h=5381 i c
    for ((i=0; i<${#str}; i++)); do
        printf -v c '%d' "'${str:$i:1}"
        h=$(( ((h << 5) + h + c) & 0xFFFFFFFF ))
    done
    (( h == 0 )) && h=1
    echo $h
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

# ── Globals (set on each greeting) ─────────────────────────────────────────────

_RKT_TIP=
_RKT_WIN=
_RKT_BDY=
_RKT_TOP=
_RKT_SDS=
_RKT_FLM=
_RKT_STAR_MODE=white
_RKT_TERMINAL_THEME=dark

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
    local all_bytes=($(rkt_palette_bytes))
    local b i1 i2
    for b in "${all_bytes[@]}"; do
        i1=$((b % total))
        i2=$(((b + 73) % total))
        echo "${_RKT_STAR_CANDIDATES[$i1]}"
        echo "${_RKT_STAR_CANDIDATES[$i2]}"
    done | sort -u -t: -k1,1n -k2,2n
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
    local all_bytes idx pattern
    all_bytes=($(rkt_palette_bytes))
    idx=$((all_bytes[0] % ${#FLAME_PATTERNS[@]}))
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
    mkdir -p "$(dirname "$file")"
    echo "$*" >> "$file"
    local lc=$(wc -l < "$file" | tr -d ' ')
    if (( lc > 100 )); then
        tail -n 100 "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    fi
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
    [[ -f "$cfg" ]] && source "$cfg"
}

_rkt_save_settings() {
    local cfg="$HOME/.config/bash/rocket_settings.sh"
    mkdir -p "$(dirname "$cfg")"
    printf '_rkt_random_star_mode=%s\n'   "$_rkt_random_star_mode"    > "$cfg"
    printf '_rkt_favorite_star_mode=%s\n' "$_rkt_favorite_star_mode" >> "$cfg"
    printf '_rkt_terminal_theme=%s\n'     "$_rkt_terminal_theme"     >> "$cfg"
    printf '_rkt_favorite_weight=%s\n'    "$_rkt_favorite_weight"    >> "$cfg"
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
        mem_str=$(free -h 2>/dev/null | grep "Mem" | tr -s ' ' | cut -d ' ' -f 2)
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
        ip=$(ifconfig 2>/dev/null | grep -v "127.0.0.1" | grep "inet " | head -1 | cut -d " " -f2)
        gw=$(netstat -nr 2>/dev/null | grep -E "default.*UGSc" | cut -d " " -f13)
    elif [[ "$os_type" == "Linux" ]]; then
        ip=$(ip address show 2>/dev/null | grep -E "inet .* brd .* dynamic" | head -1 | awk '{print $2}' | cut -d/ -f1)
        gw=$(ip route 2>/dev/null | grep default | awk '{print $3}')
    fi
    printf '_rkt_ip="%s"\n' "$ip" > "$cache"
    printf '_rkt_gw="%s"\n' "$gw" >> "$cache"
    source "$cache"
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
                echo "Usage: star add <h1> <h2> <h3> <h4> <h5> <h6>"
                echo "Order: porthole, window, body, top, window-sides, flame."
                return 1
            fi
            local -a hexes
            if ! hexes=($(_star_validate_hexes "$2" "$3" "$4" "$5" "$6" "$7")); then
                echo "Invalid hex code. Each must be 6 hex digits (e.g., ff0066 or #ff0066)."
                return 1
            fi
            local palette="${hexes[0]} ${hexes[1]} ${hexes[2]} ${hexes[3]} ${hexes[4]} ${hexes[5]}"
            if [[ -f "$fav_file" ]] && grep -Fxq "$palette" "$fav_file"; then
                echo "Already in favorites."
                return 0
            fi
            mkdir -p "$(dirname "$fav_file")"
            echo "$palette" >> "$fav_file"
            rkt_set_color "${hexes[0]}"; echo -n "★ "
            rkt_set_color "${hexes[1]}"; echo -n "★ "
            rkt_set_color "${hexes[2]}"; echo -n "★ "
            rkt_set_color "${hexes[3]}"; echo -n "★ "
            rkt_set_color "${hexes[4]}"; echo -n "★ "
            rkt_set_color "${hexes[5]}"; echo -n "★"
            rkt_set_color normal
            local total=$(wc -l < "$fav_file" | tr -d ' ')
            printf '  added to favorites! (%s total)\n' "$total"
            ;;

        explore|browse)
            local n=5
            if (( $# >= 2 )) && [[ "$2" =~ ^[0-9]+$ ]]; then
                n="$2"
            fi
            echo ""
            local i p1 p2 p3 p4 p5 p6
            for ((i=1; i<=n; i++)); do
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
            done
            echo ""
            echo "  star show <h1>..<h6>   preview a full rocket"
            echo "  star add  <h1>..<h6>   save directly to favorites"
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

        help|-h|--help)
            _rkt_load_settings
            echo "star                          save current palette to favorites"
            echo "star list                     show all favorites"
            echo "star remove N                 delete favorite #N"
            echo ""
            echo "star history                  show last 20 palettes (most recent first)"
            echo "star history N                save palette #N from history to favorites"
            echo "star history clear            wipe history"
            echo ""
            echo "star show H1..H6              preview a custom palette (mini rocket)"
            echo "star add  H1..H6              add a custom palette directly to favorites"
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
            echo "  Favorites: $fav_file"
            echo "  History:   $hist_file (last 100 launches)"
            echo "  Settings:  $HOME/.config/bash/rocket_settings.sh"
            ;;

        *)
            echo "Unknown subcommand: $1"
            echo "Try: star, star list, star show, star add, star explore, star color, star weight, star help"
            return 1
            ;;
    esac
}

# ── Greeting helpers ───────────────────────────────────────────────────────────

welcome_message() {
    echo -n "Welcome Aboard, "
    rkt_set_color "$_RKT_BDY"
    echo -n "Captain "
    rkt_set_color FFF
    echo -n "$(whoami)!"
    rkt_set_color normal
}

show_date_info() {
    local up_time=$(uptime | awk -F '(up |,)' '{print $2}' | sed 's/^ *//g')
    echo -n "Today is "
    rkt_set_color cyan
    echo -n "$(date +%Y.%m.%d)"
    rkt_set_color normal
    echo -n ", we are up and running for "
    rkt_set_color cyan
    echo -n "$up_time"
    rkt_set_color normal
    echo -n "."
}

show_os_info() {
    rkt_set_color yellow
    echo -en "\tOS: "
    rkt_set_color 0F0
    echo -n "$_rkt_os"
    rkt_set_color normal
}

show_cpu_info() {
    rkt_set_color yellow
    echo -en "\tCPU: "
    rkt_set_color 0F0
    echo -n "$_rkt_cpu"
    rkt_set_color normal
}

show_mem_info() {
    rkt_set_color yellow
    echo -en "\tMemory: "
    rkt_set_color 0F0
    echo -n "$_rkt_mem"
    rkt_set_color normal
}

show_net_info() {
    rkt_set_color yellow
    echo -en "\tNet: "
    rkt_set_color 0F0
    echo -n "IP Address: $_rkt_ip, Default Gateway: $_rkt_gw"
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
    _RKT_TERMINAL_THEME=$_rkt_terminal_theme

    local -a colors
    colors=($(_rocket_pick_palette))
    _RKT_TIP=${colors[0]}
    _RKT_WIN=${colors[1]}
    _RKT_BDY=${colors[2]}
    _RKT_TOP=${colors[3]}
    _RKT_SDS=${colors[4]}
    _RKT_FLM=${colors[5]}

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
