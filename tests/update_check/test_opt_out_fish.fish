#!/usr/bin/env fish
set SCRIPT_DIR (dirname (status filename))/../..

mkdir -p ~/.config/fish
printf '0\n9.9.9\n' > ~/.config/fish/rocket_update_check

set pass true

# Test 1: nudge appears without env var
set -e STARCOMMAND_NO_UPDATE_CHECK
set output (fish --command "source $SCRIPT_DIR/fish/fish_greeting.fish; fish_greeting" 2>&1)
if echo $output | grep -q "v9.9.9 available"
    echo "Test 1 PASS: nudge appears without env var"
else
    echo "Test 1 FAIL: nudge missing"
    set pass false
end

set output (env STARCOMMAND_NO_UPDATE_CHECK=1 fish --command "source $SCRIPT_DIR/fish/fish_greeting.fish; fish_greeting" 2>&1)
if echo $output | grep -q "v9.9.9 available"
    echo "Test 2 FAIL: nudge present despite opt-out"
    set pass false
else
    echo "Test 2 PASS: nudge suppressed with env var"
end

rm -f ~/.config/fish/rocket_update_check

if not $pass; exit 1; end
echo "All tests passed"
