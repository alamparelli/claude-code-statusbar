#!/bin/bash
# Claude Code Statusbar Installer
# https://github.com/davidamo9/claude-code-statusbar

set -e

HOOK_DIR="$HOME/.claude/hooks"
HOOK_FILE="$HOOK_DIR/statusline.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Claude Code Statusbar Installer"
echo "================================"
echo ""

# Check for jq dependency
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed."
    echo ""
    echo "Install it with:"
    echo "  macOS:  brew install jq"
    echo "  Ubuntu: sudo apt install jq"
    echo "  Fedora: sudo dnf install jq"
    exit 1
fi

echo "[1/3] Creating hooks directory..."
mkdir -p "$HOOK_DIR"

echo "[2/3] Installing statusline hook..."
cp "$SCRIPT_DIR/statusline.sh" "$HOOK_FILE"
chmod +x "$HOOK_FILE"

echo "[3/3] Configuring Claude Code settings..."

# Create settings.json if it doesn't exist
if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
fi

# Check if statusLine is already configured
if jq -e '.statusLine' "$SETTINGS_FILE" &>/dev/null; then
    echo ""
    echo "Warning: statusLine is already configured in settings.json"
    echo "Current config:"
    jq '.statusLine' "$SETTINGS_FILE"
    echo ""
    read -p "Overwrite? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping settings update. Hook file was still installed."
        echo ""
        echo "Done! Restart Claude Code to see the statusbar."
        exit 0
    fi
fi

# Add statusLine configuration
jq '.statusLine = {"type": "command", "command": "~/.claude/hooks/statusline.sh"}' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

echo ""
echo "Done! Restart Claude Code to see the statusbar."
echo ""
echo "The statusbar displays:"
echo "  - Current model (opus/sonnet/haiku)"
echo "  - Working directory"
echo "  - Context window usage (color-coded)"
echo "  - Git branch with status indicators"
