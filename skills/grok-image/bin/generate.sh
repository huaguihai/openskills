#!/usr/bin/env bash
# Grok Imagine image generation script
# Reads providers from proxy pool config, tries each until one succeeds.
#
# Usage: generate.sh "<prompt>" [size] [model]
# Output: Image file path on stdout (exit 0), or error on stderr (exit 1)
#
# The prompt is passed to Python via environment variable — never interpolated
# into code strings — to prevent injection attacks.

set -euo pipefail

PROMPT="${1:?Usage: generate.sh \"<prompt>\" [size] [model]}"
SIZE="${2:-1024x1024}"
MODEL="${3:-grok-imagine-1.0}"
CONFIG_FILE="$HOME/clawd/proxy/config.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATS_PY="${SCRIPT_DIR}/provider_stats.py"
TIMESTAMP=$(date +%s)
OUTPUT_FILE="/tmp/grok_image_${TIMESTAMP}.jpg"

# Temp files, cleaned up on exit regardless of success/failure
PAYLOAD_FILE="/tmp/grok_payload_${TIMESTAMP}.json"
RESP_FILE="/tmp/grok_resp_${TIMESTAMP}.json"
PROVIDERS_FILE="/tmp/grok_providers_${TIMESTAMP}.txt"

cleanup() {
  rm -f "$PAYLOAD_FILE" "$RESP_FILE" "$PROVIDERS_FILE" 2>/dev/null
}
trap cleanup EXIT

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Config not found: $CONFIG_FILE" >&2
  exit 1
fi

# Pass all user input via environment variables, not string interpolation.
# The Python code below reads os.environ exclusively — no shell variables
# are expanded inside the heredoc (note the quoted 'PYEOF' delimiter).
export GROK_PROMPT="$PROMPT"
export GROK_SIZE="$SIZE"
export GROK_MODEL="$MODEL"
export GROK_CONFIG="$CONFIG_FILE"
export GROK_PAYLOAD_FILE="$PAYLOAD_FILE"
export GROK_PROVIDERS_FILE="$PROVIDERS_FILE"

python3 << 'PYEOF'
import json, os, sys

prompt = os.environ["GROK_PROMPT"]
size = os.environ["GROK_SIZE"]
model = os.environ["GROK_MODEL"]
config_path = os.environ["GROK_CONFIG"]
payload_path = os.environ["GROK_PAYLOAD_FILE"]
providers_path = os.environ["GROK_PROVIDERS_FILE"]

with open(config_path) as f:
    config = json.load(f)

# Safe JSON serialization — prompt content can never break out of the value
payload = {
    "model": model,
    "prompt": prompt,
    "n": 1,
    "size": size,
    "response_format": "b64_json"
}
with open(payload_path, "w") as f:
    json.dump(payload, f)

# Discover providers: exact model match first, then other grok-imagine variants
primary = []
fallback = []
seen = set()

for p in config.get("pool", []):
    pm = p.get("model", "")
    if pm == model:
        primary.append(p)
    elif "grok-imagine" in pm.lower() and pm != model and "video" not in pm.lower():
        key = (p["baseUrl"], p["apiKey"])
        if key not in seen:
            seen.add(key)
            fallback.append(p)

with open(providers_path, "w") as f:
    for p in primary:
        f.write(f"{p['name']}|{p['baseUrl']}|{p['apiKey']}\n")
    for p in fallback:
        f.write(f"{p['name']}(fallback)|{p['baseUrl']}|{p['apiKey']}\n")

total = len(primary) + len(fallback)
print(f"Found {len(primary)} primary + {len(fallback)} fallback providers", file=sys.stderr)
if total == 0:
    print("ERROR: No grok-imagine providers in pool", file=sys.stderr)
    sys.exit(1)
PYEOF

if [[ ! -s "$PROVIDERS_FILE" ]]; then
  echo "ERROR: No providers found for ${MODEL}" >&2
  exit 1
fi

# Rank providers by historical reliability (best first).
# First run has no data — providers tried in discovery order.
# Each subsequent run benefits from accumulated success/failure stats.
echo "Ranking by reliability..." >&2
python3 "$STATS_PY" rank "$PROVIDERS_FILE" 2>&1 >&2 || true

# Export file paths for the response parser Python block
export GROK_RESP_FILE="$RESP_FILE"
export GROK_OUTPUT_FILE="$OUTPUT_FILE"

SUCCESS=0
while IFS='|' read -r NAME BASE_URL API_KEY; do
  [[ -z "$NAME" ]] && continue
  echo "Trying: ${NAME} ..." >&2

  HTTP_CODE=$(curl -s -o "$RESP_FILE" -w "%{http_code}" --max-time 90 \
    "${BASE_URL}/images/generations" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "@${PAYLOAD_FILE}" 2>/dev/null || echo "000")

  # Auth errors are not retryable — skip this provider immediately
  if [[ "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" ]]; then
    echo "  Auth error (${HTTP_CODE}), skipping" >&2
    python3 "$STATS_PY" record "$NAME" fail 2>/dev/null || true
    continue
  fi

  if [[ "$HTTP_CODE" == "200" ]]; then
    # Parse response: handle both b64_json and url formats
    RESULT=$(python3 << 'PARSE_EOF'
import json, base64, os, sys

resp_file = os.environ.get("GROK_RESP_FILE", "")
output_file = os.environ.get("GROK_OUTPUT_FILE", "")

with open(resp_file) as f:
    data = json.load(f)

items = data.get("data", [])
if items and "b64_json" in items[0]:
    img = base64.b64decode(items[0]["b64_json"])
    with open(output_file, "wb") as out:
        out.write(img)
    print(f"OK:{len(img)}")
elif items and "url" in items[0]:
    print(f"URL:{items[0]['url']}")
else:
    err = data.get("error", {})
    msg = err.get("message", str(err)) if isinstance(err, dict) else str(err)
    print(f"FAIL:{msg}")
PARSE_EOF
    ) 2>/dev/null

    if [[ "$RESULT" == OK:* ]]; then
      echo "Success! Provider: ${NAME}, size: ${RESULT#OK:} bytes" >&2
      python3 "$STATS_PY" record "$NAME" success 2>/dev/null || true
      echo "$OUTPUT_FILE"
      SUCCESS=1
      break
    elif [[ "$RESULT" == URL:* ]]; then
      IMG_URL="${RESULT#URL:}"
      echo "  Got URL, downloading..." >&2
      DL_CODE=$(curl -s -o "$OUTPUT_FILE" -w "%{http_code}" --max-time 30 "$IMG_URL" 2>/dev/null || echo "000")
      if [[ "$DL_CODE" == "200" ]] && [[ -s "$OUTPUT_FILE" ]]; then
        FILE_SIZE=$(wc -c < "$OUTPUT_FILE" | tr -d ' ')
        echo "Success! Provider: ${NAME}, size: ${FILE_SIZE} bytes" >&2
        python3 "$STATS_PY" record "$NAME" success 2>/dev/null || true
        echo "$OUTPUT_FILE"
        SUCCESS=1
        break
      else
        echo "  Download failed (HTTP ${DL_CODE})" >&2
      fi
    else
      echo "  Parse error: ${RESULT#FAIL:}" >&2
      python3 "$STATS_PY" record "$NAME" fail 2>/dev/null || true
    fi
  elif [[ "$HTTP_CODE" == "429" ]]; then
    echo "  Rate limited, trying next..." >&2
    python3 "$STATS_PY" record "$NAME" fail 2>/dev/null || true
  elif [[ "$HTTP_CODE" == "000" ]]; then
    echo "  Timeout, trying next..." >&2
    python3 "$STATS_PY" record "$NAME" fail 2>/dev/null || true
  else
    ERR_MSG=$(head -c 200 "$RESP_FILE" 2>/dev/null || echo "no response")
    echo "  HTTP ${HTTP_CODE}: ${ERR_MSG}" >&2
    python3 "$STATS_PY" record "$NAME" fail 2>/dev/null || true
  fi
done < "$PROVIDERS_FILE"

if [[ "$SUCCESS" -ne 1 ]]; then
  echo "ERROR: All providers failed" >&2
  exit 1
fi
