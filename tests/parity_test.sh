#!/usr/bin/env bash
# Cross-shell parity test: seed → rocket output
# Verifies all four shells produce byte-identical output for the same seed.
# Uses the same 5 seeds from prng_reference.txt.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REF="$DIR/tests/prng_reference.txt"
PASS=0
FAIL=0

echo "═ Cross-shell parity test ════════════════════════════════════════"
echo ""

# Extract seeds from reference file
seeds=()
while IFS= read -r line; do
    if [[ $line =~ ^seed=([0-9]+)$ ]]; then
        seeds+=("${BASH_REMATCH[1]}")
    fi
done < "$REF"

for seed in "${seeds[@]}"; do
    printf "seed=%s  " "$seed"

    # Run each shell renderer
    fish "$DIR/tests/fish/_render_seed.fish" "$seed" > /tmp/parity_fish_$seed.txt 2>/dev/null
    zsh  "$DIR/tests/zsh/_render_seed.zsh"  "$seed" > /tmp/parity_zsh_$seed.txt 2>/dev/null
    bash "$DIR/tests/bash/_render_seed.sh"   "$seed" > /tmp/parity_bash_$seed.txt 2>/dev/null
    pwsh -NoProfile -NoLogo -NonInteractive -File "$DIR/tests/powershell/_render_seed.ps1" -Seed "$seed" > /tmp/parity_pwsh_$seed.txt 2>/dev/null

    # Compare: fish vs each other shell
    fish_sz=$(wc -c < /tmp/parity_fish_$seed.txt)
    ok=true

    if ! cmp -s /tmp/parity_fish_$seed.txt /tmp/parity_zsh_$seed.txt; then
        echo "zsh MISMATCH (fish=$fish_sz, zsh=$(wc -c < /tmp/parity_zsh_$seed.txt))"
        ok=false
    fi
    if ! cmp -s /tmp/parity_fish_$seed.txt /tmp/parity_bash_$seed.txt; then
        echo "bash MISMATCH (fish=$fish_sz, bash=$(wc -c < /tmp/parity_bash_$seed.txt))"
        ok=false
    fi
    if ! cmp -s /tmp/parity_fish_$seed.txt /tmp/parity_pwsh_$seed.txt; then
        echo "pwsh MISMATCH (fish=$fish_sz, pwsh=$(wc -c < /tmp/parity_pwsh_$seed.txt))"
        ok=false
    fi

    if $ok; then
        echo "PASS  ($fish_sz bytes, all four identical)"
        ((PASS++))
    else
        echo "FAIL"
        ((FAIL++))
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed"

# Show diff for first failure, if any
for seed in "${seeds[@]}"; do
    if ! cmp -s /tmp/parity_fish_$seed.txt /tmp/parity_zsh_$seed.txt; then
        echo ""
        echo "First mismatch (seed=$seed):"
        echo "--- fish ---"
        xxd /tmp/parity_fish_$seed.txt | head -10
        echo "--- zsh ---"
        xxd /tmp/parity_zsh_$seed.txt | head -10
        break
    fi
    if ! cmp -s /tmp/parity_fish_$seed.txt /tmp/parity_bash_$seed.txt; then
        echo ""
        echo "First mismatch (seed=$seed, bash):"
        echo "--- fish ---"
        xxd /tmp/parity_fish_$seed.txt | head -10
        echo "--- bash ---"
        xxd /tmp/parity_bash_$seed.txt | head -10
        break
    fi
    if ! cmp -s /tmp/parity_fish_$seed.txt /tmp/parity_pwsh_$seed.txt; then
        echo ""
        echo "First mismatch (seed=$seed, pwsh):"
        echo "--- fish ---"
        xxd /tmp/parity_fish_$seed.txt | head -10
        echo "--- pwsh ---"
        xxd /tmp/parity_pwsh_$seed.txt | head -10
        break
    fi
done

# ═══════════════════════════════════════════════════════════════════
# Star command parity test
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "═ Star command parity test ════════════════════════════════════"
echo ""

clean_star_state() {
    rm -f "$HOME/.config/fish/rocket_favorites.txt"      "$HOME/.config/fish/rocket_history.txt"      "$HOME/.config/fish/rocket_settings.sh"
    rm -f "$HOME/.config/zsh/rocket_favorites.txt"       "$HOME/.config/zsh/rocket_history.txt"       "$HOME/.config/zsh/rocket_settings.zsh"
    rm -f "$HOME/.config/bash/rocket_favorites.txt"      "$HOME/.config/bash/rocket_history.txt"      "$HOME/.config/bash/rocket_settings.sh"
    rm -f "$HOME/.config/powershell/rocket_favorites.txt" "$HOME/.config/powershell/rocket_history.txt" "$HOME/.config/powershell/rocket_settings.ps1"
}

SEQDIR=$(mktemp -d)
clean_star_state 2>/dev/null || true

SEQUENCE='star color reset; star add 3A7BDF E85D3A 2ECC71 F1C40F 9B59B6 1ABC9C; star list; star color theme light; star color random neon; star; star list; star color reset'

fish  -c "source $DIR/fish_greeting.fish;    $SEQUENCE" 2>/dev/null > "$SEQDIR/fish.txt"
clean_star_state 2>/dev/null || true
zsh   -c "source $DIR/zsh_greeting.zsh;     $SEQUENCE" 2>/dev/null > "$SEQDIR/zsh.txt"
clean_star_state 2>/dev/null || true
bash  -c "source $DIR/bash/starcommand.sh;   $SEQUENCE" 2>/dev/null > "$SEQDIR/bash.txt"
clean_star_state 2>/dev/null || true
pwsh -NoProfile -NoLogo -NonInteractive -Command ". $DIR/powershell/starcommand.ps1; $SEQUENCE" 2>/dev/null > "$SEQDIR/pwsh.txt"

all_ok=true
for sh in zsh bash pwsh; do
    if cmp -s "$SEQDIR/fish.txt" "$SEQDIR/${sh}.txt"; then
        printf "  fish vs %-5s  PASS" "$sh"
        echo "  ($(wc -c < "$SEQDIR/fish.txt") bytes)"
    else
        printf "  fish vs %-5s  FAIL" "$sh"
        fsz=$(wc -c < "$SEQDIR/fish.txt")
        ssz=$(wc -c < "$SEQDIR/${sh}.txt")
        echo "  (fish=$fsz, $sh=$ssz)"
        all_ok=false
    fi
done

rm -rf "$SEQDIR"
clean_star_state 2>/dev/null || true
echo ""
if $all_ok; then
    echo "  Star command parity: PASS"
    ((PASS++))
else
    echo "  Star command parity: FAIL"
    ((FAIL++))
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed"

exit $FAIL
