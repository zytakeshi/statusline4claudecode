#!/usr/bin/env bash
# statusline4claudecode uninstaller
set -euo pipefail

SCRIPT_DST="$HOME/.claude/statusline-command.sh"
SETTINGS="$HOME/.claude/settings.json"
CACHE_FILE="/tmp/claude-usage-cache.json"

GREEN='\033[32m'
YELLOW='\033[33m'
RESET='\033[0m'

info() { printf "${GREEN}[+]${RESET} %s\n" "$*"; }
warn() { printf "${YELLOW}[!]${RESET} %s\n" "$*"; }

# Remove script
if [ -f "$SCRIPT_DST" ]; then
    mv "$SCRIPT_DST" "${SCRIPT_DST}.uninstalled"
    info "Moved $SCRIPT_DST to ${SCRIPT_DST}.uninstalled"
else
    warn "Script not found at $SCRIPT_DST — skipping."
fi

# Remove statusLine from settings.json
if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
    if jq -e '.statusLine' "$SETTINGS" >/dev/null 2>&1; then
        tmp=$(mktemp)
        jq 'del(.statusLine)' "$SETTINGS" > "$tmp" 2>/dev/null
        if [ $? -eq 0 ] && [ -s "$tmp" ]; then
            mv "$tmp" "$SETTINGS"
            info "Removed statusLine from $SETTINGS"
        else
            rm -f "$tmp"
            warn "Could not update settings.json. Please remove statusLine manually."
        fi
    fi
fi

# Remove cache
if [ -f "$CACHE_FILE" ]; then
    rm -f "$CACHE_FILE"
    info "Removed cache file $CACHE_FILE"
fi

echo ""
info "Uninstall complete. Restart Claude Code to apply."
