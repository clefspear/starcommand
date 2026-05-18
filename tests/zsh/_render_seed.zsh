#!/usr/bin/env zsh
# Zsh seed-based rocket renderer for parity testing
# Usage: zsh _render_seed.zsh <seed>

DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$DIR/zsh_greeting.zsh"

_RKT_PRNG_STATE=$1
_RKT_STAR_MODE=white
_RKT_TERMINAL_THEME=dark

_gen_rocket_palette
colors=("${_RKT_GEN_PALETTE[@]}")
typeset -g _rkt_tip="${colors[1]}"
typeset -g _rkt_win="${colors[2]}"
typeset -g _rkt_bdy="${colors[3]}"
typeset -g _rkt_top="${colors[4]}"
typeset -g _rkt_sds="${colors[5]}"
typeset -g _rkt_flm="${colors[6]}"
typeset -g -a _rocket_stars=("${(@f)$(_compute_star_positions)}")

_render_row 0 "                  " "                  "; echo ''
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
_render_row 11 "                  " "                  "; echo ''
