# 可疑代码模式库

> sentinel M2 第二层/第三层扫描时使用的模式匹配规则。

## Python 包

### 🔴 Critical — 立即告警

| 模式 | 正则 | 说明 |
|------|------|------|
| .pth 执行代码 | 文件 `*.pth` 内含 `import \|exec\|eval\|subprocess\|socket\|http\|urllib\|requests` | LiteLLM 攻击手法 |
| exec + 编码 | `(exec\|eval\|compile)\s*\(.*?(base64\|codecs\.decode\|bytes\.fromhex\|decode\()` | 混淆执行 |
| 敏感目录访问 | `(\.ssh\|\.aws\|\.kube\|\.gnupg\|\.config/gcloud\|credentials)` 在 `.py` 文件中 | 凭证窃取 |
| setup.py 网络调用 | `setup.py` 内含 `requests\.\|urllib\|http\.client\|socket\.\|subprocess` | 安装时攻击 |

### 🟡 High — 需人工判断

| 模式 | 正则 | 说明 |
|------|------|------|
| 大段 base64 | `[A-Za-z0-9+/]{200,}={0,2}` | 可能是编码的恶意载荷 |
| 网络外传 | `requests\.post\|urllib\.request\.urlopen\|http\.client\.HTTP\|socket\.connect` | 数据外泄 |
| 环境变量批量读取 | `os\.environ` 出现 >10 次 | 凭证收集 |
| setup.py cmdclass | `cmdclass.*?(install\|develop\|egg_info)` | 安装时执行自定义代码 |
| 异常二进制 | 纯 Python 包中出现 `.so`/`.dll`/`.exe` 文件 | 可能捆绑恶意二进制 |

### 🟢 Info — 记录但不告警

| 模式 | 说明 |
|------|------|
| `.pth` 文件存在但内容只是路径 | 正常用途 |
| `os.environ.get('KEY')` 少量使用 | 正常配置读取 |

## npm 包

### 🔴 Critical

| 模式 | 正则 | 说明 |
|------|------|------|
| install 钩子 + child_process | `package.json` scripts 含 `preinstall\|postinstall` 且代码含 `child_process` | 安装时攻击 |
| eval + 编码 | `eval\s*\(\s*(Buffer\|atob\|decode)` | 混淆执行 |

### 🟡 High

| 模式 | 正则 | 说明 |
|------|------|------|
| child_process 使用 | `child_process\|\.exec\(\|\.execSync\(` | 进程创建 |
| base64 解码 | `Buffer\.from\(.{50,},.*base64` | 可疑编码 |
| eval 使用 | `eval\s*\(` | 动态执行 |
| 网络请求 | `net\.connect\|http\.request\|https\.request` 在非 HTTP 客户端库中 | 意外网络调用 |

## 模式更新日志

- 2026-03-25: 初始版本，基于 LiteLLM 事件 + npm 历史供应链攻击总结
