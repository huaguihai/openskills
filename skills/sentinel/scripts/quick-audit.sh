#!/usr/bin/env bash
# quick-audit.sh — On-demand security audit (lite / full mode)
# Usage: quick-audit.sh [--full]
set -euo pipefail

FULL_MODE=false
[ "${1:-}" = "--full" ] && FULL_MODE=true

OPENCLAW_DIR="${OPENCLAW_DIR:-$HOME/.openclaw}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
REPORT_DIR="${OPENCLAW_DIR}/security-reports"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
REPORT_FILE="${REPORT_DIR}/sentinel_${TIMESTAMP}.md"

mkdir -p "${REPORT_DIR}"

cat > "${REPORT_FILE}" << 'HEADER'
# 🛡️ Sentinel Security Audit Report
HEADER
echo "**Time**: $(date '+%Y-%m-%d %H:%M:%S %Z')" >> "${REPORT_FILE}"
echo "**Mode**: $([ "$FULL_MODE" = true ] && echo 'Full' || echo 'Lite')" >> "${REPORT_FILE}"
echo "---" >> "${REPORT_FILE}"

WARNINGS=0

# ─── 1. Processes & Network ───
echo "" >> "${REPORT_FILE}"
echo "## 1. Processes & Network" >> "${REPORT_FILE}"
echo "### Unusual Listening Ports" >> "${REPORT_FILE}"
echo '```' >> "${REPORT_FILE}"
ss -tlnp 2>/dev/null | grep -v -E ':(3003|3006|8888|9222|18789|22)\s' >> "${REPORT_FILE}" 2>&1 || echo "No unusual ports" >> "${REPORT_FILE}"
echo '```' >> "${REPORT_FILE}"

echo "### Unusual Outbound Connections" >> "${REPORT_FILE}"
echo '```' >> "${REPORT_FILE}"
ss -tnp state established 2>/dev/null | grep -v -E '(localhost|127\.0\.0\.1|::1)' | head -20 >> "${REPORT_FILE}" 2>&1 || echo "No unusual outbound connections" >> "${REPORT_FILE}"
echo '```' >> "${REPORT_FILE}"

# ─── 2. Sensitive Directory File Changes ───
echo "" >> "${REPORT_FILE}"
echo "## 2. Sensitive Directory File Changes (24h)" >> "${REPORT_FILE}"
echo '```' >> "${REPORT_FILE}"
find "${OPENCLAW_DIR}" -type f -mmin -1440 \
  -not -path '*/delivery-queue/*' -not -path '*/logs/*' \
  -not -path '*/memory/*' -not -path '*/cron/*' \
  -not -path '*/devices/*' -not -path '*/telegram/*' \
  -not -path '*/security-reports/*' -not -path '*/sessions/*' \
  -not -name '*.bak*' 2>/dev/null | head -30 >> "${REPORT_FILE}" || true
echo '```' >> "${REPORT_FILE}"

# ─── 3. Credential DLP Scan ───
echo "" >> "${REPORT_FILE}"
echo "## 3. Credential DLP Scan" >> "${REPORT_FILE}"
DLP_PATTERN='(sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC )?PRIVATE KEY-----|xoxb-[a-zA-Z0-9-]+)'
DLP_HITS=$(grep -rn --include='*.md' --include='*.json' --include='*.js' --include='*.ts' \
  --include='*.env' --include='*.yaml' --include='*.yml' --include='*.sh' --include='*.py' \
  -E "${DLP_PATTERN}" "${WORKSPACE_DIR}" 2>/dev/null \
  | grep -v 'node_modules' | grep -v '.git' | grep -v 'package-lock' | wc -l || echo "0")

if [ "${DLP_HITS}" -gt 0 ]; then
  echo "⚠️ Found ${DLP_HITS} suspected plaintext credentials!" >> "${REPORT_FILE}"
  WARNINGS=$((WARNINGS + 1))
else
  echo "✅ No plaintext credential leaks found" >> "${REPORT_FILE}"
fi

# ─── 4. Skill Integrity ───
echo "" >> "${REPORT_FILE}"
echo "## 4. Skill Integrity" >> "${REPORT_FILE}"
SKILL_BASELINE="${OPENCLAW_DIR}/.skill-baseline.sha256"
if [ -d "${OPENCLAW_DIR}/skills" ]; then
  CURRENT_HASH=$(find "${OPENCLAW_DIR}/skills" -name 'SKILL.md' -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | awk '{print $1}')
  if [ -f "${SKILL_BASELINE}" ]; then
    SAVED_HASH=$(cat "${SKILL_BASELINE}")
    if [ "${CURRENT_HASH}" = "${SAVED_HASH}" ]; then
      echo "✅ Skill file integrity unchanged" >> "${REPORT_FILE}"
    else
      echo "⚠️ Skill files have been modified!" >> "${REPORT_FILE}"
      echo "${CURRENT_HASH}" > "${SKILL_BASELINE}"
      WARNINGS=$((WARNINGS + 1))
    fi
  else
    echo "ℹ️ First run, creating Skill baseline" >> "${REPORT_FILE}"
    echo "${CURRENT_HASH}" > "${SKILL_BASELINE}"
  fi
fi

# ─── 5. Disk Capacity ───
echo "" >> "${REPORT_FILE}"
echo "## 5. Disk Capacity" >> "${REPORT_FILE}"
echo '```' >> "${REPORT_FILE}"
df -h / >> "${REPORT_FILE}" 2>&1
echo '```' >> "${REPORT_FILE}"
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "${DISK_USAGE}" -gt 85 ]; then
  echo "⚠️ Disk usage ${DISK_USAGE}% exceeds 85%!" >> "${REPORT_FILE}"
  WARNINGS=$((WARNINGS + 1))
fi

# ─── Full mode additional checks ───
if [ "$FULL_MODE" = true ]; then

  # 6. SSH Security
  echo "" >> "${REPORT_FILE}"
  echo "## 6. SSH Security" >> "${REPORT_FILE}"
  echo "### Last 10 Login Records" >> "${REPORT_FILE}"
  echo '```' >> "${REPORT_FILE}"
  last -10 2>/dev/null >> "${REPORT_FILE}" || echo "Unable to retrieve" >> "${REPORT_FILE}"
  echo '```' >> "${REPORT_FILE}"

  echo "### Failed Logins (Last 24h)" >> "${REPORT_FILE}"
  echo '```' >> "${REPORT_FILE}"
  if command -v journalctl &>/dev/null; then
    FAILED=$(journalctl _COMM=sshd --since "24 hours ago" --no-pager 2>/dev/null | grep -c "Failed password" || echo "0")
  elif [ -f /var/log/auth.log ]; then
    FAILED=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo "0")
  else
    FAILED="N/A"
  fi
  echo "Failed attempts: ${FAILED}" >> "${REPORT_FILE}"
  if [ "${FAILED}" != "N/A" ] && [ "${FAILED}" -gt 50 ]; then
    echo "⚠️ Possible SSH brute-force attack!" >> "${REPORT_FILE}"
    WARNINGS=$((WARNINGS + 1))
  fi
  echo '```' >> "${REPORT_FILE}"

  # 7. System Cron Jobs
  echo "" >> "${REPORT_FILE}"
  echo "## 7. System Cron Jobs" >> "${REPORT_FILE}"
  echo '```' >> "${REPORT_FILE}"
  crontab -l 2>/dev/null >> "${REPORT_FILE}" || echo "No crontab" >> "${REPORT_FILE}"
  echo '```' >> "${REPORT_FILE}"

  # 8. Critical File Integrity
  echo "" >> "${REPORT_FILE}"
  echo "## 8. Critical File Integrity" >> "${REPORT_FILE}"
  BASELINE_FILE="${OPENCLAW_DIR}/.config-baseline.sha256"
  if [ -f "${BASELINE_FILE}" ]; then
    if sha256sum -c "${BASELINE_FILE}" >> "${REPORT_FILE}" 2>&1; then
      echo "✅ Config file integrity check passed" >> "${REPORT_FILE}"
    else
      echo "⚠️ Config files have been modified!" >> "${REPORT_FILE}"
      WARNINGS=$((WARNINGS + 1))
    fi
  fi

  # 9. Gateway Configuration
  echo "" >> "${REPORT_FILE}"
  echo "## 9. Gateway Configuration" >> "${REPORT_FILE}"
  GATEWAY_BIND=$(python3 -c "import json; print(json.load(open('${OPENCLAW_DIR}/openclaw.json'))['gateway']['bind'])" 2>/dev/null || echo "unknown")
  echo "- Bind: ${GATEWAY_BIND}" >> "${REPORT_FILE}"
  if [ "${GATEWAY_BIND}" != "loopback" ] && [ "${GATEWAY_BIND}" != "127.0.0.1" ]; then
    echo "⚠️ Gateway is not bound to loopback!" >> "${REPORT_FILE}"
    WARNINGS=$((WARNINGS + 1))
  fi
fi

# ─── Summary ───
echo "" >> "${REPORT_FILE}"
echo "---" >> "${REPORT_FILE}"
echo "## 📊 Audit Summary" >> "${REPORT_FILE}"
echo "- **Warnings**: ${WARNINGS}" >> "${REPORT_FILE}"
if [ "${WARNINGS}" -eq 0 ]; then
  echo "- **Conclusion**: ✅ All clear" >> "${REPORT_FILE}"
else
  echo "- **Conclusion**: ⚠️ Found ${WARNINGS} warning(s), please review" >> "${REPORT_FILE}"
fi

# Clean up old reports (keep 30 days)
find "${REPORT_DIR}" -name "sentinel_*.md" -mtime +30 -delete 2>/dev/null || true

echo "${REPORT_FILE}"
