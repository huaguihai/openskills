#!/usr/bin/env bash
# scan-installed.sh — Post-install scan of newly added packages, detect suspicious patterns
# Usage: scan-installed.sh <pypi|npm> <before-snapshot> [project-dir]
# before-snapshot: output file from pre-install pip list --format json or ls node_modules
set -euo pipefail

ECOSYSTEM="${1:-}"
BEFORE_SNAPSHOT="${2:-}"
PROJECT_DIR="${3:-.}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$ECOSYSTEM" ] || [ -z "$BEFORE_SNAPSHOT" ]; then
  echo '{"error":"Usage: scan-installed.sh <pypi|npm> <before-snapshot> [project-dir]"}'
  exit 1
fi

ALERTS="[]"
add_alert() {
  local pkg="$1" finding="$2" severity="$3"
  ALERTS=$(echo "$ALERTS" | python3 -c "
import json, sys
a = json.load(sys.stdin)
a.append({'package': '$pkg', 'finding': '''$finding''', 'severity': '$severity'})
print(json.dumps(a))
")
}

if [ "$ECOSYSTEM" = "pypi" ]; then
  # Get current package list
  AFTER=$(pip list --format json 2>/dev/null || echo "[]")

  # Find newly added packages
  NEW_PACKAGES=$(python3 -c "
import json
with open('${BEFORE_SNAPSHOT}') as f:
    before = {p['name'].lower(): p['version'] for p in json.load(f)}
after = {p['name'].lower(): p['version'] for p in json.loads('''${AFTER}''')}
for name, ver in after.items():
    if name not in before:
        print(f'{name}=={ver}')
" 2>/dev/null || echo "")

  if [ -z "$NEW_PACKAGES" ]; then
    echo '{"new_packages":0,"alerts":[]}'
    exit 0
  fi

  TOTAL_NEW=$(echo "$NEW_PACKAGES" | wc -l)

  # Scan each new package
  while IFS= read -r pkg_ver; do
    PKG=$(echo "$pkg_ver" | cut -d= -f1)
    VER=$(echo "$pkg_ver" | cut -d= -f3)

    # Find the package installation path
    PKG_DIR=$(python3 -c "
import importlib.util, os
spec = importlib.util.find_spec('${PKG}')
if spec and spec.origin:
    print(os.path.dirname(spec.origin))
else:
    # Try dist-info
    import site
    for sp in site.getsitepackages():
        for d in os.listdir(sp):
            if d.lower().startswith('${PKG}'.replace('-','_')) and d.endswith('.dist-info'):
                print(os.path.join(sp, d))
                break
" 2>/dev/null || echo "")

    SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])" 2>/dev/null || echo "")

    # Check .pth files
    if [ -n "$SITE_PACKAGES" ]; then
      PTH_FILES=$(find "$SITE_PACKAGES" -maxdepth 1 -name "*${PKG}*" -name "*.pth" 2>/dev/null || true)
      if [ -n "$PTH_FILES" ]; then
        # Check if .pth content is suspicious
        while IFS= read -r pth; do
          if grep -qEi '(base64|import |exec|eval|subprocess|socket|http|urllib|requests)' "$pth" 2>/dev/null; then
            add_alert "$PKG" ".pth file contains suspicious code: $pth" "critical"
          fi
        done <<< "$PTH_FILES"
      fi
    fi

    # Check package directory for suspicious patterns
    if [ -n "$PKG_DIR" ] && [ -d "$PKG_DIR" ]; then
      # Large base64 encoded content
      B64_HITS=$(grep -rlE '[A-Za-z0-9+/]{100,}={0,2}' "$PKG_DIR" --include="*.py" 2>/dev/null | head -3 || true)
      if [ -n "$B64_HITS" ]; then
        add_alert "$PKG" "Found large base64 encoded content" "high"
      fi

      # Network calls to non-well-known domains
      NET_HITS=$(grep -rnE '(requests\.post|urllib\.request\.urlopen|http\.client|socket\.connect|urlopen)\s*\(' "$PKG_DIR" --include="*.py" 2>/dev/null | head -5 || true)
      if [ -n "$NET_HITS" ]; then
        add_alert "$PKG" "Found outbound network calls" "high"
      fi

      # Sensitive directory access
      SENSITIVE_HITS=$(grep -rnE '(\.ssh|\.aws|\.kube|\.config|\.gnupg|\.env|credentials)' "$PKG_DIR" --include="*.py" 2>/dev/null | head -5 || true)
      if [ -n "$SENSITIVE_HITS" ]; then
        add_alert "$PKG" "Found sensitive directory access patterns" "critical"
      fi

      # Bulk os.environ enumeration
      ENV_HITS=$(grep -rnE 'os\.environ\b' "$PKG_DIR" --include="*.py" 2>/dev/null | wc -l || echo "0")
      if [ "$ENV_HITS" -gt 5 ]; then
        add_alert "$PKG" "Found excessive environment variable reading (${ENV_HITS} occurrences)" "high"
      fi

      # exec/eval + encoded strings
      EXEC_HITS=$(grep -rnE '(exec|eval|compile)\s*\(\s*(base64|codecs|decode)' "$PKG_DIR" --include="*.py" 2>/dev/null | head -3 || true)
      if [ -n "$EXEC_HITS" ]; then
        add_alert "$PKG" "Found exec/eval executing encoded content" "critical"
      fi
    fi

    # Call check-package.sh to check version publish time
    PKG_CHECK=$("$SCRIPT_DIR/check-package.sh" pypi "$PKG" "$VER" 2>/dev/null || echo '{"verdict":"unknown"}')
    PKG_VERDICT=$(echo "$PKG_CHECK" | python3 -c "import json,sys; print(json.load(sys.stdin).get('verdict','unknown'))" 2>/dev/null || echo "unknown")

    if [ "$PKG_VERDICT" = "red" ]; then
      add_alert "$PKG" "Metadata risk assessment: red" "high"
    elif [ "$PKG_VERDICT" = "yellow" ]; then
      add_alert "$PKG" "Metadata risk assessment: yellow" "medium"
    fi

  done <<< "$NEW_PACKAGES"

elif [ "$ECOSYSTEM" = "npm" ]; then
  # npm: compare node_modules
  NM_DIR="${PROJECT_DIR}/node_modules"
  if [ ! -d "$NM_DIR" ]; then
    echo '{"new_packages":0,"alerts":[],"note":"no node_modules found"}'
    exit 0
  fi

  # Current packages in node_modules
  AFTER=$(ls -1 "$NM_DIR" 2>/dev/null | grep -v '^\.' | sort)
  BEFORE=$(cat "$BEFORE_SNAPSHOT" 2>/dev/null | sort)

  NEW_PACKAGES=$(comm -23 <(echo "$AFTER") <(echo "$BEFORE"))

  if [ -z "$NEW_PACKAGES" ]; then
    echo '{"new_packages":0,"alerts":[]}'
    exit 0
  fi

  TOTAL_NEW=$(echo "$NEW_PACKAGES" | wc -l)

  while IFS= read -r PKG; do
    PKG_PATH="$NM_DIR/$PKG"

    # Check postinstall scripts
    if [ -f "$PKG_PATH/package.json" ]; then
      HAS_POSTINSTALL=$(python3 -c "
import json
with open('${PKG_PATH}/package.json') as f:
    d = json.load(f)
scripts = d.get('scripts', {})
for k in ('postinstall','preinstall','install'):
    if k in scripts:
        print(f'{k}: {scripts[k]}')
" 2>/dev/null || echo "")

      if [ -n "$HAS_POSTINSTALL" ]; then
        add_alert "$PKG" "Found install hook scripts: $HAS_POSTINSTALL" "high"
      fi
    fi

    # Check for suspicious JS patterns
    if [ -d "$PKG_PATH" ]; then
      # Outbound network/process calls
      NET_HITS=$(grep -rlE '(child_process|\.exec\(|\.execSync\(|net\.connect|http\.request)' "$PKG_PATH" --include="*.js" 2>/dev/null | head -3 || true)
      if [ -n "$NET_HITS" ]; then
        add_alert "$PKG" "Found suspicious network/process calls" "high"
      fi

      # Large base64 encoded content
      B64_HITS=$(grep -rlE '[A-Za-z0-9+/]{100,}={0,2}' "$PKG_PATH" --include="*.js" 2>/dev/null | head -3 || true)
      if [ -n "$B64_HITS" ]; then
        add_alert "$PKG" "Found large base64 encoded content" "high"
      fi

      # eval
      EVAL_HITS=$(grep -rnE 'eval\s*\(\s*(Buffer|atob|decode)' "$PKG_PATH" --include="*.js" 2>/dev/null | head -3 || true)
      if [ -n "$EVAL_HITS" ]; then
        add_alert "$PKG" "Found eval executing encoded content" "critical"
      fi
    fi
  done <<< "$NEW_PACKAGES"
fi

# ─── Output ───
echo "$ALERTS" | python3 -c "
import json, sys
alerts = json.load(sys.stdin)
total = ${TOTAL_NEW:-0}
critical = sum(1 for a in alerts if a['severity'] == 'critical')
high = sum(1 for a in alerts if a['severity'] == 'high')
verdict = 'red' if critical > 0 else ('yellow' if high > 0 else 'green')
print(json.dumps({'new_packages': total, 'alerts': alerts, 'critical': critical, 'high': high, 'verdict': verdict}, ensure_ascii=False, indent=2))
"
