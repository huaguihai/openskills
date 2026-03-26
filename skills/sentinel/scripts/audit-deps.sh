#!/usr/bin/env bash
# audit-deps.sh — Project dependency audit (npm audit + pip-audit + OSV)
# Usage: audit-deps.sh [project-dir]
set -euo pipefail

PROJECT_DIR="${1:-.}"
ALERTS="[]"

add_alert() {
  local pkg="$1" severity="$2" detail="$3"
  ALERTS=$(echo "$ALERTS" | python3 -c "
import json, sys
a = json.load(sys.stdin)
a.append({'package': '$pkg', 'severity': '$severity', 'detail': '''$detail'''})
print(json.dumps(a))
")
}

echo "📋 Scanning project: $PROJECT_DIR"

# ─── Node.js Project ───
if [ -f "$PROJECT_DIR/package.json" ]; then
  echo "Node.js project detected..."

  if [ -f "$PROJECT_DIR/package-lock.json" ] || [ -d "$PROJECT_DIR/node_modules" ]; then
    AUDIT_RESULT=$(cd "$PROJECT_DIR" && npm audit --json 2>/dev/null || echo '{"vulnerabilities":{}}')

    VULN_SUMMARY=$(echo "$AUDIT_RESULT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
vulns = data.get('vulnerabilities', {})
critical = sum(1 for v in vulns.values() if v.get('severity') == 'critical')
high = sum(1 for v in vulns.values() if v.get('severity') == 'high')
moderate = sum(1 for v in vulns.values() if v.get('severity') == 'moderate')
low = sum(1 for v in vulns.values() if v.get('severity') == 'low')
print(json.dumps({'critical': critical, 'high': high, 'moderate': moderate, 'low': low, 'total': len(vulns)}))
# Output each vulnerability
for name, info in vulns.items():
    sev = info.get('severity', 'unknown')
    via = info.get('via', [])
    title = ''
    for v in via:
        if isinstance(v, dict):
            title = v.get('title', '')
            break
    fix = info.get('fixAvailable', False)
    if isinstance(fix, dict):
        fix_ver = fix.get('version', '')
        fix_name = fix.get('name', '')
        print(f'VULN|{name}|{sev}|{title}|fix: {fix_name}@{fix_ver}')
    elif fix:
        print(f'VULN|{name}|{sev}|{title}|fix available')
    else:
        print(f'VULN|{name}|{sev}|{title}|no fix')
" 2>/dev/null || echo '{"total":0}')

    # Parse first line JSON
    SUMMARY_LINE=$(echo "$VULN_SUMMARY" | head -1)
    TOTAL=$(echo "$SUMMARY_LINE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total',0))" 2>/dev/null || echo "0")

    if [ "$TOTAL" -gt 0 ]; then
      echo "$VULN_SUMMARY" | tail -n +2 | while IFS='|' read -r _ pkg sev title fix; do
        add_alert "$pkg" "$sev" "${title:-unknown} ($fix)"
      done
    fi
  else
    echo "⚠️ No package-lock.json found, skipping npm audit"
  fi
fi

# ─── Python Project ───
REQ_FILE=""
if [ -f "$PROJECT_DIR/requirements.txt" ]; then
  REQ_FILE="$PROJECT_DIR/requirements.txt"
elif [ -f "$PROJECT_DIR/pyproject.toml" ]; then
  REQ_FILE="$PROJECT_DIR/pyproject.toml"
fi

if [ -n "$REQ_FILE" ]; then
  echo "Python project detected..."

  # Ensure pip-audit is available
  if ! command -v pip-audit &>/dev/null; then
    echo "Installing pip-audit..."
    pip install pip-audit -q 2>/dev/null || true
  fi

  if command -v pip-audit &>/dev/null; then
    if [ "$REQ_FILE" = "$PROJECT_DIR/requirements.txt" ]; then
      AUDIT_RESULT=$(pip-audit -r "$REQ_FILE" --format json 2>/dev/null || echo '{"dependencies":[]}')
    else
      AUDIT_RESULT=$(cd "$PROJECT_DIR" && pip-audit --format json 2>/dev/null || echo '{"dependencies":[]}')
    fi

    echo "$AUDIT_RESULT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
deps = data.get('dependencies', [])
for dep in deps:
    vulns = dep.get('vulns', [])
    name = dep.get('name', 'unknown')
    version = dep.get('version', '')
    for v in vulns:
        vid = v.get('id', '')
        fix = v.get('fix_versions', [])
        fix_str = ', '.join(fix) if fix else 'no fix'
        print(f'{name}|{vid}|{fix_str}')
" 2>/dev/null | while IFS='|' read -r pkg vid fix; do
      add_alert "$pkg" "vulnerability" "$vid (fix: $fix)"
    done
  else
    echo "⚠️ pip-audit installation failed, falling back to OSV API"
  fi
fi

# ─── OSV Batch Query (supplementary) ───
if [ -f "$PROJECT_DIR/requirements.txt" ]; then
  echo "Querying OSV vulnerability database..."
  python3 -c "
import json, urllib.request
with open('${PROJECT_DIR}/requirements.txt') as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#') or line.startswith('-'):
            continue
        parts = line.split('==')
        if len(parts) == 2:
            pkg, ver = parts
            query = {'package': {'name': pkg.strip(), 'ecosystem': 'PyPI'}, 'version': ver.strip()}
            try:
                req = urllib.request.Request('https://api.osv.dev/v1/query',
                    data=json.dumps(query).encode(),
                    headers={'Content-Type': 'application/json'})
                resp = urllib.request.urlopen(req, timeout=5)
                data = json.loads(resp.read())
                for v in data.get('vulns', []):
                    print(f'{pkg.strip()}|{v[\"id\"]}|OSV')
            except:
                pass
" 2>/dev/null | while IFS='|' read -r pkg vid source; do
    add_alert "$pkg" "osv" "$vid"
  done
fi

# ─── Output ───
echo "$ALERTS" | python3 -c "
import json, sys
alerts = json.load(sys.stdin)
critical = sum(1 for a in alerts if a['severity'] in ('critical',))
high = sum(1 for a in alerts if a['severity'] in ('high',))
total = len(alerts)
if critical > 0:
    verdict = 'red'
elif high > 0:
    verdict = 'yellow'
elif total > 0:
    verdict = 'yellow'
else:
    verdict = 'green'
print(json.dumps({'project': '${PROJECT_DIR}', 'total_issues': total, 'alerts': alerts, 'verdict': verdict}, ensure_ascii=False, indent=2))
"
