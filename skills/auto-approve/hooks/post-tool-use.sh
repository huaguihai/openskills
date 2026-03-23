#!/usr/bin/env bash
# PostToolUse hook: 记录每次工具执行到审计日志
# 读 stdin JSON，提取工具名和关键输入，追加到 approval-log.jsonl

set -euo pipefail

LOG_DIR="$HOME/.claude/auto-approve/data"
LOG_FILE="$LOG_DIR/approval-log.jsonl"

# 确保日志目录存在
mkdir -p "$LOG_DIR"

# 读取 stdin
INPUT=$(cat)

# 提取 tool_name
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [ -z "$TOOL_NAME" ]; then
  echo '{}'
  exit 0
fi

# 根据工具类型提取标识符
case "$TOOL_NAME" in
  Bash)
    IDENTIFIER=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    ;;
  Edit)
    IDENTIFIER=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    ;;
  Write)
    IDENTIFIER=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    ;;
  Read)
    IDENTIFIER=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    ;;
  Glob)
    IDENTIFIER=$(echo "$INPUT" | jq -r '.tool_input.pattern // empty')
    ;;
  Grep)
    IDENTIFIER=$(echo "$INPUT" | jq -r '.tool_input.pattern // empty')
    ;;
  *)
    IDENTIFIER=$(echo "$INPUT" | jq -r '.tool_input | tostring' 2>/dev/null || echo "")
    ;;
esac

# 追加到审计日志
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
jq -n -c \
  --arg ts "$TS" \
  --arg tool "$TOOL_NAME" \
  --arg input "$IDENTIFIER" \
  '{"ts":$ts,"tool":$tool,"input":$input}' >> "$LOG_FILE"

# 永不阻断
echo '{}'
exit 0
