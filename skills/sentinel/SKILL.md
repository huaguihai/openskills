---
name: sentinel
version: 1.1.0
description: >
  Unified security skill. Skill vetting, dependency install interception (3-layer defense),
  project vulnerability audit, and system security inspection.
  Trigger words: security audit, dependency check, vulnerability scan, sentinel, install skill,
  pip install, npm install, is this package safe, audit, inspection, vetting.
  Supersedes skill-vetter.
---

# Sentinel — Unified Security Protection

All security capabilities in one place. 4 modules, automatic triggers, users only make traffic-light decisions.

---

## Module Overview

| Module | Function | Trigger |
|--------|----------|---------|
| M1 | Skill security review | Auto-triggered before skill installation |
| M2 | Dependency install interception (3-layer) | PreToolUse + PostToolUse Hook |
| M3 | Project dependency audit | `/sentinel check` or periodic |
| M4 | System security inspection | `/sentinel audit` or daily cron |

---

## M1: Skill Security Review

> Inherits all skill-vetter capabilities + enhancements

### Trigger

User requests to install a skill (from ClawdHub, GitHub, or other sources), or agent detects skill installation intent.

### Step 1: Source Verification

Answer the following:
- Source? (ClawdHub / GitHub / other)
- Is the author well-known / trusted?
- Star count / download count?
- Last updated?
- Any user reviews?

### Step 2: Code Review (mandatory)

Read **all files** in the skill. Check against the following red-line checklist (any match → flag immediately):

#### Base Red Lines (inherited from skill-vetter)

```
🚨 Flag on match:
─────────────────────────────────────────
• curl/wget to unknown URLs
• Sending data to external servers
• Requesting credentials/tokens/API keys
• Reading ~/.ssh, ~/.aws, ~/.config (without clear justification)
• Accessing MEMORY.md, USER.md, SOUL.md, IDENTITY.md
• Using base64 decode
• Using eval()/exec() on external input
• Modifying system files outside workspace
• Installing undeclared packages
• Network calls using IP addresses instead of domains
• Obfuscated code (compressed, encoded, minified)
• Requesting sudo privileges
• Accessing browser cookies/sessions
• Touching credential files
```

#### Enhanced Red Lines (sentinel additions)

```
🚨 Additional checks:
─────────────────────────────────────────
• Contains .pth files
• Large base64/hex encoded content (>100 chars)
• Modifies CLAUDE.md or settings.json (privilege escalation)
• Registers Claude Code Hooks (can hijack other operations)
• scripts/ contains network calls (curl, wget, fetch, requests)
  → Check target URLs against known-malicious.md
• Introduces external dependencies → chain to M2 for each dependency
```

### Step 3: Permission Scope Assessment

- Which files does it need to read?
- Which files does it need to write?
- Which commands does it need to execute?
- Does it need network access? To where?
- Is the permission scope minimized?

### Step 4: Risk Classification

| Level | Examples | Action |
|-------|----------|--------|
| 🟢 LOW | Notes, formatting, local tools | Install after basic review |
| 🟡 MEDIUM | File operations, browser, API calls | Full code review required |
| 🔴 HIGH | Credentials, transactions, system config | User confirmation required |
| ⛔ EXTREME | Security config, root access, Hook registration | Do not install |

### Step 5: Trust Tiers

1. **Official OpenClaw skills** → Lower scrutiny (still reviewed)
2. **High-star repos (1000+)** → Medium scrutiny
3. **Known authors** → Medium scrutiny
4. **New/unknown sources** → Maximum scrutiny
5. **Skills requesting credentials** → User confirmation required

### Step 6: Output Report

```
SENTINEL Security Review Report
═══════════════════════════════════════
Skill: [name]
Source: [ClawdHub / GitHub / other]
Author: [username]
Version: [version]
───────────────────────────────────────
Metrics:
• Stars/Downloads: [count]
• Last updated: [date]
• Files reviewed: [count]
───────────────────────────────────────
Red-line hits: [none / list specific items]

Permissions required:
• Files: [list or "none"]
• Network: [list or "none"]
• Commands: [list or "none"]

External dependencies: [list or "none"]
  → Dependency review: [passed / see M2 report]
───────────────────────────────────────
Risk level: [🟢 LOW / 🟡 MEDIUM / 🔴 HIGH / ⛔ EXTREME]

Conclusion: [✅ Safe to install / ⚠️ Install with caution / ❌ Do not install]

Notes: [additional remarks]
═══════════════════════════════════════
```

---

## M2: Dependency Install Interception (3-Layer Defense)

### Hook Setup (required — M2 won't work without it)

M2 requires a Claude Code Hook to auto-intercept. Choose one of two methods:

**Method A: Standalone Hook (recommended for new users)**

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash $HOME/.claude/skills/sentinel/hooks/sentinel-pre-install.sh",
            "timeout": 15000
          }
        ]
      }
    ]
  }
}
```

**Method B: Embed in existing Hook (for users with existing PreToolUse hooks)**

Embed the core logic from `hooks/sentinel-pre-install.sh` into your existing pre-tool-use hook. See the `sentinel_should_block` function in the script.

> **Important**: Only hard signals trigger blocking (typosquatting, known-malicious, publish-age < 48h, registry missing). OSV historical vulnerabilities queried without a version number can cause false positives on safe packages (e.g., express, flask), so they are not used for automatic blocking.

### Trigger

Auto-triggered when the agent executes `pip install`, `pip3 install`, `npm install`, `yarn add`, or `pnpm add`, via Claude Code Hook.

### Layer 1: Pre-Install Gate

**After PreToolUse Hook intercepts the command, the following checks run:**

1. Extract package name and version from the command
2. Run `scripts/check-package.sh <ecosystem> <package> [version]`
3. Script queries registry + OSV database, returns risk score

**Multi-dimensional cross-evaluation (not just one metric):**

| Dimension | Green | Yellow | Red |
|-----------|-------|--------|-----|
| Publish age | > 30 days | < 7 days | < 48 hours |
| Maintainer consistency | Unchanged | — | Changed |
| Version jump | Normal increment | Minor anomaly | Major jump |
| Release interval | Matches history | — | Sudden insertion |
| OSV vulnerabilities | None | Low severity | Medium/High severity |
| known-malicious | Not listed | — | Listed |
| Typosquatting | No ambiguity | — | Highly similar to popular package |

**Decision rules:**
- 🟢 All dimensions normal → Allow, notify user
- 🟡 Single suspicious signal → Warn user, let them decide; auto-escalate to Layer 3
- 🔴 Multiple suspicious signals / known malicious → Block, explain reason

**User-facing examples:**

> 🟢 `requests 2.31.0` — Safe, allowed.

> 🟡 `some-package 3.1.0` — Latest version published 3 hours ago with maintainer change. Consider waiting or pinning the previous version. Continue or skip?

> 🔴 `req-uests 1.0.0` — Name highly similar to `requests` (typosquatting), published less than 1 day ago. Blocked.

### Layer 2: Post-Install Scan

**Catches transitive dependency blind spots. PostToolUse Hook triggers after install succeeds.**

1. Compare package list before and after install (pre-hook saved a snapshot)
2. Identify all newly added packages (including transitive dependencies)
3. Run `scripts/scan-installed.sh` on each new package:
   - Check version publish age
   - Scan install directory for suspicious patterns from `references/suspicious-patterns.md`:
     - `.pth` files
     - `setup.py` / `setup.cfg` post_install hooks
     - Large base64/hex encoded strings (>100 chars)
     - Network calls to non-well-known domains
     - Filesystem scanning patterns (traversing `~/.ssh`, `~/.aws`, `~/.kube`)
     - Bulk environment variable reading (`os.environ` mass enumeration)
4. If suspicious → red alert + recommend immediate uninstall

**User-facing example:**

> 🔴 Urgent — a dangerous transitive dependency was pulled in by dspy:
>
> **litellm 1.82.8** (published 45 minutes ago) contains malicious code:
> - Found `litellm_init.pth` file
> - Contains base64-encoded instructions that read ~/.ssh, ~/.aws and send to external server
>
> Recommend immediate uninstall. Should I run `pip uninstall litellm`?

### Layer 3: Deep Inspection (Download & Inspect)

**Auto-triggered when Layer 1 returns 🟡 or 🔴.**

1. `pip download --no-deps -d /tmp/sentinel-inspect/ <pkg>==<version>` — download without installing
2. Extract `.whl` or `.tar.gz`
3. Run `scripts/download-and-inspect.sh` for full scan:
   - All `.pth` files
   - Top-level network calls in `__init__.py`
   - `setup.py` `cmdclass` overrides
   - Obfuscation signatures (`exec()`, `eval()`, `compile()` + encoded strings)
   - Unexpected file types (binaries in a pure Python package)
4. Generate scan report
5. Clean up `/tmp/sentinel-inspect/`

---

## M3: Project Dependency Audit

### Trigger

- User says "audit", "vulnerability scan", "sentinel check"
- `/sentinel check` — current project
- `/sentinel check --all` — all known projects

### Workflow

1. Detect project type (package.json / requirements.txt / pyproject.toml)
2. Node.js: `npm audit --json`
3. Python: `pip-audit -r requirements.txt --format json` (auto-installs pip-audit on first run)
4. All projects: query OSV API (`https://api.osv.dev/v1/query`) for cross-validation
5. Output traffic-light summary

**User-facing example:**

```
📋 Project Audit: clawdbot-blog
├── 🟢 0 high-severity vulnerabilities
├── 🟡 2 medium-severity vulnerabilities
│   ├── next 14.2.3 → CVE-2024-xxx (recommend upgrade to 15.x)
│   └── postcss 8.4.1 → CVE-2024-yyy (recommend upgrade to 8.5+)
└── 🟢 No plaintext credential leaks
```

---

## M4: System Security Inspection

### Trigger

- User says "inspection", "security audit", "sentinel audit"
- `/sentinel audit` — quick version (processes/network, file changes, credential DLP, skill integrity)
- `/sentinel audit --full` — full version (equivalent to nightly)
- Daily 03:00 auto-execution (nightly cron)

### Quick Inspection Items

1. **Processes/Network** — Unusual listening ports, unusual outbound connections
2. **File Changes** — File modifications in sensitive directories within 24h
3. **Credential DLP** — Scan workspace for plaintext credential leaks
4. **Skill Integrity** — SHA256 baseline comparison, detect skill file tampering
5. **Disk Capacity** — Alert when usage exceeds 85%

### Full Inspection (additional items)

6. SSH login records and brute-force detection
7. System-level cron job scan
8. OpenClaw cron job health check
9. Critical file integrity (SHA256 + permissions)
10. Yellow-line operation cross-validation
11. Gateway configuration check

### Alert Notifications

When red-light issues are found, alerts are pushed via configured messaging channels (Telegram / Feishu / Lark):

```
🔴 Sentinel Security Alert
─────────────────────────────
[Alert summary]
Details: [report file path]
```

---

## Honest Boundaries

Sentinel can defend against most common supply-chain attacks, but cannot protect against:

- Replaced existing versions with no detectable signature changes (registry-level issue)
- Direct shell operations outside Claude Code (e.g., manual pip install via SSH)
- Zero-day attack patterns not yet documented in suspicious-patterns.md

These are inherent limitations of client-side security, requiring registry-level and system-level protections as well.

---

## Principles

- Security is not optional — it's the default
- When in doubt, block and let the user decide
- Red = block + explain, Yellow = warn + user choice, Green = allow + notify
- Better to over-block once than to miss once
- Pattern libraries (suspicious-patterns.md, known-malicious.md) are continuously updated

*Paranoia is a feature.* 🔒
