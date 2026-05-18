#!/usr/bin/env bash
# PRNG parity test for Bash starcommand port
# Verifies xorshift32 matches prng_reference.txt exactly

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$DIR/bash/starcommand.sh"
REF="$DIR/tests/prng_reference.txt"

all_passed=true

# Parse reference file
current_seed=0
expected_vals=()

while IFS= read -r line; do
    if [[ $line =~ ^seed=([0-9]+)$ ]]; then
        # Test previous seed if we have one
        if [[ $current_seed -ne 0 && ${#expected_vals[@]} -eq 20 ]]; then
            printf "Testing seed=%s... " "$current_seed"
            s=$current_seed
            ok=true
            for ((i=0; i<20; i++)); do
                s=$(rkt_xorshift32 "$s")
                if [[ $s -ne ${expected_vals[$i]} ]]; then
                    echo "FAIL at #$((i+1)): got $s, expected ${expected_vals[$i]}"
                    ok=false
                    all_passed=false
                    break
                fi
            done
            if $ok; then echo "PASS"; fi
        fi
        current_seed=${BASH_REMATCH[1]}
        expected_vals=()
    elif [[ $line =~ ^[[:space:]]+[0-9]+:[[:space:]]+([0-9]+)$ ]]; then
        expected_vals+=(${BASH_REMATCH[1]})
    fi
done < "$REF"

# Test last seed
if [[ $current_seed -ne 0 && ${#expected_vals[@]} -eq 20 ]]; then
    printf "Testing seed=%s... " "$current_seed"
    s=$current_seed
    ok=true
    for ((i=0; i<20; i++)); do
        s=$(rkt_xorshift32 "$s")
        if [[ $s -ne ${expected_vals[$i]} ]]; then
            echo "FAIL at #$((i+1)): got $s, expected ${expected_vals[$i]}"
            ok=false
            all_passed=false
            break
        fi
    done
    if $ok; then echo "PASS"; fi
fi

# Test DJB2
printf "Testing DJB2 hash... "
djb_result=$(rkt_djb2 "myhost.2026.05.18")
if [[ $djb_result -eq 125233131 ]]; then
    echo "PASS (got $djb_result)"
else
    echo "FAIL: got $djb_result, expected 125233131"
    all_passed=false
fi

if $all_passed; then
    echo ""
    echo "All PRNG parity tests PASSED"
    exit 0
else
    echo ""
    echo "Some tests FAILED"
    exit 1
fi
