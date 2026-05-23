#!/usr/bin/env bash
# Created By: Peter Azmy
# Install starcommand bash greeting via remote download.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/clefspear/starcommand/main/bash/install.sh | bash
#   bash install.sh [-p <profile_path>] [-n]
#
# Flags:
#   -p <path>   Override profile path (default: ~/.bashrc, plus ~/.bash_profile on macOS)
#   -n          Dry-run: print actions but don't modify anything

set -eu

REPO="clefspear/starcommand"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}/bash"
GREETING_FILE="starcommand.sh"

INSTALL_DIR="${HOME}/.config/bash"
INSTALL_PATH="${INSTALL_DIR}/${GREETING_FILE}"

PROFILE_PATH=""
DRY_RUN=false

while getopts "p:n" opt; do
    case $opt in
        p) PROFILE_PATH="$OPTARG" ;;
        n) DRY_RUN=true ;;
        *) echo "Usage: $0 [-p <profile_path>] [-n]" >&2; exit 1 ;;
    esac
done

# Default profile targets: .bashrc always, plus .bash_profile on macOS
# (macOS Terminal opens login shells, which read .bash_profile, not .bashrc).
if [ -z "$PROFILE_PATH" ]; then
    PROFILES=("${HOME}/.bashrc")
    if [ "$(uname -s)" = "Darwin" ]; then
        PROFILES+=("${HOME}/.bash_profile")
    fi
else
    PROFILES=("$PROFILE_PATH")
fi

BEGIN_MARKER="# >>> starcommand >>>"
END_MARKER="# <<< starcommand <<<"
SOURCE_LINE=". \"$INSTALL_PATH\""

# 1. Download the greeting to a stable location
if $DRY_RUN; then
    echo "Would download ${RAW_BASE}/${GREETING_FILE} → $INSTALL_PATH"
else
    mkdir -p "$INSTALL_DIR"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "${RAW_BASE}/${GREETING_FILE}" -o "$INSTALL_PATH"
        curl -fsSL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/VERSION" -o "${INSTALL_DIR}/VERSION"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "${RAW_BASE}/${GREETING_FILE}" -O "$INSTALL_PATH"
        wget -q "https://raw.githubusercontent.com/${REPO}/${BRANCH}/VERSION" -O "${INSTALL_DIR}/VERSION"
    else
        echo "Need curl or wget to download $GREETING_FILE." >&2
        exit 1
    fi
fi

# 2. Update each profile: strip any prior starcommand block, append a fresh one.
#    Fence markers make this idempotent across re-runs.
#    starcommand.sh auto-runs the greeting itself when sourced from an
#    interactive shell, so the block only needs to source it.
update_profile() {
    profile="$1"

    if $DRY_RUN; then
        echo "Would update $profile:"
        echo "  $BEGIN_MARKER"
        echo "  $SOURCE_LINE"
        echo "  $END_MARKER"
        return
    fi

    touch "$profile"

    # Strip any prior fenced starcommand block
    if grep -Fq "$BEGIN_MARKER" "$profile"; then
        awk -v b="$BEGIN_MARKER" -v e="$END_MARKER" '
            $0 == b {skip=1; next}
            $0 == e {skip=0; next}
            !skip {print}
        ' "$profile" > "${profile}.tmp" && mv "${profile}.tmp" "$profile"
    fi

    # Strip any legacy bare source lines that reference starcommand
    if grep -Fq "starcommand" "$profile"; then
        grep -v 'starcommand' "$profile" > "${profile}.tmp" && mv "${profile}.tmp" "$profile"
    fi

    # Append the fresh block
    {
        echo ""
        echo "$BEGIN_MARKER"
        echo "$SOURCE_LINE"
        echo "$END_MARKER"
    } >> "$profile"
}

for p in "${PROFILES[@]}"; do
    update_profile "$p"
done

if ! $DRY_RUN; then
    echo ""
    echo "starcommand installed to $INSTALL_PATH"
    echo "Type 'star help' for commands."
fi
