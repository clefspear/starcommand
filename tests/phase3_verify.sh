#!/usr/bin/env bash
# Phase 3: Final cross-shell verification script
# Tests: basic parity, star command parity, cross-shell interchange (12-pairs), feature matrix

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

red()     { printf '\e[31;1m%s\e[m\n' "$*"; }
green()   { printf '\e[32;1m%s\e[m\n' "$*"; }
bold()    { printf '\e[1m%s\e[m\n' "$*"; }
header()  { bold "──── $* ────"; }
ok()      { green "  PASS"; ((PASS++)); }
fail()    { red "  FAIL: $*"; ((FAIL++)); }

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

clean_all() {
    rm -f "$HOME/.config/fish/rocket_favorites.txt"      "$HOME/.config/fish/rocket_history.txt"      "$HOME/.config/fish/rocket_settings.sh"      2>/dev/null || true
    rm -f "$HOME/.config/zsh/rocket_favorites.txt"       "$HOME/.config/zsh/rocket_history.txt"       "$HOME/.config/zsh/rocket_settings.zsh"       2>/dev/null || true
    rm -f "$HOME/.config/bash/rocket_favorites.txt"      "$HOME/.config/bash/rocket_history.txt"      "$HOME/.config/bash/rocket_settings.sh"       2>/dev/null || true
    rm -f "$HOME/.config/powershell/rocket_favorites.txt" "$HOME/.config/powershell/rocket_history.txt" "$HOME/.config/powershell/rocket_settings.ps1" 2>/dev/null || true
}

# ════════════════════════════════════════════════════════════════
# 1. Basic rocket render parity (5/5 seeds)
# ════════════════════════════════════════════════════════════════
header "1. Basic rocket render parity (5 seeds)"
result=$(bash "$DIR/tests/parity_test.sh" 2>&1)
echo "$result" | tail -1
if echo "$result" | tail -1 | grep -q "0 failed"; then
    ok
else
    fail "basic parity"
fi

# ════════════════════════════════════════════════════════════════
# 2. Star command parity sequence
# ════════════════════════════════════════════════════════════════
header "2. Star command parity sequence"
clean_all

SEQ=/tmp/star_seq3
mkdir -p "$SEQ"

# Run sequence in each shell
fish  -c "source $DIR/fish_greeting.fish;    star color reset; star add 3A7BDF E85D3A 2ECC71 F1C40F 9B59B6 1ABC9C; star list; star color theme light; star color random neon; star; star list; star color reset" 2>/dev/null > "$SEQ/fish.txt" || true
clean_all
zsh   -c "source $DIR/zsh_greeting.zsh;     star color reset; star add 3A7BDF E85D3A 2ECC71 F1C40F 9B59B6 1ABC9C; star list; star color theme light; star color random neon; star; star list; star color reset" 2>/dev/null > "$SEQ/zsh.txt" || true
clean_all
bash  -c "source $DIR/bash/starcommand.sh;   star color reset; star add 3A7BDF E85D3A 2ECC71 F1C40F 9B59B6 1ABC9C; star list; star color theme light; star color random neon; star; star list; star color reset" 2>/dev/null > "$SEQ/bash.txt" || true
clean_all
pwsh -NoProfile -NoLogo -NonInteractive -Command ". $DIR/powershell/starcommand.ps1; star color reset; star add 3A7BDF E85D3A 2ECC71 F1C40F 9B59B6 1ABC9C; star list; star color theme light; star color random neon; star; star list; star color reset" 2>/dev/null > "$SEQ/pwsh.txt" || true

all_match=true
for sh in zsh bash pwsh; do
    if ! cmp -s "$SEQ/fish.txt" "$SEQ/${sh}.txt"; then
        fsz=$(wc -c < "$SEQ/fish.txt")
        ssz=$(wc -c < "$SEQ/${sh}.txt")
        echo "  fish vs $sh: MISMATCH (fish=$fsz, $sh=$ssz)"
        diff <(strip_ansi < "$SEQ/fish.txt") <(strip_ansi < "$SEQ/${sh}.txt") | head -10
        all_match=false
    fi
done

if $all_match; then
    echo "  All 4 shells: $(wc -c < "$SEQ/fish.txt") bytes, byte-identical"
    ok
else
    fail "star command parity"
fi

clean_all

# ════════════════════════════════════════════════════════════════
# 3. Cross-shell file interchange — all 12 directional pairs
# ════════════════════════════════════════════════════════════════
header "3. Cross-shell file interchange (12 pairs)"

PALETTE="111111 222222 333333 444444 555555 666666"

interchange_pair() {
    local src="$1" dst="$2"
    local src_dir dst_dir src_cmd dst_cmd

    case "$src" in
        fish) src_dir="$HOME/.config/fish";       src_cmd="source $DIR/fish_greeting.fish" ;;
        zsh)  src_dir="$HOME/.config/zsh";        src_cmd="source $DIR/zsh_greeting.zsh" ;;
        bash) src_dir="$HOME/.config/bash";       src_cmd="source $DIR/bash/starcommand.sh" ;;
        pwsh) src_dir="$HOME/.config/powershell"; src_cmd=". $DIR/powershell/starcommand.ps1" ;;
    esac
    case "$dst" in
        fish) dst_dir="$HOME/.config/fish";       dst_cmd="source $DIR/fish_greeting.fish" ;;
        zsh)  dst_dir="$HOME/.config/zsh";        dst_cmd="source $DIR/zsh_greeting.zsh" ;;
        bash) dst_dir="$HOME/.config/bash";       dst_cmd="source $DIR/bash/starcommand.sh" ;;
        pwsh) dst_dir="$HOME/.config/powershell"; dst_cmd=". $DIR/powershell/starcommand.ps1" ;;
    esac

    clean_all

    # Save in source shell
    case "$src" in
        fish) fish -c "$src_cmd; star add $PALETTE" 2>/dev/null || true ;;
        zsh)  zsh  -c "$src_cmd; star add $PALETTE" 2>/dev/null || true ;;
        bash) bash -c "$src_cmd; star add $PALETTE" 2>/dev/null || true ;;
        pwsh) pwsh -NoProfile -NoLogo -NonInteractive -Command "$src_cmd; star add $PALETTE" 2>/dev/null || true ;;
    esac

    src_file="$src_dir/rocket_favorites.txt"
    if [ ! -f "$src_file" ]; then
        echo "  $src → $dst: source file not created"
        return 1
    fi

    # Copy to dest
    mkdir -p "$dst_dir"
    cp "$src_file" "$dst_dir/rocket_favorites.txt"

    # Read back
    local result=""
    case "$dst" in
        fish) result=$(fish -c "$dst_cmd; star list" 2>/dev/null || true) ;;
        zsh)  result=$(zsh  -c "$dst_cmd; star list" 2>/dev/null || true) ;;
        bash) result=$(bash -c "$dst_cmd; star list" 2>/dev/null || true) ;;
        pwsh) result=$(pwsh -NoProfile -NoLogo -NonInteractive -Command "$dst_cmd; star list" 2>/dev/null || true) ;;
    esac

    if echo "$result" | strip_ansi | grep -q '111111.*222222.*333333'; then
        echo "  $src → $dst: OK"
        return 0
    else
        echo "  $src → $dst: FAIL"
        echo "    saved: $(cat "$src_file")"
        echo "    read:  $(echo "$result" | strip_ansi | head -3)"
        return 1
    fi
}

all_ok=true
pairs_tested=0
for src in fish zsh bash pwsh; do
    for dst in fish zsh bash pwsh; do
        [ "$src" = "$dst" ] && continue
        if interchange_pair "$src" "$dst"; then
            :
        else
            all_ok=false
        fi
        ((pairs_tested++))
    done
done

if $all_ok; then
    echo "  $pairs_tested pairs: all OK"
    ok
else
    fail "cross-shell interchange"
fi

# ════════════════════════════════════════════════════════════════
# 4. Feature matrix — 16 subcommands × 4 shells
# ════════════════════════════════════════════════════════════════
header "4. Feature matrix (16 subcommands × 4 shells)"

test_subcmd() {
    local shell="$1" command="$2"
    local setup
    case "$shell" in
        fish) setup="source $DIR/fish_greeting.fish" ;;
        zsh)  setup="source $DIR/zsh_greeting.zsh" ;;
        bash) setup="source $DIR/bash/starcommand.sh" ;;
        pwsh) setup=". $DIR/powershell/starcommand.ps1" ;;
    esac

    # Need palette globals for bare `star`
    local pre
    case "$shell" in
        fish) pre='set -g _rkt_tip AABBCC; set -g _rkt_win DDEEFF; set -g _rkt_bdy 112233; set -g _rkt_top 445566; set -g _rkt_sds 778899; set -g _rkt_flm 001122; ' ;;
        zsh)  pre='typeset -g _rkt_tip=AABBCC _rkt_win=DDEEFF _rkt_bdy=112233 _rkt_top=445566 _rkt_sds=778899 _rkt_flm=001122; ' ;;
        bash) pre='_RKT_TIP=AABBCC _RKT_WIN=DDEEFF _RKT_BDY=112233 _RKT_TOP=445566 _RKT_SDS=778899 _RKT_FLM=001122; ' ;;
        pwsh) pre='$global:_rkt_tip="AABBCC";$global:_rkt_win="DDEEFF";$global:_rkt_bdy="112233";$global:_rkt_top="445566";$global:_rkt_sds="778899";$global:_rkt_flm="001122"; ' ;;
    esac

    local full="$setup; $pre $command"
    local ec=0 output=""
    case "$shell" in
        fish) output=$(fish -c "$full" 2>/dev/null) || ec=$? ;;
        zsh)  output=$(zsh  -c "$full" 2>/dev/null) || ec=$? ;;
        bash) output=$(bash -c "$full" 2>/dev/null) || ec=$? ;;
        pwsh) output=$(pwsh -NoProfile -NoLogo -NonInteractive -Command "$full" 2>/dev/null) || ec=$? ;;
    esac

    [ $ec -gt 1 ] && return 1
    echo "$output" | strip_ansi | grep -qiE '^error:|not found|unknown command' && return 1
    [ "$command" = "star" -a -z "$(echo "$output" | strip_ansi | tr -d ' \t\n')" ] && return 1
    return 0
}

printf "  %-22s" ""
for sh in fish zsh bash pwsh; do printf " %-8s" "$sh"; done; echo ""

subcmds=(
    "star (bare):star"
    "star list:star list"
    "star remove:star remove 1"
    "star history:star history"
    "star history N:star history 1"
    "star history clear:star history clear"
    "star show:star show 000000 FFFFFF FF0000 00FF00 0000FF FFFF00"
    "star add:star add AAAAAA BBBBBB CCCCCC DDDDDD EEEEEE FFFFFF"
    "star explore:star explore 1"
    "star weight:star weight"
    "star color:star color"
    "star color theme:star color theme dark"
    "star color random:star color random white"
    "star color favorite:star color favorite gold"
    "star color reset:star color reset"
    "star help:star help"
)

all_subcmds_ok=true
for entry in "${subcmds[@]}"; do
    desc="${entry%%:*}"
    cmd="${entry#*:}"
    printf "  %-22s" "$desc"
    for sh in fish zsh bash pwsh; do
        clean_all
        if test_subcmd "$sh" "$cmd"; then
            printf " \e[32m%-8s\e[m" "OK"
        else
            printf " \e[31m%-8s\e[m" "FAIL"
            all_subcmds_ok=false
        fi
    done
    echo ""
done

echo ""
echo "  Aliases:"
for entry in "star ls:star list" "star rm N:star remove 1" "star hist:star history" "star preview:star show AAAAAA BBBBBB CCCCCC DDDDDD EEEEEE FFFFFF" "star browse N:star explore 1" "star w:star weight" "star colors:star color" "star -h:star help" "star --help:star --help"; do
    desc="${entry%%:*}"
    cmd="${entry#*:}"
    printf "  %-22s" "$desc"
    for sh in fish zsh bash pwsh; do
        clean_all
        if test_subcmd "$sh" "$cmd"; then
            printf " \e[32m%-8s\e[m" "OK"
        else
            printf " \e[31m%-8s\e[m" "FAIL"
            all_subcmds_ok=false
        fi
    done
    echo ""
done

if $all_subcmds_ok; then
    ok
else
    fail "feature matrix"
fi

# ════════════════════════════════════════════════════════════════
# Summary
# ════════════════════════════════════════════════════════════════
clean_all
echo ""
bold "═══════════════════════════════════════════════════════════════════"
echo "  Phase 3 verification: $PASS passed, $FAIL failed"
if [ "$FAIL" -eq 0 ]; then
    green "  ALL VERIFICATIONS PASSED"
else
    red "  SOME VERIFICATIONS FAILED — review above"
fi
bold "═══════════════════════════════════════════════════════════════════"
exit $FAIL
