source fish_greeting.fish
set -g _rkt_tip $argv[1]
set -g _rkt_win $argv[2]
set -g _rkt_bdy $argv[3]
set -g _rkt_top $argv[4]
set -g _rkt_sds $argv[5]
set -g _rkt_flm $argv[6]
set -g _rocket_stars (_compute_star_positions)
set -g _rkt_star_mode white
set -g _rkt_terminal_theme dark

_render_row 0 "                  " "                  "
echo
_render_row 1 "        |         " "        b         "
echo
_render_row 2 "       / \\        " "       t t        "
echo
_render_row 3 "      / _ \\       " "      t t t       "
echo
_render_row 4 "     |.o '.|      " "     swp wws      "
echo
_render_row 5 "     |'._.'|      " "     swwwwws      "
echo
_render_row 6 "     |     |      " "     b     b      "
echo
_render_row 7 "   ,'|  |  |`.    " "   ssb  b  bss    "
echo
_render_row 8 "  /  |  |  |  \\   " "  s  b  b  b  s   "
echo
_render_row 9 "  |,-'--|--'-.|   " "  bsssttbttsssb   "
echo
_render_flame
echo
_render_row 11 "                  " "                  "
echo