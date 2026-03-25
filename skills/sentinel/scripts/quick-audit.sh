#!/usr/bin/env bash
# quick-audit.sh — 按需安全巡检（精简版 / 完整版）
# 用法: quick-audit.sh [--full]
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
# 🛡️ Sentinel 安全巡检报告
HEADER
echo "**时间**: $(date '+%Y-%m-%d %H:%M:%S %Z')" >> "${REPORT_FILE}"
echo "**模式**: $([ "$FULL_MODE" = true ] && echo '完整版' || echo '精简版')" >> "${REPORT_FILE}"
echo "---" >> "${REPORT_FILE}"

WARNINGS=0

# ─── 1. 进程与网络 ───
echo "" >> "${REPORT_FILE}"
echo "## 1. 进程与网络" >> "${REPORT_FILE}"
echo "### 异常监听端口" >> "${REPORT_FILE}"
echo '```' >> "${REPORT_FILE}"
ss -tlnp 2>/dev/null | grep -v -E ':(3003|3006|8888|9222|18789|22)\s' >> "${REPORT_FILE}" 2>&1 || echo "无异常端口" >> "${REPORT_FILE}"
echo '```' >> "${REPORT_FILE}"

echo "### 异常出站连接" >> "${REPORT_FILE}"
echo '```' >> "${REPORT_FILE}"
ss -tnp state established 2>/dev/null | grep -v -E '(localhost|127\.0\.0\.1|::1)' | head -20 >> "${REPORT_FILE}" 2>&1 || echo "无异常出站" >> "${REPORT_FILE}"
echo '```' >> "${REPORT_FILE}"

# ─── 2. 敏感目录文件变更 ───
echo "" >> "${REPORT_FILE}"
echo "## 2. 敏感目录 24h 文件变更" >> "${REPORT_FILE}"
echo '```' >> "${REPORT_FILE}"
find "${OPENCLAW_DIR}" -type f -mmin -1440 \
  -not -path '*/delivery-queue/*' -not -path '*/logs/*' \
  -not -path '*/memory/*' -not -path '*/cron/*' \
  -not -path '*/devices/*' -not -path '*/telegram/*' \
  -not -path '*/security-reports/*' -not -path '*/sessions/*' \
  -not -name '*.bak*' 2>/dev/null | head -30 >> "${REPORT_FILE}" || true
echo '```' >> "${REPORT_FILE}"

# ─── 3. 凭证 DLP 扫描 ───
echo "" >> "${REPORT_FILE}"
echo "## 3. 凭证 DLP 扫描" >> "${REPORT_FILE}"
DLP_PATTERN='(sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC )?PRIVATE KEY-----|xoxb-[a-zA-Z0-9-]+)'
DLP_HITS=$(grep -rn --include='*.md' --include='*.json' --include='*.js' --include='*.ts' \
  --include='*.env' --include='*.yaml' --include='*.yml' --include='*.sh' --include='*.py' \
  -E "${DLP_PATTERN}" "${WORKSPACE_DIR}" 2>/dev/null \
  | grep -v 'node_modules' | grep -v '.git' | grep -v 'package-lock' | wc -l || echo "0")

if [ "${DLP_HITS}" -gt 0 ]; then
  echo "⚠️ 发现 ${DLP_HITS} 处疑似明文凭证！" >> "${REPORT_FILE}"
  WARNINGS=$((WARNINGS + 1))
else
  echo "✅ 未发现明文凭证泄露" >> "${REPORT_FILE}"
fi

# ─── 4. Skill 完整性 ───
echo "" >> "${REPORT_FILE}"
echo "## 4. Skill 完整性" >> "${REPORT_FILE}"
SKILL_BASELINE="${OPENCLAW_DIR}/.skill-baseline.sha256"
if [ -d "${OPENCLAW_DIR}/skills" ]; then
  CURRENT_HASH=$(find "${OPENCLAW_DIR}/skills" -name 'SKILL.md' -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | awk '{print $1}')
  if [ -f "${SKILL_BASELINE}" ]; then
    SAVED_HASH=$(cat "${SKILL_BASELINE}")
    if [ "${CURRENT_HASH}" = "${SAVED_HASH}" ]; then
      echo "✅ Skill 文件完整性未变" >> "${REPORT_FILE}"
    else
      echo "⚠️ Skill 文件有变更！" >> "${REPORT_FILE}"
      echo "${CURRENT_HASH}" > "${SKILL_BASELINE}"
      WARNINGS=$((WARNINGS + 1))
    fi
  else
    echo "ℹ️ 首次运行，创建 Skill 基线" >> "${REPORT_FILE}"
    echo "${CURRENT_HASH}" > "${SKILL_BASELINE}"
  fi
fi

# ─── 5. 磁盘容量 ───
echo "" >> "${REPORT_FILE}"
echo "## 5. 磁盘容量" >> "${REPORT_FILE}"
echo '```' >> "${REPORT_FILE}"
df -h / >> "${REPORT_FILE}" 2>&1
echo '```' >> "${REPORT_FILE}"
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "${DISK_USAGE}" -gt 85 ]; then
  echo "⚠️ 磁盘使用率 ${DISK_USAGE}% 超过 85%！" >> "${REPORT_FILE}"
  WARNINGS=$((WARNINGS + 1))
fi

# ─── 完整版额外巡检 ───
if [ "$FULL_MODE" = true ]; then

  # 6. SSH 安全
  echo "" >> "${REPORT_FILE}"
  echo "## 6. SSH 安全" >> "${REPORT_FILE}"
  echo "### 最近 10 条登录记录" >> "${REPORT_FILE}"
  echo '```' >> "${REPORT_FILE}"
  last -10 2>/dev/null >> "${REPORT_FILE}" || echo "无法获取" >> "${REPORT_FILE}"
  echo '```' >> "${REPORT_FILE}"

  echo "### 失败登录（最近 24h）" >> "${REPORT_FILE}"
  echo '```' >> "${REPORT_FILE}"
  if command -v journalctl &>/dev/null; then
    FAILED=$(journalctl _COMM=sshd --since "24 hours ago" --no-pager 2>/dev/null | grep -c "Failed password" || echo "0")
  elif [ -f /var/log/auth.log ]; then
    FAILED=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo "0")
  else
    FAILED="N/A"
  fi
  echo "失败次数: ${FAILED}" >> "${REPORT_FILE}"
  if [ "${FAILED}" != "N/A" ] && [ "${FAILED}" -gt 50 ]; then
    echo "⚠️ 疑似 SSH 爆破攻击！" >> "${REPORT_FILE}"
    WARNINGS=$((WARNINGS + 1))
  fi
  echo '```' >> "${REPORT_FILE}"

  # 7. 系统级定时任务
  echo "" >> "${REPORT_FILE}"
  echo "## 7. 系统级定时任务" >> "${REPORT_FILE}"
  echo '```' >> "${REPORT_FILE}"
  crontab -l 2>/dev/null >> "${REPORT_FILE}" || echo "无 crontab" >> "${REPORT_FILE}"
  echo '```' >> "${REPORT_FILE}"

  # 8. 关键文件完整性
  echo "" >> "${REPORT_FILE}"
  echo "## 8. 关键文件完整性" >> "${REPORT_FILE}"
  BASELINE_FILE="${OPENCLAW_DIR}/.config-baseline.sha256"
  if [ -f "${BASELINE_FILE}" ]; then
    if sha256sum -c "${BASELINE_FILE}" >> "${REPORT_FILE}" 2>&1; then
      echo "✅ 配置文件完整性校验通过" >> "${REPORT_FILE}"
    else
      echo "⚠️ 配置文件已被修改！" >> "${REPORT_FILE}"
      WARNINGS=$((WARNINGS + 1))
    fi
  fi

  # 9. Gateway 配置
  echo "" >> "${REPORT_FILE}"
  echo "## 9. Gateway 配置" >> "${REPORT_FILE}"
  GATEWAY_BIND=$(python3 -c "import json; print(json.load(open('${OPENCLAW_DIR}/openclaw.json'))['gateway']['bind'])" 2>/dev/null || echo "unknown")
  echo "- 绑定: ${GATEWAY_BIND}" >> "${REPORT_FILE}"
  if [ "${GATEWAY_BIND}" != "loopback" ] && [ "${GATEWAY_BIND}" != "127.0.0.1" ]; then
    echo "⚠️ Gateway 未绑定到 loopback！" >> "${REPORT_FILE}"
    WARNINGS=$((WARNINGS + 1))
  fi
fi

# ─── 总结 ───
echo "" >> "${REPORT_FILE}"
echo "---" >> "${REPORT_FILE}"
echo "## 📊 巡检总结" >> "${REPORT_FILE}"
echo "- **告警数**: ${WARNINGS}" >> "${REPORT_FILE}"
if [ "${WARNINGS}" -eq 0 ]; then
  echo "- **结论**: ✅ 一切正常" >> "${REPORT_FILE}"
else
  echo "- **结论**: ⚠️ 发现 ${WARNINGS} 个告警，请检查" >> "${REPORT_FILE}"
fi

# 清理旧报告（保留 30 天）
find "${REPORT_DIR}" -name "sentinel_*.md" -mtime +30 -delete 2>/dev/null || true

echo "${REPORT_FILE}"
