# grok-image

AI image generation skill for Claude Code, powered by Grok Imagine models.

## Features

- **Multi-model support**: grok-imagine-1.0 (standard), fast (quick), edit (editing)
- **Auto failover**: Discovers providers from proxy pool, tries each until success
- **Provider scoring**: Tracks reliability per provider — reliable ones tried first, flaky ones deprioritized
- **Injection-safe**: Prompt passed via environment variables, never interpolated into code
- **IM delivery**: One-click send to Feishu/Lark
- **Bilingual triggers**: Chinese and English image generation requests

## Prerequisites

- Proxy pool config at `~/clawd/proxy/config.json` with `grok-imagine-1.0` providers
- Python 3, curl
- (Optional) `~/.claude-to-im/config.env` for Feishu delivery

## Installation

```bash
ln -s /path/to/openskills/skills/grok-image ~/.claude/skills/grok-image
```

## Usage

Ask Claude to generate an image in any language, or use `/grok-image`.

## License

MIT
