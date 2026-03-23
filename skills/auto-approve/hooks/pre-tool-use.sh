#!/usr/bin/env bash
# PreToolUse hook: 查询 learned-rules.json，命中则自动放行
# 读 stdin JSON，提取工具名和标识符，逐条正则匹配

set -euo pipefail

BASE_DIR="$HOME/.claude/auto-approve"
RULES_FILE="$BASE_DIR/data/learned-rules.json"
LOG_FILE="$BASE_DIR/data/approval-log.jsonl"

# 读取 stdin
INPUT=$(cat)

# 规则文件不存在则跳过
if [ ! -f "$RULES_FILE" ]; then
  echo '{}'
  exit 0
fi

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
    echo '{}'
    exit 0
    ;;
esac

if [ -z "$IDENTIFIER" ]; then
  echo '{}'
  exit 0
fi

# 逐条匹配规则
MATCHED=$(jq -r --arg tool "$TOOL_NAME" --arg id "$IDENTIFIER" '
  .rules[] |
  select(.tool == $tool) |
  .regex as $re |
  select($id | test($re)) |
  .pattern
' "$RULES_FILE" 2>/dev/null | head -1)

if [ -n "$MATCHED" ]; then
  # 追加 [AUTO] 标记到审计日志
  mkdir -p "$(dirname "$LOG_FILE")"
  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  jq -n -c \
    --arg ts "$TS" \
    --arg tool "$TOOL_NAME" \
    --arg input "$IDENTIFIER" \
    --arg rule "$MATCHED" \
    '{"ts":$ts,"tool":$tool,"input":$input,"auto":true,"rule":$rule}' >> "$LOG_FILE"

  # 自动放行
  echo '{"decision":"approve"}'
  exit 0
fi

# 未命中，正常流程
echo '{}'
exit 0
