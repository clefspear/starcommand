source zsh_greeting.zsh
typeset -g _rkt_tip=$1
typeset -g _rkt_win=$2
typeset -g _rkt_bdy=$3
typeset -g _rkt_top=$4
typeset -g _rkt_sds=$5
typeset -g _rkt_flm=$6
typeset -g _rkt_star_mode=white
typeset -g _rkt_terminal_theme=dark
typeset -g -a _rocket_stars=($(_compute_star_positions))

_render_row 0 "                  " "                  "
echo ''
_render_row 1 "        |         " "        b         "
echo ''
_render_row 2 "       / \\        " "       t t        "
echo ''
_render_row 3 "      / _ \\       " "      t t t       "
echo ''
_render_row 4 "     |.o '.|      " "     swp wws      "
echo ''
_render_row 5 "     |'._.'|      " "     swwwwws      "
echo ''
_render_row 6 "     |     |      " "     b     b      "
echo ''
_render_row 7 "   ,'|  |  |\`.    " "   ssb  b  bss    "
echo ''
_render_row 8 "  /  |  |  |  \\   " "  s  b  b  b  s   "
echo ''
_render_row 9 "  |,-'--|--'-.|   " "  bsssttbttsssb   "
echo ''
_render_flame
echo ''
_render_row 11 "                  " "                  "
echo ''