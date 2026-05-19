#!/usr/bin/env fish
# Fish seed-based rocket renderer for parity testing
# Usage: fish _render_seed.fish <seed>

set DIR (dirname (status filename))/../..
source $DIR/fish/fish_greeting.fish

set -g _RKT_PRNG_STATE $argv[1]
set -g _rkt_star_mode white
set -g _rkt_terminal_theme dark

set -l colors (_gen_rocket_palette)
set -g _rkt_tip $colors[1]
set -g _rkt_win $colors[2]
set -g _rkt_bdy $colors[3]
set -g _rkt_top $colors[4]
set -g _rkt_sds $colors[5]
set -g _rkt_flm $colors[6]
set -g _RKT_PALETTE_BYTES \
    (math --scale=0 "0x"(string sub --start 1 --length 2 -- $_rkt_tip)) \
    (math --scale=0 "0x"(string sub --start 3 --length 2 -- $_rkt_tip)) \
    (math --scale=0 "0x"(string sub --start 5 --length 2 -- $_rkt_tip)) \
    (math --scale=0 "0x"(string sub --start 1 --length 2 -- $_rkt_win)) \
    (math --scale=0 "0x"(string sub --start 3 --length 2 -- $_rkt_win)) \
    (math --scale=0 "0x"(string sub --start 5 --length 2 -- $_rkt_win)) \
    (math --scale=0 "0x"(string sub --start 1 --length 2 -- $_rkt_bdy)) \
    (math --scale=0 "0x"(string sub --start 3 --length 2 -- $_rkt_bdy)) \
    (math --scale=0 "0x"(string sub --start 5 --length 2 -- $_rkt_bdy)) \
    (math --scale=0 "0x"(string sub --start 1 --length 2 -- $_rkt_top)) \
    (math --scale=0 "0x"(string sub --start 3 --length 2 -- $_rkt_top)) \
    (math --scale=0 "0x"(string sub --start 5 --length 2 -- $_rkt_top)) \
    (math --scale=0 "0x"(string sub --start 1 --length 2 -- $_rkt_sds)) \
    (math --scale=0 "0x"(string sub --start 3 --length 2 -- $_rkt_sds)) \
    (math --scale=0 "0x"(string sub --start 5 --length 2 -- $_rkt_sds)) \
    (math --scale=0 "0x"(string sub --start 1 --length 2 -- $_rkt_flm)) \
    (math --scale=0 "0x"(string sub --start 3 --length 2 -- $_rkt_flm)) \
    (math --scale=0 "0x"(string sub --start 5 --length 2 -- $_rkt_flm))
set -g _rocket_stars (_compute_star_positions)

_render_row 0 "                  " "                  "; echo ""
_render_row 1 "        |         " "        b         "; echo ""
_render_row 2 "       / \\        " "       t t        "; echo ""
_render_row 3 "      / _ \\       " "      t t t       "; echo ""
_render_row 4 "     |.o '.|      " "     swp wws      "; echo ""
_render_row 5 "     |'._.'|      " "     swwwwws      "; echo ""
_render_row 6 "     |     |      " "     b     b      "; echo ""
_render_row 7 "   ,'|  |  |`.    " "   ssb  b  bss    "; echo ""
_render_row 8 "  /  |  |  |  \\   " "  s  b  b  b  s   "; echo ""
_render_row 9 "  |,-'--|--'-.|   " "  bsssttbttsssb   "; echo ""
_render_flame; echo ""
_render_row 11 "                  " "                  "; echo ""
