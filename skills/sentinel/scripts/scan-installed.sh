#!/usr/bin/env bash
# scan-installed.sh — 安装后扫描新增包，检测可疑模式
# 用法: scan-installed.sh <pypi|npm> <before-snapshot> [project-dir]
# before-snapshot: 安装前 pip list --format json 或 ls node_modules 的输出文件
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
  # 获取当前包列表
  AFTER=$(pip list --format json 2>/dev/null || echo "[]")

  # 找出新增的包
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

  # 扫描每个新增包
  while IFS= read -r pkg_ver; do
    PKG=$(echo "$pkg_ver" | cut -d= -f1)
    VER=$(echo "$pkg_ver" | cut -d= -f3)

    # 找到包的安装路径
    PKG_DIR=$(python3 -c "
import importlib.util, os
spec = importlib.util.find_spec('${PKG}')
if spec and spec.origin:
    print(os.path.dirname(spec.origin))
else:
    # 尝试 dist-info
    import site
    for sp in site.getsitepackages():
        for d in os.listdir(sp):
            if d.lower().startswith('${PKG}'.replace('-','_')) and d.endswith('.dist-info'):
                print(os.path.join(sp, d))
                break
" 2>/dev/null || echo "")

    SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])" 2>/dev/null || echo "")

    # 检查 .pth 文件
    if [ -n "$SITE_PACKAGES" ]; then
      PTH_FILES=$(find "$SITE_PACKAGES" -maxdepth 1 -name "*${PKG}*" -name "*.pth" 2>/dev/null || true)
      if [ -n "$PTH_FILES" ]; then
        # 检查 .pth 内容是否可疑
        while IFS= read -r pth; do
          if grep -qEi '(base64|import |exec|eval|subprocess|socket|http|urllib|requests)' "$pth" 2>/dev/null; then
            add_alert "$PKG" ".pth 文件含可疑代码: $pth" "critical"
          fi
        done <<< "$PTH_FILES"
      fi
    fi

    # 检查包目录中的可疑模式
    if [ -n "$PKG_DIR" ] && [ -d "$PKG_DIR" ]; then
      # base64 大段编码
      B64_HITS=$(grep -rlE '[A-Za-z0-9+/]{100,}={0,2}' "$PKG_DIR" --include="*.py" 2>/dev/null | head -3 || true)
      if [ -n "$B64_HITS" ]; then
        add_alert "$PKG" "发现大段 base64 编码内容" "high"
      fi

      # 网络调用到非知名域名
      NET_HITS=$(grep -rnE '(requests\.post|urllib\.request\.urlopen|http\.client|socket\.connect|urlopen)\s*\(' "$PKG_DIR" --include="*.py" 2>/dev/null | head -5 || true)
      if [ -n "$NET_HITS" ]; then
        add_alert "$PKG" "发现网络外传调用" "high"
      fi

      # 读取敏感目录
      SENSITIVE_HITS=$(grep -rnE '(\.ssh|\.aws|\.kube|\.config|\.gnupg|\.env|credentials)' "$PKG_DIR" --include="*.py" 2>/dev/null | head -5 || true)
      if [ -n "$SENSITIVE_HITS" ]; then
        add_alert "$PKG" "发现敏感目录访问模式" "critical"
      fi

      # os.environ 大规模遍历
      ENV_HITS=$(grep -rnE 'os\.environ\b' "$PKG_DIR" --include="*.py" 2>/dev/null | wc -l || echo "0")
      if [ "$ENV_HITS" -gt 5 ]; then
        add_alert "$PKG" "发现大量环境变量读取 (${ENV_HITS} 处)" "high"
      fi

      # exec/eval + 编码字符串
      EXEC_HITS=$(grep -rnE '(exec|eval|compile)\s*\(\s*(base64|codecs|decode)' "$PKG_DIR" --include="*.py" 2>/dev/null | head -3 || true)
      if [ -n "$EXEC_HITS" ]; then
        add_alert "$PKG" "发现 exec/eval 执行编码内容" "critical"
      fi
    fi

    # 调用 check-package.sh 检查版本发布时间
    PKG_CHECK=$("$SCRIPT_DIR/check-package.sh" pypi "$PKG" "$VER" 2>/dev/null || echo '{"verdict":"unknown"}')
    PKG_VERDICT=$(echo "$PKG_CHECK" | python3 -c "import json,sys; print(json.load(sys.stdin).get('verdict','unknown'))" 2>/dev/null || echo "unknown")

    if [ "$PKG_VERDICT" = "red" ]; then
      add_alert "$PKG" "元数据风险评估: 红灯" "high"
    elif [ "$PKG_VERDICT" = "yellow" ]; then
      add_alert "$PKG" "元数据风险评估: 黄灯" "medium"
    fi

  done <<< "$NEW_PACKAGES"

elif [ "$ECOSYSTEM" = "npm" ]; then
  # npm: 对比 node_modules
  NM_DIR="${PROJECT_DIR}/node_modules"
  if [ ! -d "$NM_DIR" ]; then
    echo '{"new_packages":0,"alerts":[],"note":"no node_modules found"}'
    exit 0
  fi

  # 当前 node_modules 中的包
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

    # 检查 postinstall 脚本
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
        add_alert "$PKG" "发现安装钩子脚本: $HAS_POSTINSTALL" "high"
      fi
    fi

    # 检查可疑 JS 模式
    if [ -d "$PKG_PATH" ]; then
      # 网络外传
      NET_HITS=$(grep -rlE '(child_process|\.exec\(|\.execSync\(|net\.connect|http\.request)' "$PKG_PATH" --include="*.js" 2>/dev/null | head -3 || true)
      if [ -n "$NET_HITS" ]; then
        add_alert "$PKG" "发现可疑网络/进程调用" "high"
      fi

      # base64 大段编码
      B64_HITS=$(grep -rlE '[A-Za-z0-9+/]{100,}={0,2}' "$PKG_PATH" --include="*.js" 2>/dev/null | head -3 || true)
      if [ -n "$B64_HITS" ]; then
        add_alert "$PKG" "发现大段 base64 编码内容" "high"
      fi

      # eval
      EVAL_HITS=$(grep -rnE 'eval\s*\(\s*(Buffer|atob|decode)' "$PKG_PATH" --include="*.js" 2>/dev/null | head -3 || true)
      if [ -n "$EVAL_HITS" ]; then
        add_alert "$PKG" "发现 eval 执行编码内容" "critical"
      fi
    fi
  done <<< "$NEW_PACKAGES"
fi

# ─── 输出 ───
echo "$ALERTS" | python3 -c "
import json, sys
alerts = json.load(sys.stdin)
total = ${TOTAL_NEW:-0}
critical = sum(1 for a in alerts if a['severity'] == 'critical')
high = sum(1 for a in alerts if a['severity'] == 'high')
verdict = 'red' if critical > 0 else ('yellow' if high > 0 else 'green')
print(json.dumps({'new_packages': total, 'alerts': alerts, 'critical': critical, 'high': high, 'verdict': verdict}, ensure_ascii=False, indent=2))
"
