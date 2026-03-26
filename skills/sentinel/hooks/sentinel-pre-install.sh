#!/usr/bin/env bash
# sentinel-pre-install.sh — Sentinel M2 PreToolUse Hook
# Intercepts npm install / pip install and runs check-package.sh
# Only blocks on hard signals (typosquatting/known-malicious/publish-age<48h/registry missing)
# OSV historical vulns are NOT used for blocking (querying without version causes false positives)
#
# Usage: Add to Claude Code settings.json hooks.PreToolUse
# or embed into your existing pre-tool-use hook

set -euo pipefail

SENTINEL_DIR="${SENTINEL_DIR:-$HOME/.claude/skills/sentinel/scripts}"

# Read stdin (Claude Code Hook protocol: JSON with tool_name, tool_input)
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only handle Bash tool
if [ "$TOOL_NAME" != "Bash" ]; then
  echo '{}'
  exit 0
fi

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# sentinel_should_block: only check hard signals
# osv-vulns without version returns historical CVEs — not used for blocking
sentinel_should_block() {
  local result="$1"
  python3 -c "
import json,sys
d=json.loads(sys.stdin.read())
hard_red=[s for s in d.get('signals',[]) if s['level']=='red' and s['dimension'] in ('known-malicious','typosquatting','publish-age','registry')]
if hard_red:
    reasons='; '.join(s['dimension']+': '+s['value'] for s in hard_red)
    print(reasons)
else:
    print('')
" <<< "$result" 2>/dev/null || echo ""
}

# Detect npm install / yarn add / pnpm add
if echo "$CMD" | grep -qE '(npm install|npm i |yarn add|pnpm add)\s+[^-]'; then
  PKG=$(echo "$CMD" | grep -oE '(npm install|npm i |yarn add|pnpm add)\s+\S+' | awk '{print $NF}' | sed 's/@.*//')
  if [ -n "$PKG" ] && [ -x "$SENTINEL_DIR/check-package.sh" ]; then
    RESULT=$("$SENTINEL_DIR/check-package.sh" npm "$PKG" 2>/dev/null || echo '{"verdict":"green"}')
    BLOCK_REASON=$(sentinel_should_block "$RESULT")
    if [ -n "$BLOCK_REASON" ]; then
      echo "{\"decision\":\"block\",\"reason\":\"🔴 Sentinel: ${BLOCK_REASON}\"}"
      exit 0
    fi
  fi
fi

# Detect pip install / pip3 install
if echo "$CMD" | grep -qE '(pip3? install)\s+[^-]'; then
  PKG=$(echo "$CMD" | grep -oE '(pip3? install)\s+\S+' | awk '{print $NF}' | sed 's/[>=<].*//')
  if [ -n "$PKG" ] && [ -x "$SENTINEL_DIR/check-package.sh" ]; then
    RESULT=$("$SENTINEL_DIR/check-package.sh" pypi "$PKG" 2>/dev/null || echo '{"verdict":"green"}')
    BLOCK_REASON=$(sentinel_should_block "$RESULT")
    if [ -n "$BLOCK_REASON" ]; then
      echo "{\"decision\":\"block\",\"reason\":\"🔴 Sentinel: ${BLOCK_REASON}\"}"
      exit 0
    fi
  fi
fi

# No install command detected — pass through
echo '{}'
exit 0
