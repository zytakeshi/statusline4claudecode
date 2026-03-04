#!/usr/bin/env bash
# statusline4claudecode installer
# Copies the status line script and configures Claude Code settings.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_SRC="$REPO_DIR/statusline.sh"
SCRIPT_DST="$HOME/.claude/statusline-command.sh"
SETTINGS="$HOME/.claude/settings.json"

# Colors
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { printf "${GREEN}[+]${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}[!]${RESET} %s\n" "$*"; }
error() { printf "${RED}[x]${RESET} %s\n" "$*"; exit 1; }

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
command -v jq      >/dev/null 2>&1 || error "jq is required.      Install: brew install jq"
command -v curl    >/dev/null 2>&1 || error "curl is required."
command -v python3 >/dev/null 2>&1 || error "python3 is required."
command -v git     >/dev/null 2>&1 || error "git is required."

if [ "$(uname)" != "Darwin" ]; then
    warn "This script uses macOS Keychain to read OAuth tokens."
    warn "On Linux, you will need to modify the token extraction in statusline.sh."
fi

[ -f "$SCRIPT_SRC" ] || error "statusline.sh not found at $SCRIPT_SRC"

# ---------------------------------------------------------------------------
# Install script
# ---------------------------------------------------------------------------
mkdir -p "$HOME/.claude"

if [ -f "$SCRIPT_DST" ]; then
    warn "Existing $SCRIPT_DST found — backing up to ${SCRIPT_DST}.bak"
    cp "$SCRIPT_DST" "${SCRIPT_DST}.bak"
fi

cp "$SCRIPT_SRC" "$SCRIPT_DST"
chmod +x "$SCRIPT_DST"
info "Installed statusline script to $SCRIPT_DST"

# ---------------------------------------------------------------------------
# Configure settings.json
# ---------------------------------------------------------------------------
STATUSLINE_CMD="bash $SCRIPT_DST"

if [ -f "$SETTINGS" ]; then
    # Check if statusLine is already configured
    existing=$(jq -r '.statusLine.command // empty' "$SETTINGS" 2>/dev/null)
    if [ "$existing" = "$STATUSLINE_CMD" ]; then
        info "settings.json already configured — no changes needed."
    else
        # Merge statusLine into existing settings
        tmp=$(mktemp)
        jq --arg cmd "$STATUSLINE_CMD" '.statusLine = {"type": "command", "command": $cmd}' \
            "$SETTINGS" > "$tmp" 2>/dev/null
        if [ $? -eq 0 ] && [ -s "$tmp" ]; then
            mv "$tmp" "$SETTINGS"
            info "Updated $SETTINGS with statusLine command."
        else
            rm -f "$tmp"
            warn "Could not auto-update settings.json. Please add manually:"
            echo ""
            printf '  "statusLine": {\n    "type": "command",\n    "command": "%s"\n  }\n' "$STATUSLINE_CMD"
            echo ""
        fi
    fi
else
    # Create new settings.json
    printf '{\n  "statusLine": {\n    "type": "command",\n    "command": "%s"\n  }\n}\n' \
        "$STATUSLINE_CMD" > "$SETTINGS"
    info "Created $SETTINGS with statusLine command."
fi

# ---------------------------------------------------------------------------
# Optional: set timezone
# ---------------------------------------------------------------------------
echo ""
printf "${BOLD}Timezone${RESET} (default: Asia/Tokyo)\n"
printf "  Current: ${GREEN}%s${RESET}\n" "${STATUSLINE_TIMEZONE:-Asia/Tokyo}"
printf "  To change, set STATUSLINE_TIMEZONE in your shell profile:\n"
printf "    export STATUSLINE_TIMEZONE=\"America/New_York\"\n"
echo ""

# ---------------------------------------------------------------------------
# Verify OAuth token is accessible
# ---------------------------------------------------------------------------
if [ "$(uname)" = "Darwin" ]; then
    token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
        | python3 -c "import sys,re; m=re.search(r'\"accessToken\":\"([^\"]+)\"', sys.stdin.read()); print(m.group(1) if m else '')" 2>/dev/null)
    if [ -n "$token" ]; then
        info "OAuth token found in Keychain."
    else
        warn "Could not find OAuth token in Keychain."
        warn "Rate limit display will show 0% until you sign in to Claude Code."
    fi
fi

echo ""
info "Installation complete! Restart Claude Code to see the status line."
