# claude-statusline

Minimal statusline for [Claude Code](https://claude.ai/code) — shows model, context usage, session time, effort level, cost, and rate limits.

```
sonnet-4.6 | 🧠  9% · 93k/200k | ⏱ 44m | ◑ high | $0.42
5h ▪▪▪▪▫▫▫▫▫▫▫▫ 34% ↻ 4:40pm  |  7d ▫▫▫▫▫▫▫▫▫▫▫▫ 4% ↻ may 30, 7:00am
```

## What it shows

**Line 1** — session info:
- Model name (shortened)
- 🧠 Context usage — percent + tokens used/total, color-coded
- ⏱ Session duration
- Effort level indicator (`◔` low → `◉` xhigh)
- Session cost in USD

**Line 2** — rate limits (hidden when not available):
- 5-hour window — usage bar + reset time
- 7-day window — usage bar + reset date

Colors shift from green → yellow → orange → red as usage increases.

## Requirements

- [Claude Code](https://claude.ai/code) v2.1+
- `jq`
- `bash`

Install `jq` if needed:
```bash
# macOS
brew install jq

# Ubuntu/Debian
apt install jq
```

## Install

```bash
npx github:slpuh/claude-statusline
```

Restart Claude Code after installation.

## Remove

```bash
npx github:slpuh/claude-statusline --remove
```

## License

MIT
