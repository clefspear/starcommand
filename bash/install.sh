#!/usr/bin/env bash
# Install starcommand.sh into Bash profile
# Usage: bash install.sh [-p <path>] [-n]

PROFILE_PATH="${HOME}/.bashrc"
DRY_RUN=false

while getopts "p:n" opt; do
    case $opt in
        p) PROFILE_PATH="$OPTARG" ;;
        n) DRY_RUN=true ;;
        *) echo "Usage: $0 [-p <profile_path>] [-n]" >&2; exit 1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_LINE=". \"$SCRIPT_DIR/starcommand.sh\""

if ! grep -Fq "$SOURCE_LINE" "$PROFILE_PATH" 2>/dev/null; then
    if $DRY_RUN; then
        echo "Would append to $PROFILE_PATH:"
        echo "# starcommand - cross-shell rocket greeting"
        echo "$SOURCE_LINE"
    else
        echo "" >> "$PROFILE_PATH"
        echo "# starcommand - cross-shell rocket greeting" >> "$PROFILE_PATH"
        echo "$SOURCE_LINE" >> "$PROFILE_PATH"
        echo "starcommand.sh installed to $PROFILE_PATH"
        echo "Run 'source $PROFILE_PATH' or 'rkt_starcommand' to display your rocket greeting."
    fi
else
    echo "starcommand.sh already installed in $PROFILE_PATH"
fi
