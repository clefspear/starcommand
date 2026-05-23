# Created By: Peter Azmy
# zsh_greeting.zsh — Rocketfish zsh port
# Deterministic rocket + starfield greeting for zsh
# Ported from fish_greeting.fish

_RKT_VERSION="1.1.0"
_RKT_UPDATE_CACHE="$HOME/.config/zsh/rocket_update_check"

_rkt_update_check_background() {
  [[ -n ${STARCOMMAND_NO_UPDATE_CHECK:-} ]] && return
  [[ "${_RKT_AUTO_UPDATE_CHECK:-}" == "yes" ]] || return
  [[ -t 1 ]] || return
  mkdir -p "$HOME/.config/zsh"
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
  ( curl -fsSL --max-time 3 "https://raw.githubusercontent.com/clefspear/starcommand/main/VERSION" 2>/dev/null \
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
  _rkt_set_color grey
  echo "(starcommand v$cached_version available — run 'star update' — https://github.com/clefspear/starcommand/blob/main/CHANGELOG.md)"
  _rkt_set_color normal
}

#
# Install:
#   curl -fsSL https://raw.githubusercontent.com/clefspear/starcommand/main/zsh/zsh_greeting.zsh | zsh
#
# Or source manually from .zshrc:
#   source ~/.config/zsh/zsh_greeting.zsh

# ── Portable xorshift32 PRNG ───────────────────────────────────────────────────

_RKT_PRNG_STATE=0

_rkt_xorshift32() {
  emulate -L zsh
  local s=$1
  s=$(( (s ^ (s << 13)) & 0xFFFFFFFF ))
  s=$(( (s ^ (s >> 17)) & 0xFFFFFFFF ))
  s=$(( (s ^ (s << 5)) & 0xFFFFFFFF ))
  echo $s
}

_rkt_prng_seed() {
  emulate -L zsh
  while true; do
    typeset -g _RKT_PRNG_STATE=$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')
    (( _RKT_PRNG_STATE != 0 )) && break
  done
}

_rkt_prng_range() {
  emulate -L zsh
  local min=$1 max=$2 range
  _RKT_PRNG_STATE=$(( ( (_RKT_PRNG_STATE ^ (_RKT_PRNG_STATE << 13)) & 0xFFFFFFFF ) ))
  _RKT_PRNG_STATE=$(( ( (_RKT_PRNG_STATE ^ (_RKT_PRNG_STATE >> 17)) & 0xFFFFFFFF ) ))
  _RKT_PRNG_STATE=$(( ( (_RKT_PRNG_STATE ^ (_RKT_PRNG_STATE << 5)) & 0xFFFFFFFF ) ))
  range=$((max - min + 1))
  _RKT_PRNG_RET=$((min + (_RKT_PRNG_STATE % range)))
}

_rkt_set_color() {
  local bold=false italic=false
  local args=()
  for arg in "$@"; do
    case "$arg" in
      --bold) bold=true ;;
      --italics) italic=true ;;
      normal|reset) printf '\e[m'; return ;;
      *) args+=("$arg") ;;
    esac
  done
  local codes=()
  $bold && codes+=('1')
  $italic && codes+=('3')
  if (( ${#args[@]} > 0 )); then
    local hex="${args[1]}"
    case "$hex" in
      grey)   hex="808080" ;;
      cyan)   hex="00FFFF" ;;
      yellow) hex="FFFF00" ;;
      0F0)    hex="00FF00" ;;
      FFF)    hex="FFFFFF" ;;
      [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])
        hex="${hex:0:1}${hex:0:1}${hex:1:1}${hex:1:1}${hex:2:1}${hex:2:1}" ;;
    esac
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    codes+=("38;2;$r;$g;$b")
  fi
  local IFS=';'
  printf '\e[%sm' "${codes[*]}"
}

_hsl_to_hex() {
  printf '%s %s %s\n' "$1" "$2" "$3" | awk '{
    h = $1; s = $2; l_in = $3
    sat = s / 100
    light = l_in / 100
    c = (1 - (2*light - 1 < 0 ? -(2*light - 1) : 2*light - 1)) * sat
    hp = h / 60
    x = (hp - 2*int(hp/2) - 1)
    if (x < 0) x = -x
    x = 1 - x
    x = c * x
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

_rkt_load_settings() {
  emulate -L zsh
  local cfg="$HOME/.config/zsh/rocket_settings.zsh"
  typeset -g _rkt_random_star_mode=white
  typeset -g _rkt_favorite_star_mode=gold
  typeset -g _rkt_terminal_theme=dark
  typeset -g _rkt_favorite_weight=20
  typeset -g _RKT_AUTO_UPDATE_CHECK=""
  [[ -f "$cfg" ]] && source "$cfg"
}

_rkt_save_settings() {
  emulate -L zsh
  local cfg="$HOME/.config/zsh/rocket_settings.zsh"
  mkdir -p "${cfg:h}"
  printf 'typeset -g _rkt_random_star_mode=%s\n'   "${(q)_rkt_random_star_mode}"    > "$cfg"
  printf 'typeset -g _rkt_favorite_star_mode=%s\n' "${(q)_rkt_favorite_star_mode}" >> "$cfg"
  printf 'typeset -g _rkt_terminal_theme=%s\n'     "${(q)_rkt_terminal_theme}"     >> "$cfg"
  printf 'typeset -g _rkt_favorite_weight=%s\n'    "${(q)_rkt_favorite_weight}"    >> "$cfg"
  printf 'typeset -g _RKT_AUTO_UPDATE_CHECK=%s\n'  "${(q)_RKT_AUTO_UPDATE_CHECK}"  >> "$cfg"
}

_rkt_print_option() {
  emulate -L zsh
  local active="$1"
  shift
  local -a opts=("$@")
  printf '('
  local first=1
  for opt in "${opts[@]}"; do
    (( first == 0 )) && printf ' | '
    first=0
    if [[ "$active" == "$opt" ]]; then
      _rkt_set_color --bold --italics
      printf '%s' "$opt"
      _rkt_set_color normal
    else
      printf '%s' "$opt"
    fi
  done
  printf ')'
}

_gen_rocket_palette() {
  emulate -L zsh
  typeset -g -a _RKT_GEN_PALETTE=()
  _rkt_prng_range 0 359; local h_base=$_RKT_PRNG_RET
  _rkt_prng_range 0 4; local scheme=$_RKT_PRNG_RET
  _rkt_prng_range 65 90; local sat=$_RKT_PRNG_RET
  _rkt_prng_range 55 72; local light=$_RKT_PRNG_RET
  local -a offs
  case $scheme in
    0) offs=(0 60 120 180 240 300) ;;
    1) offs=(0 50 110 180 230 290) ;;
    2) offs=(0 70 130 200 250 310) ;;
    3) offs=(0 45 115 180 235 295) ;;
    *) offs=(0 65 125 190 245 310) ;;
  esac
  local -a lines=()
  for off in "${offs[@]}"; do
    lines+=("$(( (h_base + off) % 360 )) $sat $light")
  done
  _RKT_GEN_PALETTE=("${(@f)$(printf '%s\n' "${lines[@]}" | awk '{
    h = $1; s = $2; l_in = $3
    sat = s / 100
    light = l_in / 100
    c = (1 - (2*light - 1 < 0 ? -(2*light - 1) : 2*light - 1)) * sat
    hp = h / 60
    x = (hp - 2*int(hp/2) - 1)
    if (x < 0) x = -x
    x = 1 - x
    x = c * x
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
  }')}")
}

_rocket_record_history() {
  emulate -L zsh
  local file="$HOME/.config/zsh/rocket_history.txt"
  local lock="$file.lock"
  mkdir -p "${file:h}"
  local waited=0
  while ! mkdir "$lock" 2>/dev/null; do
    sleep 0.05
    (( waited++ < 20 )) || return 1
  done
  trap 'rmdir "$lock" 2>/dev/null' EXIT
  echo "${(j: :)@}" >> "$file"
  local lc=$(wc -l < "$file")
  if (( lc > 100 )); then
    tail -n 100 "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  fi
  rmdir "$lock" 2>/dev/null
  trap - EXIT
}

_rkt_neon_color() {
  emulate -L zsh
  local -a neons=(
    FF0033 FF3300 FF6600 FF9900 FFBB00 FFDD00 FFFF00
    CCFF00 99FF00 66FF00 33FF00 00FF33 00FF66 00FF99
    00FFCC 00FFFF 00CCFF 0099FF 0066FF 0033FF 3300FF
    6600FF 9900FF CC00FF FF00FF FF00CC FF0099 FF0066
  )
  _rkt_prng_range 1 ${#neons}
  _RKT_PRNG_RET="${neons[$_RKT_PRNG_RET]}"
}


_rkt_neon_color_light() {
  emulate -L zsh
  local -a neons=(
    CC0029 CC2900 CC5200 CC7A00 CC9500 B8860B AAAA00
    88AA00 668800 448800 228822 228B22 008844 008866
    008B7F 008B8B 0077AA 1E6FB8 0055CC 0033AA 2200AA
    4B0082 6622AA 7B1FA2 A020A0 AA0088 AD1457 AA0044
  )
  _rkt_prng_range 1 ${#neons}
  _RKT_PRNG_RET="${neons[$_RKT_PRNG_RET]}"
}


_palette_is_favorite() {
  emulate -L zsh
  local fav_file="$HOME/.config/zsh/rocket_favorites.txt"
  [[ ! -f "$fav_file" ]] && return 1
  local palette="$_rkt_tip $_rkt_win $_rkt_bdy $_rkt_top $_rkt_sds $_rkt_flm"
  grep -Fxq "$palette" "$fav_file"
}

_rocket_print_star_row() {
  emulate -L zsh
  local n="$1" palette="$2"
  local -a cs=("${(s: :)palette}")
  if (( $# >= 3 )); then
    printf '%s' "$3"
  else
    printf "%3d. " "$n"
  fi
  _rkt_set_color "$cs[1]"; printf '★ '
  _rkt_set_color "$cs[2]"; printf '★ '
  _rkt_set_color "$cs[3]"; printf '★ '
  _rkt_set_color "$cs[4]"; printf '★ '
  _rkt_set_color "$cs[5]"; printf '★ '
  _rkt_set_color "$cs[6]"; printf '★'
  _rkt_set_color normal
  printf '  %s\n' "$palette"
}

_rocket_palette_bytes() {
  emulate -L zsh
  local color byte_hex
  for color in $_rkt_tip $_rkt_win $_rkt_bdy $_rkt_top $_rkt_sds $_rkt_flm; do
    for i in 1 3 5; do
      byte_hex="${color:$((i-1)):2}"
      printf "%d\n" $((16#$byte_hex))
    done
  done
}

_compute_star_positions() {
  emulate -L zsh
  if [[ ! -v _RKT_STAR_CANDIDATES ]]; then
    typeset -g -a _RKT_STAR_CANDIDATES=(
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
  fi
  local total=${#_RKT_STAR_CANDIDATES}
  local -a seen=()
  local b i1 i2 idx pos
  for b in "${_RKT_PALETTE_BYTES[@]}"; do
    i1=$(( b % total ))
    i2=$(( (b + 73) % total ))
    for idx in $i1 $i2; do
      pos="${_RKT_STAR_CANDIDATES[$((idx + 1))]}"
      if (( ! ${seen[(Ie)$pos]} )); then
        seen+=("$pos")
      fi
    done
  done
  printf '%s\n' "${seen[@]}"
}

_rkt_star_color_for_mode() {
  emulate -L zsh
  case $_rkt_star_mode in
    gold)
      if [[ "$_rkt_terminal_theme" == light ]]; then
        _RKT_PRNG_RET="B8860B"
      else
        _RKT_PRNG_RET="FFE600"
      fi
      ;;
    neon)
      if [[ "$_rkt_terminal_theme" == light ]]; then
        _rkt_neon_color_light
      else
        _rkt_neon_color
      fi
      ;;
    *)
      if [[ "$_rkt_terminal_theme" == light ]]; then
        _RKT_PRNG_RET="333333"
      else
        _RKT_PRNG_RET="FFFFFF"
      fi
      ;;
  esac
}

_render_row() {
  emulate -L zsh
  local line_num="$1" art="$2" role="$3"
  local col char r key
  for ((col=0; col<18; col++)); do
    key="$line_num:$col"
    char="${art:$col:1}"
    if [[ "$char" != " " ]]; then
      r="${role:$col:1}"
      case "$r" in
        p) _rkt_set_color "$_rkt_tip" ;;
        w) _rkt_set_color "$_rkt_win" ;;
        b) _rkt_set_color "$_rkt_bdy" ;;
        t) _rkt_set_color "$_rkt_top" ;;
        s) _rkt_set_color "$_rkt_sds" ;;
        f) _rkt_set_color "$_rkt_flm" ;;
      esac
      printf '%s' "$char"
      _rkt_set_color normal
    elif (( ${_rocket_stars[(Ie)$key]} )); then
      _rkt_star_color_for_mode
      _rkt_set_color "$_RKT_PRNG_RET"
      printf '*'
      _rkt_set_color normal
    else
      printf ' '
    fi
  done
}

_render_flame() {
  emulate -L zsh
  local -a patterns=('\| ||' '|| |/' '\| |/' '|| ||' '*| |*' '~| ||' '|| |~' '\| /|')
  local n_patterns=${#patterns}
  local idx=$(( _RKT_PALETTE_BYTES[1] % n_patterns ))
  local pattern="${patterns[$((idx + 1))]}"
  printf '      '
  _rkt_set_color "$_rkt_flm"
  printf '%s' "$pattern"
  _rkt_set_color normal
}

_rocket_pick_palette() {
  emulate -L zsh
  local fav_file="$HOME/.config/zsh/rocket_favorites.txt"
  local -a colors=()
  _rkt_prng_range 1 100
  if (( _RKT_PRNG_RET <= $_rkt_favorite_weight )) && [[ -f "$fav_file" ]]; then
    local -a favs=("${(@f)"$(<$fav_file)"}")
    if (( ${#favs} > 0 )); then
      _rkt_prng_range 1 ${#favs}
      local rand_idx=$_RKT_PRNG_RET
      colors=("${(s: :)favs[$rand_idx]}")
    fi
  fi
  if (( ${#colors} != 6 )); then
    _gen_rocket_palette
    colors=("${_RKT_GEN_PALETTE[@]}")
  fi
  _rocket_record_history "${colors[@]}"
  typeset -g -a _RKT_PALETTE=("${colors[@]}")
}

_star_validate_hexes() {
  emulate -L zsh
  local -a hexes=()
  local raw cleaned
  for raw in "$@"; do
    cleaned="${raw#\#}"
    if [[ ! "$cleaned" =~ '^[0-9a-fA-F]{6}$' ]]; then
      return 1
    fi
    hexes+=("$cleaned")
  done
  printf '%s\n' "${hexes[@]}"
}

_star_preview_palette() {
  emulate -L zsh
  local h1="$1" h2="$2" h3="$3" h4="$4" h5="$5" h6="$6"
  local saved_tip="$_rkt_tip" saved_win="$_rkt_win" saved_bdy="$_rkt_bdy"
  local saved_top="$_rkt_top" saved_sds="$_rkt_sds" saved_flm="$_rkt_flm"
  local -a saved_stars=("${_rocket_stars[@]}")
  typeset -g _rkt_tip="$h1" _rkt_win="$h2" _rkt_bdy="$h3"
  typeset -g _rkt_top="$h4" _rkt_sds="$h5" _rkt_flm="$h6"
  typeset -g -a _rocket_stars=()
  _render_row 1 "        |         " "        b         "; echo ''
  _render_row 2 "       / \\        " "       t t        "; echo ''
  _render_row 3 "      / _ \\       " "      t t t       "; echo ''
  _render_row 4 "     |.o '.|      " "     swp wws      "; echo ''
  _render_row 5 "     |'._.'|      " "     swwwwws      "; echo ''
  _render_row 6 "     |     |      " "     b     b      "; echo ''
  _render_row 7 "   ,'|  |  |\`.    " "   ssb  b  bss    "; echo ''
  _render_row 8 "  /  |  |  |  \\   " "  s  b  b  b  s   "; echo ''
  _render_row 9 "  |,-'--|--'-.|   " "  bsssttbttsssb   "; echo ''
  _render_flame; echo ''
  typeset -g _rkt_tip="$saved_tip" _rkt_win="$saved_win" _rkt_bdy="$saved_bdy"
  typeset -g _rkt_top="$saved_top" _rkt_sds="$saved_sds" _rkt_flm="$saved_flm"
  typeset -g -a _rocket_stars=("${saved_stars[@]}")
}

star() {
  emulate -L zsh
  local fav_file="$HOME/.config/zsh/rocket_favorites.txt"
  local hist_file="$HOME/.config/zsh/rocket_history.txt"
  if (( $# == 0 )); then
    if [[ ! -v _rkt_bdy ]]; then
      echo "No active palette. Open a new tab first."
      return 1
    fi
    local palette="$_rkt_tip $_rkt_win $_rkt_bdy $_rkt_top $_rkt_sds $_rkt_flm"
    if [[ -f "$fav_file" ]] && grep -Fxq "$palette" "$fav_file"; then
      echo "Already in favorites."
      return 0
    fi
    mkdir -p "${fav_file:h}"
    echo "$palette" >> "$fav_file"
    _rkt_set_color "$_rkt_tip"; printf '★ '
    _rkt_set_color "$_rkt_win"; printf '★ '
    _rkt_set_color "$_rkt_bdy"; printf '★ '
    _rkt_set_color "$_rkt_top"; printf '★ '
    _rkt_set_color "$_rkt_sds"; printf '★ '
    _rkt_set_color "$_rkt_flm"; printf '★'
    _rkt_set_color normal
    local -a all_lines=("${(@f)"$(<$fav_file)"}")
    printf '  saved! (%s total)\n' "${#all_lines[@]}"
    return 0
  fi
  case "${1}" in
    list|ls)
      if [[ ! -f "$fav_file" ]]; then
        echo "No favorites yet. Use 'star' to save the current palette."
        return 0
      fi
      local i=1
      local -a lines=("${(@f)"$(<$fav_file)"}")
      for line in "${lines[@]}"; do
        _rocket_print_star_row "$i" "$line"
        (( i++ ))
      done
      ;;
    remove|rm)
      if [[ ! -f "$fav_file" ]]; then
        echo "No favorites to remove."
        return 1
      fi
      local n="${2}"
      if [[ ! "$n" =~ '^[0-9]+$' ]]; then
        echo "Usage: star remove <number>"
        return 1
      fi
      local -a lines=("${(@f)"$(<$fav_file)"}")
      local total=${#lines}
      if (( n < 1 || n > total )); then
        echo "Out of range. You have $total favorites."
        return 1
      fi
      lines[$n]=()
      if (( ${#lines} == 0 )); then
        rm "$fav_file"
      else
        printf '%s\n' "${lines[@]}" > "$fav_file"
      fi
      echo "Removed #$n."
      ;;
    history|hist)
      if [[ ! -f "$hist_file" ]]; then
        echo "No history yet."
        return 0
      fi
      local -a lines=("${(@f)"$(<$hist_file)"}")
      local total=${#lines}
      if [[ "$2" == "clear" ]]; then
        rm "$hist_file"
        echo "History cleared."
        return 0
      fi
      if (( $# >= 2 )); then
        if [[ ! "$2" =~ '^[0-9]+$' ]]; then
          echo "Usage: star history [N | clear]"
          return 1
        fi
        local n="$2"
        if (( n < 1 || n > total )); then
          echo "Out of range. History has $total entries."
          return 1
        fi
        local idx=$(( total - n + 1 ))
        local palette="${lines[$idx]}"
        if [[ -f "$fav_file" ]] && grep -Fxq "$palette" "$fav_file"; then
          echo "Already in favorites."
          return 0
        fi
        mkdir -p "${fav_file:h}"
        echo "$palette" >> "$fav_file"
        local -a cs=("${(s: :)palette}")
        _rkt_set_color "$cs[1]"; printf '★ '
        _rkt_set_color "$cs[2]"; printf '★ '
        _rkt_set_color "$cs[3]"; printf '★ '
        _rkt_set_color "$cs[4]"; printf '★ '
        _rkt_set_color "$cs[5]"; printf '★ '
        _rkt_set_color "$cs[6]"; printf '★'
        _rkt_set_color normal
        printf '  saved to favorites from history #%s!\n' "$n"
        return 0
      fi
      local limit=20
      local shown=0
      local display_n idx palette
      for ((i=total; i>=1; i--)); do
        (( shown >= limit )) && break
        display_n=$(( total - i + 1 ))
        if (( display_n == 1 )); then
          _rocket_print_star_row "$display_n" "${lines[$i]}" "(Current) 1. "
        else
          _rocket_print_star_row "$display_n" "${lines[$i]}" "$(printf '        %3d. ' "$display_n")"
        fi
        (( shown++ ))
      done
      if (( total > limit )); then
        echo ''
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
      echo ''
      _rkt_set_color "$hexes[1]"; printf '  ★ Porthole      '; _rkt_set_color normal; printf '  %s\n' "$hexes[1]"
      _rkt_set_color "$hexes[2]"; printf '  ★ Window        '; _rkt_set_color normal; printf '  %s\n' "$hexes[2]"
      _rkt_set_color "$hexes[3]"; printf '  ★ Body          '; _rkt_set_color normal; printf '  %s\n' "$hexes[3]"
      _rkt_set_color "$hexes[4]"; printf '  ★ Top           '; _rkt_set_color normal; printf '  %s\n' "$hexes[4]"
      _rkt_set_color "$hexes[5]"; printf '  ★ Window-sides  '; _rkt_set_color normal; printf '  %s\n' "$hexes[5]"
      _rkt_set_color "$hexes[6]"; printf '  ★ Flame         '; _rkt_set_color normal; printf '  %s\n' "$hexes[6]"
      echo ''
      _star_preview_palette "$hexes[1]" "$hexes[2]" "$hexes[3]" "$hexes[4]" "$hexes[5]" "$hexes[6]"
      echo ''
      printf '  star add %s %s %s %s %s %s\n' "$hexes[1]" "$hexes[2]" "$hexes[3]" "$hexes[4]" "$hexes[5]" "$hexes[6]"
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
      local -a all_hexes=()
      local i raw cleaned
      for ((i=2; i<=$#; i++)); do
        raw="${(P)i}"
        cleaned="${raw#\#}"
        if [[ ! "$cleaned" =~ ^[0-9a-fA-F]{6}$ ]]; then
          echo "Invalid hex code at position $((i-1)): $raw. Each must be 6 hex digits (e.g., ff0066 or #ff0066)."
          return 1
        fi
        all_hexes+=("$cleaned")
      done
      mkdir -p "${fav_file:h}"
      local j idx palette
      for ((j=0; j<palette_count; j++)); do
        idx=$((j * 6))
        palette="$all_hexes[$((idx+1))] $all_hexes[$((idx+2))] $all_hexes[$((idx+3))] $all_hexes[$((idx+4))] $all_hexes[$((idx+5))] $all_hexes[$((idx+6))]"
        echo "$palette" >> "$fav_file"
      done
      local -a all_lines=("${(@f)"$(<$fav_file)"}")
      local total=${#all_lines[@]}
      local start=$((total - palette_count + 1))
      for ((j=0; j<palette_count; j++)); do
        idx=$((j * 6))
        palette="$all_hexes[$((idx+1))] $all_hexes[$((idx+2))] $all_hexes[$((idx+3))] $all_hexes[$((idx+4))] $all_hexes[$((idx+5))] $all_hexes[$((idx+6))]"
        _rocket_print_star_row "" "$palette" "Added favorite #$((start + j)): "
      done
      ;;
    explore|browse)
      local n=5
      if (( $# >= 2 )) && [[ "$2" =~ '^[0-9]+$' ]]; then
        n="$2"
      fi
      echo ''
      for ((i=1; i<=n; i++)); do
        _rkt_prng_seed
        local -a p=($(_gen_rocket_palette))
        printf "%3d. " "$i"
        _rkt_set_color "$p[1]"; printf '★ '
        _rkt_set_color "$p[2]"; printf '★ '
        _rkt_set_color "$p[3]"; printf '★ '
        _rkt_set_color "$p[4]"; printf '★ '
        _rkt_set_color "$p[5]"; printf '★ '
        _rkt_set_color "$p[6]"; printf '★'
        _rkt_set_color normal
        printf '  %s %s %s %s %s %s\n' "${p[@]}"
      done
      echo ''
      echo "  star show <h1>..<h6>   preview a full rocket"
      echo "  star add  <h1>..<h6> [<h1>..<h6> ...]   save palette(s) to favorites"
      ;;
    weight|w)
      _rkt_load_settings
      if (( $# == 1 )); then
        echo "Favorite weight: $_rkt_favorite_weight%"
        echo ''
        echo "  Roughly $_rkt_favorite_weight out of every 100 new shells will roll"
        echo "  a saved favorite. The rest generate fresh palettes."
        echo ''
        echo "Usage: star weight <0-100>"
        echo "  0    = never use favorites (always fresh)"
        echo "  100  = always use favorites"
        return 0
      fi
      local n="$2"
      if [[ ! "$n" =~ '^[0-9]+$' ]]; then
        echo "Weight must be a number between 0 and 100."
        return 1
      fi
      if (( n < 0 || n > 100 )); then
        echo "Weight must be between 0 and 100."
        return 1
      fi
      typeset -g _rkt_favorite_weight=$n
      _rkt_save_settings
      echo "Set favorite weight to $n%."
      ;;
    color|colors)
      _rkt_load_settings
      if (( $# == 1 )); then
        if [[ ! -v _rkt_bdy ]]; then
          echo "No active palette. Open a new tab first."
          return 1
        fi
        echo ''
        _rkt_set_color "$_rkt_tip"; printf '  ★ Porthole      '; _rkt_set_color normal; printf '  %s\n' "$_rkt_tip"
        _rkt_set_color "$_rkt_win"; printf '  ★ Window        '; _rkt_set_color normal; printf '  %s\n' "$_rkt_win"
        _rkt_set_color "$_rkt_bdy"; printf '  ★ Body          '; _rkt_set_color normal; printf '  %s\n' "$_rkt_bdy"
        _rkt_set_color "$_rkt_top"; printf '  ★ Top           '; _rkt_set_color normal; printf '  %s\n' "$_rkt_top"
        _rkt_set_color "$_rkt_sds"; printf '  ★ Window-sides  '; _rkt_set_color normal; printf '  %s\n' "$_rkt_sds"
        _rkt_set_color "$_rkt_flm"; printf '  ★ Flame         '; _rkt_set_color normal; printf '  %s\n' "$_rkt_flm"
        echo ''
        _star_preview_palette "$_rkt_tip" "$_rkt_win" "$_rkt_bdy" "$_rkt_top" "$_rkt_sds" "$_rkt_flm"
        return 0
      fi
      if [[ "$2" == "reset" ]]; then
        typeset -g _rkt_random_star_mode=white
        typeset -g _rkt_favorite_star_mode=gold
        typeset -g _rkt_terminal_theme=dark
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
          typeset -g _rkt_terminal_theme="$val"
          _rkt_save_settings
          echo "Set terminal theme to $val."
          ;;
        random)
          if [[ "$val" != white && "$val" != gold && "$val" != neon ]]; then
            echo "Random mode must be 'white' or 'neon'."
            return 1
          fi
          typeset -g _rkt_random_star_mode="$val"
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
          typeset -g _rkt_favorite_star_mode="$val"
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
      if ! command -v curl >/dev/null 2>&1; then
        echo "curl is required for star update."
        return 1
      fi
      local remote_version=$(curl -fsSL --max-time 5 "https://raw.githubusercontent.com/clefspear/starcommand/main/VERSION" 2>/dev/null)
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
      local script_path="${(%):-%x}"
      if [[ -z $script_path ]]; then
        echo "Cannot determine script path. Update manually."
        return 1
      fi
      local temp_file
      temp_file=$(mktemp 2>/dev/null) || temp_file="/tmp/starcommand_update.$$"
      local dl_url="https://raw.githubusercontent.com/clefspear/starcommand/v${remote_version}/zsh/zsh_greeting.zsh"
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
      echo "starcommand v$_RKT_VERSION"
      echo ''
      echo "star                          save current palette to favorites"
      echo "star list                     show all favorites"
      echo "star remove N                 delete favorite #N"
      echo ''
      echo "star history                  show last 20 palettes (most recent first)"
      echo "star history N                save palette #N from history to favorites"
      echo "star history clear            wipe history"
      echo ''
      echo "star show H1..H6              preview a custom palette (mini rocket)"
      echo "star add  H1..H6 [H1..H6 ...] add one or more palettes to favorites"
      echo "star explore [N]              browse N random palettes (default 5)"
      echo ''
      echo "star color                    show current palette preview"
      printf 'star color theme <d|l>        terminal theme: '
      _rkt_print_option "$_rkt_terminal_theme" dark light
      echo ''
      printf 'star color random <mode>      random-palette stars: '
      _rkt_print_option "$_rkt_random_star_mode" white neon
      echo ''
      printf 'star color favorite <mode>    favorite-palette stars: '
      _rkt_print_option "$_rkt_favorite_star_mode" gold neon
      echo ''
      printf 'star weight <0-100>           ratio of favorites to random rockets. Currently: '
      _rkt_set_color --bold --italics
      printf '%s%%' "$_rkt_favorite_weight"
      _rkt_set_color normal
      echo ''
      echo "star color reset              restore defaults"
      echo ''
      echo "star update                   update to the latest version"
      echo ''
      echo "  Favorites: $fav_file"
      echo "  History:   $hist_file (last 100 launches)"
      echo "  Settings:  $HOME/.config/zsh/rocket_settings.zsh"
      ;;
    *)
      echo "Unknown subcommand: ${1}"
      echo "Try: star, star list, star show, star add, star explore, star color, star weight, star help"
      return 1
      ;;
  esac
}

_rkt_hw_info() {
  emulate -L zsh
  local cache="$HOME/.config/zsh/rocket_hw_cache.zsh"
  if [[ -f "$cache" ]] && [[ -n $(find "$cache" -mmin -1440 2>/dev/null) ]]; then
    source "$cache"
    return
  fi
  mkdir -p "${cache:h}"
  local os_type=$(uname -s)
  local os_str=$(uname -sm)
  local cpu_str="" mem_str=""
  if [[ "$os_type" == "Darwin" ]]; then
    local chip_name=$(sysctl -n machdep.cpu.brand_string)
    local cores_n=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Total Number of Cores" | cut -d ":" -f2 | sed 's/^[[:space:]]*//')
    cpu_str="$chip_name, $cores_n"
    mem_str=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Memory:" | cut -d ":" -f 2 | tr -d " ")
  elif [[ "$os_type" == "Linux" ]]; then
    local procs_n=$(grep -c "^processor" /proc/cpuinfo)
    local cores_n=$(grep "cpu cores" /proc/cpuinfo | head -1 | cut -d ":" -f2 | tr -d " ")
    local cpu_type=$(grep "model name" /proc/cpuinfo | head -1 | cut -d ":" -f2)
    cpu_str="$procs_n processors, $cores_n cores, $cpu_type"
    if [[ -r /proc/meminfo ]]; then
      local mem_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
      if [[ -n $mem_kb ]]; then
        mem_str=$(awk -v k="$mem_kb" 'BEGIN{printf "%.0fGB", k/1024/1024}')
      fi
    fi
    if [[ -z $mem_str ]]; then
      mem_str=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
    fi
    if [[ -r /etc/os-release ]]; then
      local pretty=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")
      local arch=$(uname -m)
      if [[ -n $pretty ]]; then
        os_str="$pretty $arch"
      fi
    fi
  fi
  printf 'typeset -g _rkt_os=%s\n'  "${(q)os_str}"  > "$cache"
  printf 'typeset -g _rkt_cpu=%s\n' "${(q)cpu_str}" >> "$cache"
  printf 'typeset -g _rkt_mem=%s\n' "${(q)mem_str}" >> "$cache"
  source "$cache"
}

_rkt_net_info() {
  emulate -L zsh
  local cache="$HOME/.config/zsh/rocket_net_cache.zsh"
  if [[ -f "$cache" ]] && [[ -n $(find "$cache" -mmin -5 2>/dev/null) ]]; then
    source "$cache"
    return
  fi
  mkdir -p "${cache:h}"
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
  printf 'typeset -g _rkt_ip=%s\n' "${(q)ip}" > "$cache"
  printf 'typeset -g _rkt_gw=%s\n' "${(q)gw}" >> "$cache"
  source "$cache"
}

_rkt_greeting() {
  emulate -L zsh
  _rkt_prng_seed
  _rkt_hw_info
  _rkt_net_info
  _rkt_load_settings
  if [[ -z "${_RKT_AUTO_UPDATE_CHECK:-}" ]]; then
    echo -n "starcommand: Allow starcommand to check Github periodically for future updates? [Y/N] "
    read -r _rkt_response
    if [[ "$_rkt_response" == "y" || "$_rkt_response" == "Y" ]]; then
      typeset -g _RKT_AUTO_UPDATE_CHECK="yes"
    else
      typeset -g _RKT_AUTO_UPDATE_CHECK="no"
    fi
    _rkt_save_settings
  fi
  _rkt_update_check_background
  _rocket_pick_palette
  local -a colors=("${_RKT_PALETTE[@]}")
  typeset -g _rkt_tip="${colors[1]}"
  typeset -g _rkt_win="${colors[2]}"
  typeset -g _rkt_bdy="${colors[3]}"
  typeset -g _rkt_top="${colors[4]}"
  typeset -g _rkt_sds="${colors[5]}"
  typeset -g _rkt_flm="${colors[6]}"
  typeset -g -a _RKT_PALETTE_BYTES=(
    $((16#${_rkt_tip:0:2})) $((16#${_rkt_tip:2:2})) $((16#${_rkt_tip:4:2}))
    $((16#${_rkt_win:0:2})) $((16#${_rkt_win:2:2})) $((16#${_rkt_win:4:2}))
    $((16#${_rkt_bdy:0:2})) $((16#${_rkt_bdy:2:2})) $((16#${_rkt_bdy:4:2}))
    $((16#${_rkt_top:0:2})) $((16#${_rkt_top:2:2})) $((16#${_rkt_top:4:2}))
    $((16#${_rkt_sds:0:2})) $((16#${_rkt_sds:2:2})) $((16#${_rkt_sds:4:2}))
    $((16#${_rkt_flm:0:2})) $((16#${_rkt_flm:2:2})) $((16#${_rkt_flm:4:2}))
  )
  typeset -g -a _rocket_stars=("${(@f)$(_compute_star_positions)}")
  if _palette_is_favorite; then
    typeset -g _rkt_star_mode="$_rkt_favorite_star_mode"
  else
    typeset -g _rkt_star_mode="$_rkt_random_star_mode"
  fi
  echo ''
  _render_row 0 "                  " "                  "
  echo ''
  _render_row 1 "        |         " "        b         "
  printf ' '; welcome_message; printf '\n'
  _render_row 2 "       / \\        " "       t t        "
  echo ''
  _render_row 3 "      / _ \\       " "      t t t       "
  printf ' '; show_date_info; printf '\n'
  _render_row 4 "     |.o '.|      " "     swp wws      "
  echo ''
  _render_row 5 "     |'._.'|      " "     swwwwws      "
  echo " Space Vessel:"
  _render_row 6 "     |     |      " "     b     b      "
  printf ' '; show_os_info; printf '\n'
  _render_row 7 "   ,'|  |  |\`.    " "   ssb  b  bss    "
  printf ' '; show_cpu_info; printf '\n'
  _render_row 8 "  /  |  |  |  \\   " "  s  b  b  b  s   "
  printf ' '; show_mem_info; printf '\n'
  _render_row 9 "  |,-'--|--'-.|   " "  bsssttbttsssb   "
  printf ' '; show_net_info; printf '\n'
  _render_flame
  echo ''
  _render_row 11 "                  " "                  "
  echo ''
  echo ''
  _rkt_set_color grey
  echo "Have a Nice Trip!"
  _rkt_set_color normal
  _rkt_update_check_nudge
}

welcome_message() {
  emulate -L zsh
  local cols prefix_len available value
  cols=$(_rkt_cols)
  prefix_len=19
  available=$((cols - prefix_len - 2))
  value="Welcome Aboard, Captain $(whoami)!"
  if (( $#value > available )); then
    printf '%s…' "${value[1,$((available - 1))]}"
  else
    printf 'Welcome Aboard, '
    _rkt_set_color "$_rkt_bdy"
    printf 'Captain '
    _rkt_set_color FFF
    printf '%s!' "$(whoami)"
  fi
  _rkt_set_color normal
}

show_date_info() {
  emulate -L zsh
  local cols prefix_len available value up_time
  cols=$(_rkt_cols)
  prefix_len=19
  available=$((cols - prefix_len - 2))
  up_time=$(uptime | awk -F '(up |,)' '{print $2}' | sed 's/^ *//g')
  value="Today is $(date +%Y.%m.%d), we are up and running for $up_time."
  if (( $#value > available )); then
    printf '%s…' "${value[1,$((available - 1))]}"
  else
    printf 'Today is '
    _rkt_set_color cyan
    printf '%s' "$(date +%Y.%m.%d)"
    _rkt_set_color normal
    printf ', we are up and running for '
    _rkt_set_color cyan
    printf '%s' "$up_time"
    _rkt_set_color normal
    printf '.'
  fi
  _rkt_set_color normal
}

_rkt_cols() {
  tput cols 2>/dev/null || echo 80
}

show_os_info() {
  emulate -L zsh
  local cols prefix_len available value
  cols=$(_rkt_cols)
  prefix_len=28
  available=$((cols - prefix_len - 2))
  value="$_rkt_os"
  _rkt_set_color yellow
  printf '\tOS: '
  _rkt_set_color 0F0
  if (( $#value > available )); then
    printf '%s…' "${value[1,$((available - 1))]}"
  else
    printf '%s' "$value"
  fi
  _rkt_set_color normal
}

show_cpu_info() {
  emulate -L zsh
  local cols prefix_len available value
  cols=$(_rkt_cols)
  prefix_len=29
  available=$((cols - prefix_len - 2))
  value="$_rkt_cpu"
  _rkt_set_color yellow
  printf '\tCPU: '
  _rkt_set_color 0F0
  if (( $#value > available )); then
    printf '%s…' "${value[1,$((available - 1))]}"
  else
    printf '%s' "$value"
  fi
  _rkt_set_color normal
}

show_mem_info() {
  emulate -L zsh
  local cols prefix_len available value
  cols=$(_rkt_cols)
  prefix_len=32
  available=$((cols - prefix_len - 2))
  value="$_rkt_mem"
  _rkt_set_color yellow
  printf '\tMemory: '
  _rkt_set_color 0F0
  if (( $#value > available )); then
    printf '%s…' "${value[1,$((available - 1))]}"
  else
    printf '%s' "$value"
  fi
  _rkt_set_color normal
}

show_net_info() {
  emulate -L zsh
  local cols prefix_len available value
  cols=$(_rkt_cols)
  prefix_len=29
  available=$((cols - prefix_len - 2))
  value="IP Address: $_rkt_ip, Default Gateway: $_rkt_gw"
  _rkt_set_color yellow
  printf '\tNet: '
  _rkt_set_color 0F0
  if (( $#value > available )); then
    printf '%s…' "${value[1,$((available - 1))]}"
  else
    printf '%s' "$value"
  fi
  _rkt_set_color normal
}

# ── Self-installer / auto-run dispatcher ─────────────────────────────────────
#
# Behavior depends on how this file is invoked:
#
#   Sourced (e.g. from .zshrc):      define functions, run greeting if interactive
#   Executed directly (curl|zsh,     download self to ~/.config/zsh/ and
#   `zsh zsh_greeting.zsh`):         add a fenced source block to .zshrc
#
# Detection uses ZSH_EVAL_CONTEXT:
#   - "toplevel"               → executed directly
#   - "toplevel:file" or       → sourced
#     "toplevel:file:file"
#
# Cross-OS: works on macOS, Linux, and WSL (anywhere zsh + curl/wget are
# available). Uses POSIX awk/grep/mv/touch only — no GNU-specific flags.

_starcommand_install() {
  emulate -L zsh
  setopt local_options no_unset pipe_fail

  local repo='clefspear/starcommand'
  local branch='main'
  local raw_url="https://raw.githubusercontent.com/${repo}/${branch}/zsh/zsh_greeting.zsh"

  local install_dir="${HOME}/.config/zsh"
  local install_path="${install_dir}/zsh_greeting.zsh"
  local profile="${HOME}/.zshrc"

  mkdir -p "$install_dir" || { echo "Could not create $install_dir" >&2; return 1; }

  # Download self to a stable location
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$raw_url" -o "$install_path" || { echo "Download failed" >&2; return 1; }
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$raw_url" -O "$install_path" || { echo "Download failed" >&2; return 1; }
  else
    echo "Need curl or wget to install starcommand." >&2
    return 1
  fi

  # Update .zshrc idempotently with fenced block
  local begin_marker='# >>> starcommand >>>'
  local end_marker='# <<< starcommand <<<'
  local source_line=". \"$install_path\""

  touch "$profile"

  # Strip any prior fenced starcommand block
  if grep -Fq "$begin_marker" "$profile"; then
    awk -v b="$begin_marker" -v e="$end_marker" '
      $0 == b {skip=1; next}
      $0 == e {skip=0; next}
      !skip {print}
    ' "$profile" > "${profile}.tmp" && mv "${profile}.tmp" "$profile"
  fi

  # Strip any legacy bare references to starcommand
  if grep -Fq "starcommand" "$profile"; then
    grep -v 'starcommand' "$profile" > "${profile}.tmp" && mv "${profile}.tmp" "$profile"
  fi

  # Append the fresh block
  {
    echo ""
    echo "$begin_marker"
    echo "$source_line"
    echo "$end_marker"
  } >> "$profile"

  echo ""
  echo "starcommand installed to $install_path"
  echo "Restart your shell (or run: exec zsh) to see the greeting."
  echo "Type 'star help' for commands."
}

if [[ "${ZSH_EVAL_CONTEXT-}" == "toplevel" ]]; then
  _starcommand_install
elif [[ -o interactive ]] && [[ -t 1 ]]; then
  _rkt_greeting
fi
