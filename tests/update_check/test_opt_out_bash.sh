#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

mkdir -p ~/.config/bash
printf '0\n9.9.9\n' > ~/.config/bash/rocket_update_check

pass=true

output=$(unset STARCOMMAND_NO_UPDATE_CHECK; bash "$SCRIPT_DIR/bash/starcommand.sh" --greeting 2>&1)
if echo "$output" | grep -q "v9.9.9 available"; then
    echo "Test 1 PASS: nudge appears without env var"
else
    echo "Test 1 FAIL: nudge missing"
    pass=false
fi

output=$(STARCOMMAND_NO_UPDATE_CHECK=1 bash "$SCRIPT_DIR/bash/starcommand.sh" --greeting 2>&1)
if echo "$output" | grep -q "v9.9.9 available"; then
    echo "Test 2 FAIL: nudge present despite opt-out"
    pass=false
else
    echo "Test 2 PASS: nudge suppressed with env var"
fi

rm -f ~/.config/bash/rocket_update_check

$pass || exit 1
echo "All tests passed"
