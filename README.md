# statusline4claudecode

A rich 3-line status line for [Claude Code](https://claude.ai/claude-code) that shows your model, context usage, git status, and **real-time rate limit usage** with progress bars.

```
🤖 Opus 4.6 │ 📊 25% │ ✏️  +42/-1 │ 🔀 main
⏱ 5h  ▰▰▱▱▱▱▱▱▱▱  17%  Resets 3am (Asia/Tokyo)
📅 7d  ▰▰▰▱▱▱▱▱▱▱  35%  Resets Mar 6 at 4pm (Asia/Tokyo)
```

## What it shows

| Section | Description |
|---------|-------------|
| 🤖 Model | Active Claude model name |
| 📊 Context | Context window usage percentage |
| ✏️ Changes | Lines added/removed (`git diff --numstat HEAD`) |
| 🔀 Branch | Current git branch, tag, or commit hash |
| ⏱ 5h | 5-hour rate limit usage with progress bar |
| 📅 7d | 7-day rate limit usage with progress bar |

Colors change based on usage:
- **Green** (#97C9C3): 0-49%
- **Yellow** (#E5C07B): 50-79%
- **Red** (#E06C75): 80-100%

## Requirements

- **macOS** (uses Keychain for OAuth token access)
- `bash`, `jq`, `curl`, `python3`, `git`
- Claude Code with an active OAuth session (Claude Pro / Max / Team)

## Install

```bash
git clone https://github.com/zytakeshi/statusline4claudecode.git
cd statusline4claudecode
bash install.sh
```

The installer:
1. Copies `statusline.sh` to `~/.claude/statusline-command.sh`
2. Configures `~/.claude/settings.json` with the `statusLine` command
3. Verifies your OAuth token is accessible

Restart Claude Code after installation.

### Manual install

```bash
cp statusline.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

## Uninstall

```bash
bash uninstall.sh
```

## Configuration

### Timezone

The default timezone is `Asia/Tokyo`. Override it by setting:

```bash
export STATUSLINE_TIMEZONE="America/New_York"
```

Add this to your `~/.zshrc` or `~/.bashrc` to persist.

### Cache TTL

Rate limit data is cached for 360 seconds (6 minutes) by default. Override:

```bash
export STATUSLINE_CACHE_TTL=120  # 2 minutes
```

### Cache location

```bash
export STATUSLINE_CACHE_FILE="/tmp/my-claude-cache.json"
```

## How it works

1. Claude Code pipes session JSON (model, context %, working directory) to the script via stdin
2. The script reads git branch and diff stats from the working directory
3. OAuth token is extracted from macOS Keychain (`Claude Code-credentials`)
4. Rate limit data is fetched from `https://api.anthropic.com/api/oauth/usage` with the `anthropic-beta: oauth-2025-04-20` header
5. Results are cached to avoid repeated API calls
6. Output is rendered as 3 ANSI-colored lines

## Troubleshooting

### Rate limits show 0%

- Ensure you're signed in to Claude Code with OAuth (not API key)
- Check that `security find-generic-password -s "Claude Code-credentials" -w` returns data
- Try deleting the cache: `rm /tmp/claude-usage-cache.json`

### "unknown" reset times

- Ensure `python3` is available in your PATH
- The API may not return reset times if you haven't hit any limits yet

### Script errors

Test the script manually:

```bash
echo '{"model":{"display_name":"Test"},"context_window":{"used_percentage":50},"workspace":{"current_dir":"'"$(pwd)"'"}}' \
  | bash ~/.claude/statusline-command.sh
```

## License

MIT
