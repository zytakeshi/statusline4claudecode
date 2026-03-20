---
name: statusline
description: Configure a rich status line for Claude Code showing model name, context usage, git stats, and rate limit progress bars with color-coded thresholds. Use when asked to "set up statusline", "configure status line", "show rate limits", "install statusline", or "statusline setup".
license: MIT
metadata:
  author: zytakeshi
  version: "2.0.0"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---

# statusline4claudecode

Set up a rich 3-line status line for Claude Code.

## What It Displays

```
🤖 Opus 4.6 │ 📊 25% │ ✏️  +42/-1 │ 🔀 main
⏱ 5h  ▰▰▱▱▱▱▱▱▱▱  17%  Resets 3am (Asia/Tokyo)
📅 7d  ▰▰▰▱▱▱▱▱▱▱  35%  Resets Mar 6 at 4pm (Asia/Tokyo)
```

- **Line 1:** Model name | Context window % | Lines added/removed | Git branch
- **Line 2:** 5-hour rate limit with progress bar and reset time
- **Line 3:** 7-day rate limit with progress bar and reset time

Colors change by usage: green (0-49%), yellow (50-79%), red (80-100%).

## Requirements

- **macOS** (uses Keychain for OAuth token — Linux users must modify token extraction)
- `bash`, `jq`, `curl`, `python3`, `git`
- Claude Code with OAuth session (Claude Pro / Max / Team) or v2.1.80+ for native rate limits

## How Rate Limits Work

The script uses two strategies in priority order:

1. **Native (v2.1.80+):** Reads `rate_limits` directly from the statusLine stdin JSON — no API call needed
2. **API fallback:** Extracts OAuth token from macOS Keychain and fetches from the Anthropic usage API (cached for 6 minutes)

## Installation Steps

When the user asks to set up or install the statusline, follow these steps:

### Step 1: Locate the statusline script

The script is at `statusline.sh` relative to this skill file. Determine its absolute path from the skill's installed location.

### Step 2: Copy the script

```bash
cp "<skill-dir>/statusline.sh" ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

### Step 3: Configure settings.json

Read `~/.claude/settings.json` and add or update the `statusLine` key:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

Preserve all existing settings — only add/update the `statusLine` field.

### Step 4: Verify

Check that `~/.claude/statusline-command.sh` exists and is executable. Inform the user to restart Claude Code.

## Configuration

The script reads these environment variables (set in `~/.zshrc` or `~/.bashrc`):

| Variable | Default | Description |
|----------|---------|-------------|
| `STATUSLINE_TIMEZONE` | `Asia/Tokyo` | Timezone for reset times (any IANA tz name) |
| `STATUSLINE_CACHE_TTL` | `360` | API cache lifetime in seconds (fallback mode only) |
| `STATUSLINE_CACHE_FILE` | `/tmp/claude-usage-cache.json` | Cache file path (fallback mode only) |

## Troubleshooting

- **Rate limits show 0%:** Ensure OAuth login (`security find-generic-password -s "Claude Code-credentials" -w` should return data), or upgrade to Claude Code v2.1.80+ for native rate limits
- **"unknown" reset times:** Check `python3` is in PATH; API may not return reset times if no limits hit yet
- **Script errors:** Test manually: `echo '{"model":{"display_name":"Test"},"context_window":{"used_percentage":50},"workspace":{"current_dir":"'"$(pwd)"'"}}' | bash ~/.claude/statusline-command.sh`

## Uninstallation

To remove the statusline:

1. Delete `~/.claude/statusline-command.sh`
2. Remove the `statusLine` key from `~/.claude/settings.json`
3. Optionally remove cache: `/tmp/claude-usage-cache.json`
4. Restart Claude Code
