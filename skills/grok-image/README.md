# grok-image

AI image generation skill for Claude Code, powered by Grok Imagine models.

## Features

- **Multi-model**: grok-imagine-1.0 (standard), fast (quick), edit (editing)
- **Auto failover**: Discovers providers from proxy pool, tries each until success
- **Provider scoring**: Learns which providers are reliable — best ones tried first
- **Injection-safe**: Prompt via environment variables, never interpolated into code
- **Multi-channel delivery**: Unified `send.sh` routes to Feishu, Telegram, Discord
- **Bilingual triggers**: Chinese and English image generation requests

## Prerequisites

- Proxy pool config at `~/clawd/proxy/config.json` with `grok-imagine-1.0` providers
- Python 3, curl

For IM delivery (optional), add to `~/.claude-to-im/config.env`:
- **Feishu**: `CTI_FEISHU_APP_ID`, `CTI_FEISHU_APP_SECRET`, `CTI_FEISHU_ALLOWED_USERS`
- **Telegram**: `CTI_TG_BOT_TOKEN`, `CTI_TG_CHAT_ID`
- **Discord**: `CTI_DISCORD_WEBHOOK_URL`

## Installation

```bash
ln -s /path/to/openskills/skills/grok-image ~/.claude/skills/grok-image
```

## Usage

Ask Claude to generate an image in any language, or use `/grok-image`.

## License

MIT
