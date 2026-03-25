#!/usr/bin/env bash
# check-package.sh — 查询 PyPI/npm registry + OSV，输出风险评分
# 用法: check-package.sh <pypi|npm> <package> [version]
set -euo pipefail

ECOSYSTEM="${1:-}"
PACKAGE="${2:-}"
VERSION="${3:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MALICIOUS_LIST="$SCRIPT_DIR/../references/known-malicious.md"

if [ -z "$ECOSYSTEM" ] || [ -z "$PACKAGE" ]; then
  echo '{"error":"Usage: check-package.sh <pypi|npm> <package> [version]"}'
  exit 1
fi

# ─── 输出 JSON 格式的风险报告 ───
# signals: array of {dimension, value, level}
# level: green / yellow / red
# verdict: green / yellow / red

SIGNALS="[]"
add_signal() {
  local dim="$1" val="$2" level="$3"
  SIGNALS=$(echo "$SIGNALS" | python3 -c "
import json, sys
s = json.load(sys.stdin)
s.append({'dimension': '$dim', 'value': '''$val''', 'level': '$level'})
print(json.dumps(s))
")
}

# ─── 1. 检查 known-malicious 名单 ───
# 只匹配恶意包条目格式: "- `pkg` —" 或 "- `pkg` v"
if [ -f "$MALICIOUS_LIST" ] && grep -qE "^\- \`${PACKAGE}\` (—|v)" "$MALICIOUS_LIST" 2>/dev/null; then
  add_signal "known-malicious" "在已知恶意包名单中" "red"
fi

# ─── 2. Typosquatting 检测（与热门包的编辑距离） ───
TYPO_CHECK=$(python3 -c "
import difflib
popular = ['requests','flask','django','numpy','pandas','boto3','openai','langchain',
           'fastapi','httpx','aiohttp','celery','redis','sqlalchemy','pydantic',
           'express','react','vue','axios','lodash','moment','webpack','typescript',
           'next','tailwindcss','prisma','zod','trpc','litellm','anthropic']
pkg = '${PACKAGE}'.lower()
for p in popular:
    ratio = difflib.SequenceMatcher(None, pkg, p).ratio()
    if 0.75 < ratio < 1.0 and pkg != p:
        print(f'与 {p} 高度相似 (相似度 {ratio:.0%})')
        break
else:
    print('OK')
" 2>/dev/null || echo "OK")

if [ "$TYPO_CHECK" != "OK" ]; then
  add_signal "typosquatting" "$TYPO_CHECK" "red"
fi

# ─── 3. 查询 Registry ───
if [ "$ECOSYSTEM" = "pypi" ]; then
  # PyPI JSON API
  if [ -n "$VERSION" ]; then
    REGISTRY_URL="https://pypi.org/pypi/${PACKAGE}/${VERSION}/json"
  else
    REGISTRY_URL="https://pypi.org/pypi/${PACKAGE}/json"
  fi

  REGISTRY_DATA=$(curl -sf "$REGISTRY_URL" 2>/dev/null || echo "")

  if [ -z "$REGISTRY_DATA" ]; then
    add_signal "registry" "包不存在或无法查询" "red"
  else
    # 提取信息
    PKG_INFO=$(echo "$REGISTRY_DATA" | python3 -c "
import json, sys
from datetime import datetime, timezone, timedelta
data = json.load(sys.stdin)
info = data.get('info', {})
name = info.get('name', 'unknown')
version = info.get('version', 'unknown')
# 获取最新版本的发布时间
releases = data.get('releases', {})
upload_time = ''
maintainer_changed = False
if version in releases and releases[version]:
    upload_time = releases[version][0].get('upload_time_iso_8601', '')
# 获取所有版本，分析发布节奏
versions = sorted(releases.keys())
# 计算版本发布时间差
print(json.dumps({
    'name': name,
    'version': version,
    'upload_time': upload_time,
    'total_versions': len(versions),
    'author': info.get('author', '') or info.get('maintainer', ''),
    'author_email': info.get('author_email', '') or info.get('maintainer_email', ''),
}))
" 2>/dev/null || echo '{}')

    # 解析发布时间
    UPLOAD_TIME=$(echo "$PKG_INFO" | python3 -c "
import json, sys
from datetime import datetime, timezone, timedelta
info = json.load(sys.stdin)
ut = info.get('upload_time', '')
if ut:
    pub = datetime.fromisoformat(ut.replace('Z', '+00:00'))
    now = datetime.now(timezone.utc)
    hours = (now - pub).total_seconds() / 3600
    print(f'{hours:.1f}')
else:
    print('-1')
" 2>/dev/null || echo "-1")

    if [ "$UPLOAD_TIME" != "-1" ]; then
      HOURS=$(echo "$UPLOAD_TIME" | cut -d. -f1)
      if [ "$HOURS" -lt 48 ]; then
        add_signal "publish-age" "发布仅 ${HOURS} 小时前" "red"
      elif [ "$HOURS" -lt 168 ]; then
        add_signal "publish-age" "发布 ${HOURS} 小时前（< 7 天）" "yellow"
      else
        add_signal "publish-age" "发布超过 7 天" "green"
      fi
    fi

    TOTAL_VERSIONS=$(echo "$PKG_INFO" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total_versions',0))" 2>/dev/null || echo "0")
    if [ "$TOTAL_VERSIONS" -lt 3 ]; then
      add_signal "maturity" "仅 ${TOTAL_VERSIONS} 个版本" "yellow"
    else
      add_signal "maturity" "${TOTAL_VERSIONS} 个版本" "green"
    fi
  fi

elif [ "$ECOSYSTEM" = "npm" ]; then
  # npm Registry API
  REGISTRY_DATA=$(curl -sf "https://registry.npmjs.org/${PACKAGE}" 2>/dev/null || echo "")

  if [ -z "$REGISTRY_DATA" ]; then
    add_signal "registry" "包不存在或无法查询" "red"
  else
    PKG_INFO=$(echo "$REGISTRY_DATA" | python3 -c "
import json, sys
from datetime import datetime, timezone
data = json.load(sys.stdin)
time_data = data.get('time', {})
dist_tags = data.get('dist-tags', {})
latest = dist_tags.get('latest', '')
latest_time = time_data.get(latest, '')
versions = [v for v in time_data.keys() if v not in ('created','modified')]
# 获取维护者
maintainers = [m.get('name','') for m in data.get('maintainers', [])]
print(json.dumps({
    'name': data.get('name', 'unknown'),
    'version': latest,
    'upload_time': latest_time,
    'total_versions': len(versions),
    'maintainers': maintainers,
}))
" 2>/dev/null || echo '{}')

    UPLOAD_TIME=$(echo "$PKG_INFO" | python3 -c "
import json, sys
from datetime import datetime, timezone
info = json.load(sys.stdin)
ut = info.get('upload_time', '')
if ut:
    pub = datetime.fromisoformat(ut.replace('Z', '+00:00'))
    now = datetime.now(timezone.utc)
    hours = (now - pub).total_seconds() / 3600
    print(f'{hours:.1f}')
else:
    print('-1')
" 2>/dev/null || echo "-1")

    if [ "$UPLOAD_TIME" != "-1" ]; then
      HOURS=$(echo "$UPLOAD_TIME" | cut -d. -f1)
      if [ "$HOURS" -lt 48 ]; then
        add_signal "publish-age" "发布仅 ${HOURS} 小时前" "red"
      elif [ "$HOURS" -lt 168 ]; then
        add_signal "publish-age" "发布 ${HOURS} 小时前（< 7 天）" "yellow"
      else
        add_signal "publish-age" "发布超过 7 天" "green"
      fi
    fi

    TOTAL_VERSIONS=$(echo "$PKG_INFO" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total_versions',0))" 2>/dev/null || echo "0")
    if [ "$TOTAL_VERSIONS" -lt 3 ]; then
      add_signal "maturity" "仅 ${TOTAL_VERSIONS} 个版本" "yellow"
    else
      add_signal "maturity" "${TOTAL_VERSIONS} 个版本" "green"
    fi
  fi
fi

# ─── 4. 查询 OSV 漏洞数据库 ───
OSV_QUERY="{\"package\":{\"name\":\"${PACKAGE}\",\"ecosystem\":\"$(echo "$ECOSYSTEM" | sed 's/pypi/PyPI/;s/npm/npm/')\"}}"
if [ -n "$VERSION" ]; then
  OSV_QUERY="{\"package\":{\"name\":\"${PACKAGE}\",\"ecosystem\":\"$(echo "$ECOSYSTEM" | sed 's/pypi/PyPI/;s/npm/npm/')\"},\"version\":\"${VERSION}\"}"
fi

OSV_RESULT=$(curl -sf -X POST "https://api.osv.dev/v1/query" \
  -H "Content-Type: application/json" \
  -d "$OSV_QUERY" 2>/dev/null || echo '{}')

VULN_COUNT=$(echo "$OSV_RESULT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
vulns = data.get('vulns', [])
print(len(vulns))
" 2>/dev/null || echo "0")

if [ "$VULN_COUNT" -gt 0 ]; then
  VULN_SEVERITY=$(echo "$OSV_RESULT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
vulns = data.get('vulns', [])
ids = [v.get('id','?') for v in vulns[:3]]
print(', '.join(ids))
" 2>/dev/null || echo "unknown")

  if [ "$VULN_COUNT" -gt 2 ]; then
    add_signal "osv-vulns" "${VULN_COUNT} 个已知漏洞 (${VULN_SEVERITY})" "red"
  else
    add_signal "osv-vulns" "${VULN_COUNT} 个已知漏洞 (${VULN_SEVERITY})" "yellow"
  fi
else
  add_signal "osv-vulns" "无已知漏洞" "green"
fi

# ─── 5. 综合判定 ───
VERDICT=$(echo "$SIGNALS" | python3 -c "
import json, sys
signals = json.load(sys.stdin)
reds = sum(1 for s in signals if s['level'] == 'red')
yellows = sum(1 for s in signals if s['level'] == 'yellow')
if reds > 0:
    print('red')
elif yellows >= 2:
    print('yellow')
elif yellows == 1:
    print('yellow')
else:
    print('green')
")

# ─── 输出 ───
echo "$SIGNALS" | python3 -c "
import json, sys
signals = json.load(sys.stdin)
verdict = '${VERDICT}'
print(json.dumps({'package': '${PACKAGE}', 'ecosystem': '${ECOSYSTEM}', 'version': '${VERSION}', 'signals': signals, 'verdict': verdict}, ensure_ascii=False, indent=2))
"
