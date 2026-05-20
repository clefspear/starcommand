#!/usr/bin/env zsh
set -euo pipefail
SCRIPT_DIR="${0:A:h:h:h}"

mkdir -p ~/.config/zsh
printf '0\n9.9.9\n' > ~/.config/zsh/rocket_update_check

pass=true

output=$(unset STARCOMMAND_NO_UPDATE_CHECK; zsh -c ". '$SCRIPT_DIR/zsh/zsh_greeting.zsh'; _rkt_greeting" 2>&1)
if echo "$output" | grep -q "v9.9.9 available"; then
    echo "Test 1 PASS: nudge appears without env var"
else
    echo "Test 1 FAIL: nudge missing"
    pass=false
fi

output=$(STARCOMMAND_NO_UPDATE_CHECK=1 zsh -c ". '$SCRIPT_DIR/zsh/zsh_greeting.zsh'; _rkt_greeting" 2>&1)
if echo "$output" | grep -q "v9.9.9 available"; then
    echo "Test 2 FAIL: nudge present despite opt-out"
    pass=false
else
    echo "Test 2 PASS: nudge suppressed with env var"
fi

rm -f ~/.config/zsh/rocket_update_check

$pass || exit 1
echo "All tests passed"
