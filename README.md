# openskills

Open-source AI agent skills for [OpenClaw](https://github.com/anthropics/openclaw) and Claude Code.

[🇨🇳 中文版](README_CN.md)

## Skills

| Skill | Description |
|-------|-------------|
| [sentinel](skills/sentinel/) | Unified security — skill vetting, dependency interception (3-layer defense), project vulnerability scan, system audit |
| [blog-pipeline](skills/blog-pipeline/) | End-to-end blog writing pipeline with style enforcement and independent review |
| [public-apis](skills/public-apis/) | Find and recommend free public APIs across 51 categories |
| [opportunity-radar](skills/opportunity-radar/) | Indie dev opportunity discovery — 10 transformation strategies to find software business ideas from products/markets/news |
| [smart-fetch](skills/smart-fetch/) | Smart web scraping router — auto-selects the right tool (Jina/WebFetch/curl) for any URL, zero dependencies |

## Sentinel — Supply Chain Defense

Born from the [LiteLLM PyPI attack (2026-03-24)](https://x.com/karpathy/status/2036487306585268612). A single `pip install` was enough to exfiltrate SSH keys, AWS credentials, and API keys from a package with 97M monthly downloads.

Sentinel internalizes security into the agent itself — no technical knowledge required from the user.

**4 modules:**

| Module | What it does | Trigger |
|--------|-------------|---------|
| M1: Skill Review | Code audit before installing any skill (13 red flags + 6 enhanced checks) | Auto on skill install |
| M2: Dependency Interception | 3-layer defense: pre-install metadata check → post-install code scan → deep download-and-inspect | Auto via Claude Code hooks |
| M3: Project Health Check | Scan existing dependencies for known vulnerabilities (npm audit + pip-audit + OSV) | `/sentinel check` |
| M4: System Audit | Process/network anomalies, credential DLP, file integrity, disk usage | `/sentinel audit` |

**M2 vs the LiteLLM attack:**

| Attack vector | Layer 1 (Pre) | Layer 2 (Post) | Layer 3 (Deep) | Result |
|--------------|:---:|:---:|:---:|--------|
| Direct `pip install litellm` | Flags new version + maintainer change | — | Detects .pth + base64 | Blocked |
| Transitive via `pip install dspy` | dspy passes | Detects litellm .pth in new packages | — | Alert + rollback |

## Installation

```bash
# Copy a single skill to OpenClaw
cp -r skills/sentinel ~/.openclaw/skills/

# Or to Claude Code
cp -r skills/sentinel ~/.claude/skills/
```

For sentinel's full auto-interception (M2), you also need to configure Claude Code hooks — see [sentinel/SKILL.md](skills/sentinel/SKILL.md) for details.

## Structure

```
skills/
├── sentinel/          # Security: vetting + dependency defense + audit
│   ├── SKILL.md
│   ├── scripts/       # check-package.sh, scan-installed.sh, etc.
│   └── references/    # red-flags.md, known-malicious.md, suspicious-patterns.md
├── opportunity-radar/ # Indie dev opportunity discovery
│   └── SKILL.md
├── blog-pipeline/     # Blog writing pipeline
├── public-apis/       # Public API discovery
└── smart-fetch/       # Smart web scraping router (Jina/WebFetch/curl)
    ├── SKILL.md
    └── references/    # site-patterns.md
```

## License

MIT
