#!/usr/bin/env bash
# Bash rocket renderer for parity testing
# Usage: bash _render_bash.sh <h1> <h2> <h3> <h4> <h5> <h6>

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$DIR/bash/starcommand.sh"

_RKT_TIP=$1
_RKT_WIN=$2
_RKT_BDY=$3
_RKT_TOP=$4
_RKT_SDS=$5
_RKT_FLM=$6
_RKT_STAR_MODE=white
_RKT_TERMINAL_THEME=dark
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
