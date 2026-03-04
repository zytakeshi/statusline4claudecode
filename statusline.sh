#!/usr/bin/env bash
# statusline4claudecode - Rich status line for Claude Code
# https://github.com/zytakeshi/statusline4claudecode
#
# Displays:
#   Line 1: Model | Context% | +added/-removed | git branch
#   Line 2: 5-hour rate limit with progress bar and reset time
#   Line 3: 7-day rate limit with progress bar and reset time
#
# Reads JSON from stdin (provided by Claude Code's statusLine command feature).
# Fetches rate limit data from the Anthropic OAuth usage API.
#
# Requirements: bash, jq, curl, python3
# Platform:     macOS (uses `security` for Keychain access)

set -uo pipefail

# ---------------------------------------------------------------------------
# Configuration (override via environment variables)
# ---------------------------------------------------------------------------
STATUSLINE_CACHE_FILE="${STATUSLINE_CACHE_FILE:-/tmp/claude-usage-cache.json}"
STATUSLINE_CACHE_TTL="${STATUSLINE_CACHE_TTL:-360}"        # seconds
STATUSLINE_TIMEZONE="${STATUSLINE_TIMEZONE:-Asia/Tokyo}"

# ---------------------------------------------------------------------------
# ANSI true-color helpers
# ---------------------------------------------------------------------------
C_GREEN='\033[38;2;151;201;195m'   # #97C9C3
C_YELLOW='\033[38;2;229;192;123m'  # #E5C07B
C_RED='\033[38;2;224;108;117m'     # #E06C75
C_GRAY='\033[38;2;74;88;92m'       # #4A585C
C_RESET='\033[0m'

# Pick color based on integer percentage (0-100)
pct_color() {
    local pct="${1:-0}"
    if [ "$pct" -ge 80 ] 2>/dev/null; then
        printf '%s' "$C_RED"
    elif [ "$pct" -ge 50 ] 2>/dev/null; then
        printf '%s' "$C_YELLOW"
    else
        printf '%s' "$C_GREEN"
    fi
}

# Build a 10-segment progress bar: ▰ (filled) ▱ (empty)
make_bar() {
    local pct="${1:-0}"
    local filled=$(( pct * 10 / 100 ))
    [ "$filled" -gt 10 ] && filled=10
    [ "$filled" -lt 0 ] && filled=0
    local empty=$(( 10 - filled ))
    local bar=""
    local i
    for (( i=0; i<filled; i++ )); do bar="${bar}▰"; done
    for (( i=0; i<empty;  i++ )); do bar="${bar}▱"; done
    printf '%s' "$bar"
}

# ---------------------------------------------------------------------------
# Read JSON from stdin (Claude Code provides this)
# ---------------------------------------------------------------------------
input=$(cat)

model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"' 2>/dev/null)
[ -z "$model_name" ] || [ "$model_name" = "null" ] && model_name="Claude"

context_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' 2>/dev/null)
context_pct=${context_pct%.*}   # truncate decimal
[ -z "$context_pct" ] && context_pct=0

current_dir=$(echo "$input" | jq -r '.workspace.current_dir // ""' 2>/dev/null)
[ -z "$current_dir" ] || [ "$current_dir" = "null" ] && current_dir="$(pwd)"

# ---------------------------------------------------------------------------
# Git info: branch name and diff stats
# ---------------------------------------------------------------------------
git_branch=""
lines_added=0
lines_removed=0

if cd "$current_dir" 2>/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
    git_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [ -z "$git_branch" ]; then
        git_branch=$(git describe --tags --exact-match 2>/dev/null)
    fi
    if [ -z "$git_branch" ]; then
        git_branch=$(git rev-parse --short HEAD 2>/dev/null)
    fi
    [ -z "$git_branch" ] && git_branch="unknown"

    # Count added/removed lines (staged + unstaged vs HEAD)
    diff_stat=$(git diff --numstat HEAD 2>/dev/null)
    if [ -n "$diff_stat" ]; then
        lines_added=$(echo "$diff_stat" | awk '{sum+=$1} END{print sum+0}')
        lines_removed=$(echo "$diff_stat" | awk '{sum+=$2} END{print sum+0}')
    fi
fi

# ---------------------------------------------------------------------------
# Fetch rate-limit usage from Anthropic API (cached)
# ---------------------------------------------------------------------------
five_hour_pct=0
seven_day_pct=0
five_hour_reset_epoch=""
seven_day_reset_epoch=""

fetch_usage() {
    # Extract OAuth access token from macOS Keychain.
    # The keychain entry may be truncated, so we use regex instead of jq.
    local access_token
    access_token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
        | python3 -c "import sys,re; m=re.search(r'\"accessToken\":\"([^\"]+)\"', sys.stdin.read()); print(m.group(1) if m else '')" 2>/dev/null)
    if [ -z "$access_token" ]; then
        return 1
    fi

    local response
    response=$(curl -s --max-time 10 \
        -H "Authorization: Bearer $access_token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
    if [ -z "$response" ]; then
        return 1
    fi

    # Verify valid JSON with expected fields
    echo "$response" | jq -e '.five_hour' >/dev/null 2>&1 || return 1

    # Save with timestamp for cache
    local timestamp
    timestamp=$(date +%s)
    echo "$response" | jq --argjson ts "$timestamp" '. + {_cached_at: $ts}' \
        > "$STATUSLINE_CACHE_FILE" 2>/dev/null
    printf '%s' "$response"
    return 0
}

load_usage() {
    local now data=""
    now=$(date +%s)

    # Try cache first
    if [ -f "$STATUSLINE_CACHE_FILE" ]; then
        local cached_at
        cached_at=$(jq -r '._cached_at // 0' "$STATUSLINE_CACHE_FILE" 2>/dev/null)
        cached_at=${cached_at:-0}
        local age=$(( now - cached_at ))
        if [ "$age" -lt "$STATUSLINE_CACHE_TTL" ]; then
            data=$(cat "$STATUSLINE_CACHE_FILE" 2>/dev/null)
        fi
    fi

    # Refresh if cache is stale or missing
    if [ -z "$data" ]; then
        data=$(fetch_usage) || true
    fi

    if [ -z "$data" ]; then
        return 1
    fi

    # Parse utilization (API returns percentage directly, e.g. 17.0)
    five_hour_pct=$(echo "$data" | jq -r '.five_hour.utilization // 0' 2>/dev/null)
    five_hour_pct=${five_hour_pct%.*}
    [ -z "$five_hour_pct" ] && five_hour_pct=0

    seven_day_pct=$(echo "$data" | jq -r '.seven_day.utilization // 0' 2>/dev/null)
    seven_day_pct=${seven_day_pct%.*}
    [ -z "$seven_day_pct" ] && seven_day_pct=0

    # Parse reset timestamps (ISO 8601)
    five_hour_reset_epoch=$(echo "$data" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)
    seven_day_reset_epoch=$(echo "$data" | jq -r '.seven_day.resets_at // empty' 2>/dev/null)

    return 0
}

load_usage

# ---------------------------------------------------------------------------
# Format reset times in configured timezone using python3
# ---------------------------------------------------------------------------
read -r reset_5h reset_7d <<< "$(python3 -c "
from datetime import datetime, timezone, timedelta
import os

tz_name = os.environ.get('STATUSLINE_TIMEZONE', 'Asia/Tokyo')

# Try zoneinfo first (Python 3.9+), fall back to fixed offset
try:
    from zoneinfo import ZoneInfo
    tz = ZoneInfo(tz_name)
except Exception:
    tz = timezone(timedelta(hours=9))  # fallback to JST

def fmt_time(iso_str, short=False):
    if not iso_str or iso_str == 'null':
        return 'unknown'
    try:
        iso_str = iso_str.replace('+00:00', '+0000').replace('Z', '+0000')
        if '.' in iso_str:
            base, rest = iso_str.split('.', 1)
            for sep in ('+', '-'):
                if sep in rest:
                    idx = rest.index(sep)
                    iso_str = base + rest[idx:]
                    break
            else:
                iso_str = base + '+0000'
        dt = datetime.strptime(iso_str, '%Y-%m-%dT%H:%M:%S%z')
        dt_local = dt.astimezone(tz)
        if short:
            return dt_local.strftime('%-I%p').lower()
        else:
            return dt_local.strftime('%b %-d at %-I%p').replace('AM','am').replace('PM','pm')
    except Exception:
        return 'unknown'

five_h = '${five_hour_reset_epoch}'
seven_d = '${seven_day_reset_epoch}'
print(fmt_time(five_h, short=True), fmt_time(seven_d, short=False))
" 2>/dev/null || echo "unknown unknown")"

tz_label="$STATUSLINE_TIMEZONE"

# ---------------------------------------------------------------------------
# Build output lines
# ---------------------------------------------------------------------------
ctx_col=$(pct_color "$context_pct")
sep="${C_GRAY}│${C_RESET}"

line1=$(printf "${C_GREEN}🤖 %s${C_RESET} %s ${ctx_col}📊 %s%%${C_RESET} %s ${C_GREEN}✏️  +%s/-%s${C_RESET} %s ${C_GREEN}🔀 %s${C_RESET}" \
    "$model_name" "$sep" "$context_pct" "$sep" "$lines_added" "$lines_removed" "$sep" "$git_branch")

h5_col=$(pct_color "$five_hour_pct")
h5_bar=$(make_bar "$five_hour_pct")
line2=$(printf "${C_GRAY}⏱ 5h  ${h5_col}%s  %s%%${C_RESET}${C_GRAY}  Resets %s (%s)${C_RESET}" \
    "$h5_bar" "$five_hour_pct" "$reset_5h" "$tz_label")

d7_col=$(pct_color "$seven_day_pct")
d7_bar=$(make_bar "$seven_day_pct")
line3=$(printf "${C_GRAY}📅 7d  ${d7_col}%s  %s%%${C_RESET}${C_GRAY}  Resets %s (%s)${C_RESET}" \
    "$d7_bar" "$seven_day_pct" "$reset_7d" "$tz_label")

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
printf '%b\n%b\n%b\n' "$line1" "$line2" "$line3"
