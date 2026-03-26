#!/usr/bin/env bash
# sentinel-pre-install.sh — Sentinel M2 PreToolUse Hook
# 拦截 npm install / pip install，调用 check-package.sh 审查
# 只拦截硬信号(typosquatting/known-malicious/publish-age<48h/registry不存在)
# OSV 历史漏洞不作为拦截依据（不带版本号查会误杀正常包）
#
# 用法: 在 Claude Code settings.json 的 hooks.PreToolUse 中添加本脚本
# 或嵌入到已有的 pre-tool-use hook 中

set -euo pipefail

SENTINEL_DIR="${SENTINEL_DIR:-$HOME/.claude/skills/sentinel/scripts}"

# 读取 stdin (Claude Code Hook 协议: JSON with tool_name, tool_input)
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# 只处理 Bash 工具
if [ "$TOOL_NAME" != "Bash" ]; then
  echo '{}'
  exit 0
fi

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# sentinel_should_block: 只看硬信号
# osv-vulns 不带版本号查会返回历史漏洞，不作为拦截依据
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

# 检测 npm install / yarn add / pnpm add
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

# 检测 pip install / pip3 install
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

# 未命中 install 命令，放行
echo '{}'
exit 0
