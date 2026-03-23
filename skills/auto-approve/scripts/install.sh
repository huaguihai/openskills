#!/usr/bin/env bash
# auto-approve skill 安装脚本
# 用法: bash install.sh

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="$HOME/.claude/auto-approve"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "=== auto-approve 安装 ==="
echo ""

# 检查依赖
if ! command -v jq &>/dev/null; then
  echo "错误: 需要 jq。请先安装: brew install jq"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "错误: 需要 python3。"
  exit 1
fi

# 创建目录
mkdir -p "$TARGET_DIR/hooks" "$TARGET_DIR/data"

# 复制文件
cp "$SKILL_DIR/hooks/post-tool-use.sh" "$TARGET_DIR/hooks/"
cp "$SKILL_DIR/hooks/pre-tool-use.sh" "$TARGET_DIR/hooks/"
cp "$SKILL_DIR/analyze.py" "$TARGET_DIR/"
cp "$SKILL_DIR/deny-patterns.json" "$TARGET_DIR/"

chmod +x "$TARGET_DIR/hooks/post-tool-use.sh"
chmod +x "$TARGET_DIR/hooks/pre-tool-use.sh"
chmod +x "$TARGET_DIR/analyze.py"

echo "文件已复制到 $TARGET_DIR"

# 注册 hooks 到 settings.json
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# 检查是否已注册
if jq -e '.hooks.PreToolUse' "$SETTINGS_FILE" &>/dev/null; then
  echo "注意: settings.json 已有 PreToolUse hooks，请手动检查是否需要合并。"
else
  # 添加 hooks
  TMP=$(mktemp)
  jq '.hooks = {
    "PreToolUse": [{
      "hooks": [{
        "type": "command",
        "command": "bash $HOME/.claude/auto-approve/hooks/pre-tool-use.sh",
        "timeout": 5000
      }]
    }],
    "PostToolUse": [{
      "hooks": [{
        "type": "command",
        "command": "bash $HOME/.claude/auto-approve/hooks/post-tool-use.sh",
        "timeout": 5000
      }]
    }]
  }' "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
  echo "已注册 hooks 到 $SETTINGS_FILE"
fi

echo ""
echo "安装完成！请重启 Claude Code 使 hooks 生效。"
echo "使用方法: 在 Claude Code 中输入 /auto-approve 触发分析"
