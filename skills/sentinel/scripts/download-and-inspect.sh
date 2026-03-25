#!/usr/bin/env bash
# download-and-inspect.sh — 下载但不安装，解包全面检查
# 用法: download-and-inspect.sh <pypi|npm> <package> [version]
set -euo pipefail

ECOSYSTEM="${1:-}"
PACKAGE="${2:-}"
VERSION="${3:-}"
INSPECT_DIR="/tmp/sentinel-inspect"

if [ -z "$ECOSYSTEM" ] || [ -z "$PACKAGE" ]; then
  echo '{"error":"Usage: download-and-inspect.sh <pypi|npm> <package> [version]"}'
  exit 1
fi

# 清理
rm -rf "$INSPECT_DIR"
mkdir -p "$INSPECT_DIR"

FINDINGS="[]"
add_finding() {
  local category="$1" detail="$2" severity="$3" file="${4:-}"
  FINDINGS=$(echo "$FINDINGS" | python3 -c "
import json, sys
f = json.load(sys.stdin)
f.append({'category': '$category', 'detail': '''$detail''', 'severity': '$severity', 'file': '$file'})
print(json.dumps(f))
")
}

if [ "$ECOSYSTEM" = "pypi" ]; then
  # 下载但不安装
  PIP_TARGET="${PACKAGE}"
  [ -n "$VERSION" ] && PIP_TARGET="${PACKAGE}==${VERSION}"

  pip download --no-deps -d "$INSPECT_DIR" "$PIP_TARGET" 2>/dev/null || {
    echo '{"error":"下载失败","package":"'"$PACKAGE"'"}'
    rm -rf "$INSPECT_DIR"
    exit 1
  }

  # 解压
  EXTRACT_DIR="$INSPECT_DIR/extracted"
  mkdir -p "$EXTRACT_DIR"

  for f in "$INSPECT_DIR"/*.whl; do
    [ -f "$f" ] && unzip -q "$f" -d "$EXTRACT_DIR" 2>/dev/null || true
  done
  for f in "$INSPECT_DIR"/*.tar.gz; do
    [ -f "$f" ] && tar xzf "$f" -C "$EXTRACT_DIR" 2>/dev/null || true
  done
  for f in "$INSPECT_DIR"/*.zip; do
    [ -f "$f" ] && unzip -q "$f" -d "$EXTRACT_DIR" 2>/dev/null || true
  done

  # ─── 扫描 ───

  # 1. .pth 文件
  PTH_FILES=$(find "$EXTRACT_DIR" -name "*.pth" 2>/dev/null || true)
  if [ -n "$PTH_FILES" ]; then
    while IFS= read -r pth; do
      CONTENT=$(cat "$pth" 2>/dev/null || true)
      if echo "$CONTENT" | grep -qEi '(import |base64|exec|eval|subprocess|socket|http|urllib)'; then
        add_finding "pth-malicious" ".pth 文件含执行代码" "critical" "$pth"
      else
        add_finding "pth-present" ".pth 文件存在（内容看似无害）" "medium" "$pth"
      fi
    done <<< "$PTH_FILES"
  fi

  # 2. setup.py cmdclass 覆写
  SETUP_PY=$(find "$EXTRACT_DIR" -name "setup.py" -maxdepth 3 2>/dev/null | head -1 || true)
  if [ -n "$SETUP_PY" ] && [ -f "$SETUP_PY" ]; then
    if grep -qE 'cmdclass\s*=' "$SETUP_PY" 2>/dev/null; then
      # 检查是否覆写了 install/develop
      if grep -qE "(install|develop|egg_info)" "$SETUP_PY" 2>/dev/null; then
        add_finding "setup-cmdclass" "setup.py 覆写了安装命令" "high" "$SETUP_PY"
      fi
    fi
    # 检查 setup.py 中的网络调用
    if grep -qEi '(requests\.|urllib|http\.client|socket\.|subprocess)' "$SETUP_PY" 2>/dev/null; then
      add_finding "setup-network" "setup.py 中有网络/进程调用" "critical" "$SETUP_PY"
    fi
  fi

  # 3. __init__.py 顶层网络调用
  INIT_FILES=$(find "$EXTRACT_DIR" -name "__init__.py" 2>/dev/null || true)
  if [ -n "$INIT_FILES" ]; then
    while IFS= read -r init; do
      if grep -qEi '(requests\.post|urllib\.request\.urlopen|http\.client\.HTTP|socket\.connect)' "$init" 2>/dev/null; then
        add_finding "init-network" "__init__.py 中有网络调用" "high" "$init"
      fi
    done <<< "$INIT_FILES"
  fi

  # 4. exec/eval + 编码
  EXEC_FILES=$(grep -rlE '(exec|eval|compile)\s*\(' "$EXTRACT_DIR" --include="*.py" 2>/dev/null || true)
  if [ -n "$EXEC_FILES" ]; then
    while IFS= read -r ef; do
      if grep -qEi '(base64|codecs\.decode|bytes\.fromhex|decode\()' "$ef" 2>/dev/null; then
        add_finding "obfuscated-exec" "exec/eval 执行编码内容" "critical" "$ef"
      fi
    done <<< "$EXEC_FILES"
  fi

  # 5. 大段 base64
  B64_FILES=$(grep -rlE '[A-Za-z0-9+/]{200,}={0,2}' "$EXTRACT_DIR" --include="*.py" 2>/dev/null || true)
  if [ -n "$B64_FILES" ]; then
    add_finding "base64-blob" "发现大段 base64 编码（>200字符）" "high" "$(echo "$B64_FILES" | head -1)"
  fi

  # 6. 敏感目录访问
  SENSITIVE=$(grep -rnE '(\.ssh|\.aws|\.kube|\.gnupg|\.config/gcloud|credentials)' "$EXTRACT_DIR" --include="*.py" 2>/dev/null | head -5 || true)
  if [ -n "$SENSITIVE" ]; then
    add_finding "sensitive-access" "发现敏感目录/文件访问模式" "critical" ""
  fi

  # 7. 环境变量批量读取
  ENV_COUNT=$(grep -rnE 'os\.environ' "$EXTRACT_DIR" --include="*.py" 2>/dev/null | wc -l || echo "0")
  if [ "$ENV_COUNT" -gt 10 ]; then
    add_finding "env-harvest" "大量环境变量读取 (${ENV_COUNT} 处)" "high" ""
  fi

  # 8. 异常二进制文件
  BIN_FILES=$(find "$EXTRACT_DIR" \( -name "*.so" -o -name "*.dll" -o -name "*.dylib" -o -name "*.exe" \) 2>/dev/null || true)
  if [ -n "$BIN_FILES" ]; then
    BIN_COUNT=$(echo "$BIN_FILES" | wc -l)
    add_finding "binary-files" "包含 ${BIN_COUNT} 个二进制文件" "medium" ""
  fi

elif [ "$ECOSYSTEM" = "npm" ]; then
  # npm pack + extract
  cd "$INSPECT_DIR"
  npm pack "$PACKAGE${VERSION:+@$VERSION}" 2>/dev/null || {
    echo '{"error":"下载失败","package":"'"$PACKAGE"'"}'
    rm -rf "$INSPECT_DIR"
    exit 1
  }

  EXTRACT_DIR="$INSPECT_DIR/extracted"
  mkdir -p "$EXTRACT_DIR"
  for f in *.tgz; do
    [ -f "$f" ] && tar xzf "$f" -C "$EXTRACT_DIR" 2>/dev/null || true
  done

  # 扫描 package.json 安装脚本
  PKG_JSON=$(find "$EXTRACT_DIR" -name "package.json" -maxdepth 2 2>/dev/null | head -1 || true)
  if [ -n "$PKG_JSON" ]; then
    INSTALL_SCRIPTS=$(python3 -c "
import json
with open('${PKG_JSON}') as f:
    d = json.load(f)
scripts = d.get('scripts', {})
for k in ('preinstall','install','postinstall'):
    if k in scripts:
        print(f'{k}: {scripts[k]}')
" 2>/dev/null || echo "")
    if [ -n "$INSTALL_SCRIPTS" ]; then
      add_finding "install-scripts" "发现安装钩子: $INSTALL_SCRIPTS" "high" "$PKG_JSON"
    fi
  fi

  # 扫描 JS 文件
  EXEC_FILES=$(grep -rlE '(child_process|\.exec\(|\.execSync\()' "$EXTRACT_DIR" --include="*.js" 2>/dev/null || true)
  if [ -n "$EXEC_FILES" ]; then
    add_finding "child-process" "使用 child_process 执行命令" "high" "$(echo "$EXEC_FILES" | head -1)"
  fi

  NET_FILES=$(grep -rlE '(net\.connect|http\.request|https\.request|fetch\()' "$EXTRACT_DIR" --include="*.js" 2>/dev/null || true)
  if [ -n "$NET_FILES" ]; then
    add_finding "network-calls" "发现网络请求" "medium" "$(echo "$NET_FILES" | head -1)"
  fi

  B64_FILES=$(grep -rlE 'Buffer\.from\(.{50,},.*base64' "$EXTRACT_DIR" --include="*.js" 2>/dev/null || true)
  if [ -n "$B64_FILES" ]; then
    add_finding "base64-decode" "发现 base64 解码操作" "high" "$(echo "$B64_FILES" | head -1)"
  fi

  EVAL_FILES=$(grep -rlE 'eval\s*\(' "$EXTRACT_DIR" --include="*.js" 2>/dev/null || true)
  if [ -n "$EVAL_FILES" ]; then
    add_finding "eval-usage" "使用 eval()" "high" "$(echo "$EVAL_FILES" | head -1)"
  fi
fi

# ─── 综合判定 ───
echo "$FINDINGS" | python3 -c "
import json, sys
findings = json.load(sys.stdin)
critical = sum(1 for f in findings if f['severity'] == 'critical')
high = sum(1 for f in findings if f['severity'] == 'high')
medium = sum(1 for f in findings if f['severity'] == 'medium')
verdict = 'red' if critical > 0 else ('yellow' if high > 0 else 'green')
print(json.dumps({
    'package': '${PACKAGE}',
    'ecosystem': '${ECOSYSTEM}',
    'version': '${VERSION}',
    'findings': findings,
    'summary': {'critical': critical, 'high': high, 'medium': medium},
    'verdict': verdict
}, ensure_ascii=False, indent=2))
"

# 清理
rm -rf "$INSPECT_DIR"
