#!/usr/bin/env bash
# starcommand.sh — Portable rocket greeting for Bash
# Implements xorshift32 PRNG for cross-shell deterministic output

# ── Portable PRNG ──────────────────────────────────────────────────────────────

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

rkt_seed() {
    local hostname date_str seed
    hostname=$(hostname -s 2>/dev/null || echo "localhost")
    hostname=$(printf '%s' "$hostname" | tr '[:upper:]' '[:lower:]')
    date_str=$(date +%Y.%m.%d)
    seed=$(rkt_djb2 "$hostname.$date_str")
    echo "$seed"
    echo "$hostname.$date_str"
}

rkt_random() {
    local state=$1 min=$2 max=$3 range val
    state=$(rkt_xorshift32 "$state")
    range=$((max - min + 1))
    val=$((min + (state % range)))
    echo "$state"
    echo "$val"
}

# ── Color utilities ────────────────────────────────────────────────────────────

rkt_set_color() {
    local hex=$1 r g b
    [[ $hex == "normal" || $hex == "reset" ]] && { printf '\e[m'; return; }
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
    r=$((16#${hex:0:2}))
    g=$((16#${hex:2:2}))
    b=$((16#${hex:4:2}))
    printf '\e[38;2;%d;%d;%dm' "$r" "$g" "$b"
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

# ── Globals (set on each greeting) ─────────────────────────────────────────────

_RKT_TIP=
_RKT_WIN=
_RKT_BDY=
_RKT_TOP=
_RKT_SDS=
_RKT_FLM=
_RKT_STAR_MODE=white
_RKT_TERMINAL_THEME=dark
_RKT_FAVORITE_STAR_MODE=gold
_RKT_RANDOM_STAR_MODE=white
_RKT_FAVORITE_WEIGHT=20

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

# ── Star color ─────────────────────────────────────────────────────────────────

rkt_star_color_for_mode() {
    case $_RKT_STAR_MODE in
        gold)
            if [[ $_RKT_TERMINAL_THEME == light ]]; then
                echo B8860B
            else
                echo FFE600
            fi
            ;;
        neon)
            if [[ $_RKT_TERMINAL_THEME == light ]]; then
                echo "${NEON_COLORS_LIGHT[$RANDOM % ${#NEON_COLORS_LIGHT[@]}]}"
            else
                echo "${NEON_COLORS[$RANDOM % ${#NEON_COLORS[@]}]}"
            fi
            ;;
        *)
            if [[ $_RKT_TERMINAL_THEME == light ]]; then
                echo 333333
            else
                echo FFFFFF
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
            rkt_set_color "$(rkt_star_color_for_mode)"
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
    local state=$1 result h_base scheme sat light
    result=($(rkt_random "$state" 0 359))
    state=${result[0]}; h_base=${result[1]}
    result=($(rkt_random "$state" 0 4))
    state=${result[0]}; scheme=${result[1]}
    result=($(rkt_random "$state" 65 90))
    state=${result[0]}; sat=${result[1]}
    result=($(rkt_random "$state" 55 72))
    state=${result[0]}; light=${result[1]}

    local offs
    case $scheme in
        0) offs=(0 60 120 180 240 300) ;;
        1) offs=(0 50 110 180 230 290) ;;
        2) offs=(0 70 130 200 250 310) ;;
        3) offs=(0 45 115 180 235 295) ;;
        *) offs=(0 65 125 190 245 310) ;;
    esac

    local colors=() h off
    for off in "${offs[@]}"; do
        h=$(((h_base + off) % 360))
        colors+=($(rkt_hsl_to_hex "$h" "$sat" "$light"))
    done

    echo "$state"
    printf '%s\n' "${colors[@]}"
}

# ── System info (stub for parity testing) ──────────────────────────────────────

# ── Main greeting ──────────────────────────────────────────────────────────────

rkt_starcommand() {
    local override_seed=${1:-0}
    local -a override_palette=()
    if [[ $# -ge 7 ]]; then
        override_palette=("${@:2:6}")
    fi

    local seed seed_str
    if [[ $override_seed -ne 0 ]]; then
        seed=$override_seed
        seed_str=override
    else
        local seed_info
        seed_info=($(rkt_seed))
        seed=${seed_info[0]}
        seed_str=${seed_info[1]}
    fi

    local state=$seed

    local -a colors
    if [[ ${#override_palette[@]} -eq 6 ]]; then
        colors=("${override_palette[@]}")
    else
        local palette_result
        palette_result=($(rkt_gen_rocket_palette "$state"))
        state=${palette_result[0]}
        colors=("${palette_result[@]:1}")
    fi

    _RKT_TIP=${colors[0]}
    _RKT_WIN=${colors[1]}
    _RKT_BDY=${colors[2]}
    _RKT_TOP=${colors[3]}
    _RKT_SDS=${colors[4]}
    _RKT_FLM=${colors[5]}

    _ROCKET_STARS=($(rkt_compute_star_positions))

    rkt_render_row 0 "                  " "                  "
    echo

    for ((i=0; i<${#ROCKET_ART[@]}; i++)); do
        rkt_render_row $((i+1)) "${ROCKET_ART[$i]}" "${ROCKET_ROLE[$i]}"
        echo
    done

    rkt_render_flame
    echo

    rkt_render_row 11 "                  " "                  "
    echo
}

# If the script is sourced, just define functions (no auto-run)
# If run directly, execute once
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    rkt_starcommand "$@"
fi
