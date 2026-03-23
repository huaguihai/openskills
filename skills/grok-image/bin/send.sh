#!/usr/bin/env bash
# Unified image delivery to IM platforms
# Auto-detects configured channels and routes accordingly.
#
# Usage: send.sh <image_path> [channel]
#   channel: feishu, telegram, discord, all (default: first available)
#
# Config: reads from ~/.claude-to-im/config.env

set -euo pipefail

IMAGE_PATH="${1:?Usage: send.sh <image_path> [channel]}"
TARGET="${2:-auto}"
CONFIG_ENV="$HOME/.claude-to-im/config.env"

if [[ ! -f "$IMAGE_PATH" ]]; then
  echo "ERROR: Image not found: $IMAGE_PATH" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_ENV" ]]; then
  echo "ERROR: Config not found: $CONFIG_ENV" >&2
  echo "Create ~/.claude-to-im/config.env with your IM credentials." >&2
  exit 1
fi

source "$CONFIG_ENV"

BINDINGS_FILE="$HOME/.claude-to-im/data/bindings.json"
SENT=0
ERRORS=0

# ─── Source Detection ────────────────────────────────────────────
# When a message arrives via the claude-to-im bridge, the bridge
# updates the binding's `updatedAt` timestamp. By finding the most
# recently updated binding, we can infer which channel sent the
# current request and route the image back there.
detect_source_channel() {
  if [[ ! -f "$BINDINGS_FILE" ]]; then
    return 1
  fi

  python3 << 'DETECT_EOF'
import json, os, sys
from datetime import datetime, timezone, timedelta

bindings_path = os.environ.get("BINDINGS_FILE", "")
if not bindings_path or not os.path.exists(bindings_path):
    sys.exit(1)

with open(bindings_path) as f:
    bindings = json.load(f)

if not bindings:
    sys.exit(1)

# Find the most recently updated active binding
best = None
best_time = None
for key, b in bindings.items():
    if not b.get("active", False):
        continue
    updated = b.get("updatedAt", "")
    if not updated:
        continue
    try:
        t = datetime.fromisoformat(updated.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        continue
    if best_time is None or t > best_time:
        best_time = t
        best = b

if not best or not best_time:
    sys.exit(1)

# Only trust the detection if the binding was updated recently (within 5 min).
# Otherwise, this is likely a direct CLI session, not a bridge request.
now = datetime.now(timezone.utc)
if (now - best_time) > timedelta(minutes=5):
    sys.exit(1)

print(best["channelType"])
DETECT_EOF
}

export BINDINGS_FILE

# ─── Feishu / Lark ───────────────────────────────────────────────
send_feishu() {
  local app_id="${CTI_FEISHU_APP_ID:-}"
  local app_secret="${CTI_FEISHU_APP_SECRET:-}"
  local domain="${CTI_FEISHU_DOMAIN:-https://open.feishu.cn}"
  local open_id="${CTI_FEISHU_ALLOWED_USERS:-}"

  if [[ -z "$app_id" || -z "$app_secret" || -z "$open_id" ]]; then
    echo "  Feishu: skipped (missing config)" >&2
    return 1
  fi

  echo "  Feishu: getting token..." >&2
  local token
  token=$(curl -s --max-time 10 \
    "${domain}/open-apis/auth/v3/tenant_access_token/internal" \
    -H "Content-Type: application/json" \
    -d "{\"app_id\":\"${app_id}\",\"app_secret\":\"${app_secret}\"}" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['tenant_access_token']) if d.get('code')==0 else (print('FAIL:'+d.get('msg',''),file=sys.stderr) or exit(1))" \
  ) || { echo "  Feishu: token failed" >&2; return 1; }

  echo "  Feishu: uploading..." >&2
  local image_key
  image_key=$(curl -s --max-time 30 \
    "${domain}/open-apis/im/v1/images" \
    -H "Authorization: Bearer ${token}" \
    -F "image_type=message" \
    -F "image=@${IMAGE_PATH}" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['data']['image_key']) if d.get('code')==0 else (print('FAIL:'+d.get('msg',''),file=sys.stderr) or exit(1))" \
  ) || { echo "  Feishu: upload failed" >&2; return 1; }

  curl -s --max-time 10 \
    "${domain}/open-apis/im/v1/messages?receive_id_type=open_id" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "{\"receive_id\":\"${open_id}\",\"msg_type\":\"image\",\"content\":\"{\\\"image_key\\\":\\\"${image_key}\\\"}\"}" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('code')==0 else 1)" \
    || { echo "  Feishu: send failed" >&2; return 1; }

  echo "  Feishu: sent!" >&2
  return 0
}

# ─── Telegram ────────────────────────────────────────────────────
send_telegram() {
  local bot_token="${CTI_TG_BOT_TOKEN:-}"
  local chat_id="${CTI_TG_CHAT_ID:-}"
  local proxy=""

  if [[ -z "$bot_token" || -z "$chat_id" ]]; then
    echo "  Telegram: skipped (missing config)" >&2
    return 1
  fi

  # Telegram is blocked in China, use proxy if configured
  if [[ -n "${HTTPS_PROXY:-}" ]]; then
    proxy="--proxy ${HTTPS_PROXY}"
  fi

  echo "  Telegram: sending photo..." >&2
  local resp
  resp=$(curl -s --max-time 30 $proxy \
    "https://api.telegram.org/bot${bot_token}/sendPhoto" \
    -F "chat_id=${chat_id}" \
    -F "photo=@${IMAGE_PATH}" \
  ) || { echo "  Telegram: request failed" >&2; return 1; }

  local ok
  ok=$(echo "$resp" | python3 -c "import json,sys; d=json.load(sys.stdin); print('ok' if d.get('ok') else 'fail:'+str(d.get('description','')))" 2>/dev/null)

  if [[ "$ok" == "ok" ]]; then
    echo "  Telegram: sent!" >&2
    return 0
  else
    echo "  Telegram: ${ok}" >&2
    return 1
  fi
}

# ─── Discord (webhook) ──────────────────────────────────────────
send_discord() {
  local webhook_url="${CTI_DISCORD_WEBHOOK_URL:-}"

  if [[ -z "$webhook_url" ]]; then
    echo "  Discord: skipped (missing CTI_DISCORD_WEBHOOK_URL)" >&2
    return 1
  fi

  echo "  Discord: sending via webhook..." >&2
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 \
    "$webhook_url" \
    -F "file=@${IMAGE_PATH}" \
  ) || { echo "  Discord: request failed" >&2; return 1; }

  if [[ "$http_code" == "200" || "$http_code" == "204" ]]; then
    echo "  Discord: sent!" >&2
    return 0
  else
    echo "  Discord: HTTP ${http_code}" >&2
    return 1
  fi
}

# ─── Router ──────────────────────────────────────────────────────
available_channels() {
  local channels=()
  [[ -n "${CTI_FEISHU_APP_ID:-}" ]] && channels+=("feishu")
  [[ -n "${CTI_TG_BOT_TOKEN:-}" ]] && channels+=("telegram")
  [[ -n "${CTI_DISCORD_WEBHOOK_URL:-}" ]] && channels+=("discord")
  echo "${channels[*]}"
}

send_to() {
  local ch="$1"
  case "$ch" in
    feishu)   send_feishu   ;;
    telegram) send_telegram ;;
    discord)  send_discord  ;;
    *) echo "  Unknown channel: $ch" >&2; return 1 ;;
  esac
}

# ─── Main ────────────────────────────────────────────────────────
AVAIL=$(available_channels)
echo "Available channels: ${AVAIL:-none}" >&2

if [[ -z "$AVAIL" ]]; then
  echo "ERROR: No IM channels configured in $CONFIG_ENV" >&2
  exit 1
fi

if [[ "$TARGET" == "all" ]]; then
  for ch in $AVAIL; do
    if send_to "$ch"; then
      SENT=$((SENT + 1))
    else
      ERRORS=$((ERRORS + 1))
    fi
  done
elif [[ "$TARGET" == "auto" ]]; then
  # Auto: detect source channel from bridge bindings, fall back to first available
  DETECTED=$(detect_source_channel 2>/dev/null) || DETECTED=""
  if [[ -n "$DETECTED" ]]; then
    echo "Source detected: ${DETECTED}" >&2
    if send_to "$DETECTED"; then
      SENT=1
    fi
  fi
  # Fallback if detection failed or send failed
  if [[ "$SENT" -eq 0 ]]; then
    for ch in $AVAIL; do
      if send_to "$ch"; then
        SENT=1
        break
      fi
    done
  fi
else
  # Specific channel
  if send_to "$TARGET"; then
    SENT=1
  else
    ERRORS=1
  fi
fi

if [[ "$SENT" -gt 0 ]]; then
  echo "Delivered to ${SENT} channel(s)" >&2
  exit 0
else
  echo "ERROR: Failed to deliver to any channel" >&2
  exit 1
fi
