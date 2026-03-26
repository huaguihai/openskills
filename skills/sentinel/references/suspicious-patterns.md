# Suspicious Code Pattern Library

> Pattern matching rules used during sentinel M2 layer-2/layer-3 scanning.

## Python Packages

### 🔴 Critical — Immediate Alert

| Pattern | Regex | Description |
|---------|-------|-------------|
| .pth executing code | File `*.pth` containing `import \|exec\|eval\|subprocess\|socket\|http\|urllib\|requests` | LiteLLM attack technique |
| exec + encoding | `(exec\|eval\|compile)\s*\(.*?(base64\|codecs\.decode\|bytes\.fromhex\|decode\()` | Obfuscated execution |
| Sensitive directory access | `(\.ssh\|\.aws\|\.kube\|\.gnupg\|\.config/gcloud\|credentials)` in `.py` files | Credential theft |
| setup.py network calls | `setup.py` containing `requests\.\|urllib\|http\.client\|socket\.\|subprocess` | Install-time attack |

### 🟡 High — Requires Manual Review

| Pattern | Regex | Description |
|---------|-------|-------------|
| Large base64 block | `[A-Za-z0-9+/]{200,}={0,2}` | Possibly encoded malicious payload |
| Network exfiltration | `requests\.post\|urllib\.request\.urlopen\|http\.client\.HTTP\|socket\.connect` | Data exfiltration |
| Bulk env var reading | `os\.environ` appearing >10 times | Credential harvesting |
| setup.py cmdclass | `cmdclass.*?(install\|develop\|egg_info)` | Custom code execution during install |
| Unexpected binaries | `.so`/`.dll`/`.exe` files in a pure Python package | Possibly bundled malicious binaries |

### 🟢 Info — Logged but No Alert

| Pattern | Description |
|---------|-------------|
| `.pth` file present but content is only paths | Normal usage |
| `os.environ.get('KEY')` used sparingly | Normal configuration reading |

## npm Packages

### 🔴 Critical

| Pattern | Regex | Description |
|---------|-------|-------------|
| install hook + child_process | `package.json` scripts containing `preinstall\|postinstall` and code containing `child_process` | Install-time attack |
| eval + encoding | `eval\s*\(\s*(Buffer\|atob\|decode)` | Obfuscated execution |

### 🟡 High

| Pattern | Regex | Description |
|---------|-------|-------------|
| child_process usage | `child_process\|\.exec\(\|\.execSync\(` | Process creation |
| base64 decoding | `Buffer\.from\(.{50,},.*base64` | Suspicious encoding |
| eval usage | `eval\s*\(` | Dynamic execution |
| Network requests | `net\.connect\|http\.request\|https\.request` in non-HTTP client libraries | Unexpected network calls |

## Pattern Update Log

- 2026-03-25: Initial version, based on LiteLLM incident + npm historical supply chain attack summary
