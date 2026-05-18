#!/usr/bin/env bash
# Bash seed-based rocket renderer for parity testing
# Usage: bash _render_seed.sh <seed>

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$DIR/bash/starcommand.sh"

_RKT_PRNG_STATE=$1
_RKT_STAR_MODE=white
_RKT_TERMINAL_THEME=dark

result=($(rkt_gen_rocket_palette $_RKT_PRNG_STATE))
_RKT_TIP=${result[1]}
_RKT_WIN=${result[2]}
_RKT_BDY=${result[3]}
_RKT_TOP=${result[4]}
_RKT_SDS=${result[5]}
_RKT_FLM=${result[6]}
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
