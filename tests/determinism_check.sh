#!/usr/bin/env bash
# determinism_check.sh
# Verify zsh and fish produce byte-identical rocket output for fixed palettes.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$(dirname "$0")"
OUTPUT_DIR="$TESTS_DIR/outputs"
PALETTE_DIR="$TESTS_DIR/palettes"
RENDER_FISH="$TESTS_DIR/_render_fish.fish"
RENDER_ZSH="$TESTS_DIR/_render_zsh.zsh"

mkdir -p "$OUTPUT_DIR" "$PALETTE_DIR"

# ── Test palettes (6 hex codes each, no # prefix) ──────────────────────────
# Palette 1: random mid-range colors
P1="3A7BDF E85D3A 2ECC71 F1C40F 9B59B6 1ABC9C"

# Palette 2: near 148-cell modulo boundary — bytes 0,1,146,147,73,74 distributed
P2="000001 929300 494A00 000092 010000 920049"

# Palette 3: dark + bright extremes, exercises ANSI at RGB min/max
P3="000000 FFFFFF 000000 FFFFFF 000000 FFFFFF"

PALETTES=("$P1" "$P2" "$P3")
NAMES=("random-mid" "boundary" "extremes")

# Save palette files for reproducibility
for i in "${!PALETTES[@]}"; do
  echo "${PALETTES[$i]}" > "$PALETTE_DIR/${NAMES[$i]}.txt"
done

# ── Helpers ────────────────────────────────────────────────────────────────
hex_to_args() { printf '%s %s %s %s %s %s\n' $1; }

run_fish() {
  local name="$1" palette="$2"
  # shellcheck disable=SC2086
  fish "$RENDER_FISH" $(hex_to_args "$palette") > "$OUTPUT_DIR/${name}.fish.txt" 2>&1
}

run_zsh() {
  local name="$1" palette="$2"
  # shellcheck disable=SC2086
  zsh "$RENDER_ZSH" $(hex_to_args "$palette") > "$OUTPUT_DIR/${name}.zsh.txt" 2>&1
}

# ── Test each palette ──────────────────────────────────────────────────────
ALL_PASSED=true

for i in "${!PALETTES[@]}"; do
  name="${NAMES[$i]}"
  palette="${PALETTES[$i]}"

  echo "── Palette: $name ──────────────────────────────"
  echo "   $palette"
  echo ""

  run_fish "$name" "$palette"
  echo "   [fish] wrote $(wc -c < "$OUTPUT_DIR/${name}.fish.txt" | tr -d ' ') bytes"

  run_zsh "$name" "$palette"
  echo "   [zsh]  wrote $(wc -c < "$OUTPUT_DIR/${name}.zsh.txt" | tr -d ' ') bytes"

  if diff "$OUTPUT_DIR/${name}.fish.txt" "$OUTPUT_DIR/${name}.zsh.txt" > "$OUTPUT_DIR/${name}.diff"; then
    echo "   ✅ PASS — byte-identical"
  else
    echo "   ❌ FAIL — see $OUTPUT_DIR/${name}.diff"
    echo ""
    echo "   First 10 lines of diff:"
    head -10 "$OUTPUT_DIR/${name}.diff" | sed 's/^/     /'
    ALL_PASSED=false
  fi
  echo ""
done

# Also save a combined report
{
  echo "Determinism Check — $(date)"
  echo "================================"
  for i in "${!PALETTES[@]}"; do
    name="${NAMES[$i]}"
    palette="${PALETTES[$i]}"
    echo ""
    echo "Palette: $name"
    echo "  Hex: $palette"
    if [ -s "$OUTPUT_DIR/${name}.diff" ]; then
      echo "  Result: FAIL"
      cat "$OUTPUT_DIR/${name}.diff"
    else
      echo "  Result: PASS"
    fi
  done
} > "$OUTPUT_DIR/REPORT.txt"

# ── Summary ────────────────────────────────────────────────────────────────
if $ALL_PASSED; then
  echo "═══════════════════════════════════════════════"
  echo "  ✅ ALL PALETTES PASSED — fish == zsh byte-for-byte"
  echo "═══════════════════════════════════════════════"
else
  echo "═══════════════════════════════════════════════"
  echo "  ❌ SOME PALETTES FAILED"
  echo "  Check diffs in $OUTPUT_DIR/"
  echo "═══════════════════════════════════════════════"
  exit 1
fi