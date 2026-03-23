#!/usr/bin/env bash
# 飞书图片发送脚本
# 自动获取 token → 上传图片 → 发送图片消息
#
# 用法: bash send-feishu.sh <image_path> [open_id]
# 如不指定 open_id，自动从 config.env 的 CTI_FEISHU_ALLOWED_USERS 读取

set -euo pipefail

IMAGE_PATH="${1:?用法: send-feishu.sh <image_path> [open_id]}"
CONFIG_ENV="$HOME/.claude-to-im/config.env"

if [[ ! -f "$IMAGE_PATH" ]]; then
  echo "ERROR: 图片文件不存在: $IMAGE_PATH" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_ENV" ]]; then
  echo "ERROR: 飞书配置不存在: $CONFIG_ENV" >&2
  exit 1
fi

# 读取飞书配置
source "$CONFIG_ENV"

APP_ID="${CTI_FEISHU_APP_ID:?缺少 CTI_FEISHU_APP_ID}"
APP_SECRET="${CTI_FEISHU_APP_SECRET:?缺少 CTI_FEISHU_APP_SECRET}"
DOMAIN="${CTI_FEISHU_DOMAIN:-https://open.feishu.cn}"
OPEN_ID="${2:-${CTI_FEISHU_ALLOWED_USERS:?缺少接收人 open_id}}"

# Step 1: 获取 tenant_access_token
echo "获取飞书 token..." >&2
TOKEN_RESP=$(curl -s --max-time 10 \
  "${DOMAIN}/open-apis/auth/v3/tenant_access_token/internal" \
  -H "Content-Type: application/json" \
  -d "{\"app_id\":\"${APP_ID}\",\"app_secret\":\"${APP_SECRET}\"}")

TENANT_TOKEN=$(echo "$TOKEN_RESP" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data.get('code') != 0:
    print('ERROR:' + data.get('msg', 'unknown'), file=sys.stderr)
    sys.exit(1)
print(data['tenant_access_token'])
") || { echo "ERROR: 获取 token 失败" >&2; exit 1; }

echo "Token 获取成功" >&2

# Step 2: 上传图片
echo "上传图片到飞书..." >&2
UPLOAD_RESP=$(curl -s --max-time 30 \
  "${DOMAIN}/open-apis/im/v1/images" \
  -H "Authorization: Bearer ${TENANT_TOKEN}" \
  -F "image_type=message" \
  -F "image=@${IMAGE_PATH}")

IMAGE_KEY=$(echo "$UPLOAD_RESP" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data.get('code') != 0:
    print('ERROR:' + data.get('msg', 'unknown'), file=sys.stderr)
    sys.exit(1)
print(data['data']['image_key'])
") || { echo "ERROR: 上传图片失败" >&2; exit 1; }

echo "图片上传成功: ${IMAGE_KEY}" >&2

# Step 3: 发送图片消息
echo "发送图片消息..." >&2
SEND_RESP=$(curl -s --max-time 10 \
  "${DOMAIN}/open-apis/im/v1/messages?receive_id_type=open_id" \
  -H "Authorization: Bearer ${TENANT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"receive_id\": \"${OPEN_ID}\",
    \"msg_type\": \"image\",
    \"content\": \"{\\\"image_key\\\":\\\"${IMAGE_KEY}\\\"}\"
  }")

SEND_OK=$(echo "$SEND_RESP" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data.get('code') != 0:
    print('ERROR:' + data.get('msg', 'unknown'), file=sys.stderr)
    sys.exit(1)
print('ok')
") || { echo "ERROR: 发送消息失败" >&2; exit 1; }

echo "图片已成功发送到飞书!" >&2
