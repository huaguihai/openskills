#!/usr/bin/env bash
# auto-approve skill 卸载脚本
# 用法: bash uninstall.sh

set -euo pipefail

TARGET_DIR="$HOME/.claude/auto-approve"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "=== auto-approve 卸载 ==="
echo ""

# 移除 hooks 注册
if [ -f "$SETTINGS_FILE" ] && command -v jq &>/dev/null; then
  if jq -e '.hooks' "$SETTINGS_FILE" &>/dev/null; then
    TMP=$(mktemp)
    jq 'del(.hooks)' "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
    echo "已从 $SETTINGS_FILE 移除 hooks 注册"
    echo "注意: 如果你有其他 hooks，请手动恢复。"
  fi
fi

# 询问是否保留数据
echo ""
read -rp "是否保留审计日志和已学习规则？[Y/n] " keep_data
if [[ "$keep_data" =~ ^[Nn] ]]; then
  rm -rf "$TARGET_DIR"
  echo "已删除 $TARGET_DIR（含所有数据）"
else
  rm -f "$TARGET_DIR/hooks/pre-tool-use.sh"
  rm -f "$TARGET_DIR/hooks/post-tool-use.sh"
  rm -f "$TARGET_DIR/analyze.py"
  rm -f "$TARGET_DIR/deny-patterns.json"
  rmdir "$TARGET_DIR/hooks" 2>/dev/null || true
  echo "已删除脚本，保留 $TARGET_DIR/data/"
fi

echo ""
echo "卸载完成。请重启 Claude Code。"
