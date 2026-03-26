---
name: sentinel
version: 1.0.0
description: >
  统一安全防护 skill。Skill 安全审查、依赖安装拦截（三层纵深防御）、项目漏洞体检、系统巡检。
  触发词：安全审查、安全检查、依赖检查、漏洞扫描、sentinel、哨兵、安装 skill、
  pip install、npm install、审查这个包、这个包安全吗、体检、巡检、security audit、vetting。
  吸收并替代 skill-vetter。
---

# Sentinel — 统一安全防护

所有安全能力集中在一处。4 个模块，自动触发，用户只需做红绿灯决策。

---

## 模块总览

| 模块 | 功能 | 触发方式 |
|------|------|----------|
| M1 | Skill 安全审查 | 安装 skill 前自动触发 |
| M2 | 依赖安装拦截（三层防御） | PreToolUse + PostToolUse Hook |
| M3 | 项目依赖体检 | `/sentinel check` 或定期 |
| M4 | 系统安全巡检 | `/sentinel audit` 或每日自动 |

---

## M1: Skill 安全审查

> 继承 skill-vetter 全部能力 + 增强

### 触发条件

用户要求安装 skill（从 ClawdHub、GitHub 或其他来源），或 agent 识别到安装 skill 的意图。

### Step 1: 来源检查

回答以下问题：
- 来源？（ClawdHub / GitHub / 其他）
- 作者是否知名/可信？
- star 数 / 下载量？
- 最后更新时间？
- 有没有其他用户评价？

### Step 2: 代码审查（强制）

读取 skill 的**所有文件**。对照以下红线清单（任何一条命中 → 立即标记）：

#### 基础红线（继承自 skill-vetter）

```
🚨 命中即标记：
─────────────────────────────────────────
• curl/wget 到未知 URL
• 向外部服务器发送数据
• 请求凭证/token/API key
• 读取 ~/.ssh、~/.aws、~/.config（无明确理由）
• 访问 MEMORY.md、USER.md、SOUL.md、IDENTITY.md
• 使用 base64 decode
• 使用 eval()/exec() 处理外部输入
• 修改 workspace 外的系统文件
• 安装未声明的包
• 网络调用使用 IP 而非域名
• 混淆代码（压缩、编码、minify）
• 请求 sudo 权限
• 访问浏览器 cookie/session
• 触碰凭证文件
```

#### 增强红线（sentinel 新增）

```
🚨 额外检查：
─────────────────────────────────────────
• 包含 .pth 文件
• 大段 base64/hex 编码内容（>100字符）
• 修改 CLAUDE.md 或 settings.json（权限提升）
• 注册 Claude Code Hook（可劫持其他操作）
• scripts/ 中有网络调用（curl、wget、fetch、requests）
  → 检查目标 URL 是否在 known-malicious.md 中
• 引入外部依赖 → 联动 M2 审查每个依赖
```

### Step 3: 权限范围评估

- 需要读哪些文件？
- 需要写哪些文件？
- 需要执行哪些命令？
- 是否需要网络访问？访问哪里？
- 权限范围是否最小化？

### Step 4: 风险分类

| 等级 | 示例 | 处置 |
|------|------|------|
| 🟢 LOW | 笔记、格式化、本地工具 | 基础审查后可安装 |
| 🟡 MEDIUM | 文件操作、浏览器、API调用 | 完整代码审查 |
| 🔴 HIGH | 涉及凭证、交易、系统配置 | 必须用户确认 |
| ⛔ EXTREME | 安全配置、root 权限、Hook 注册 | 不安装 |

### Step 5: 信任分层

1. **OpenClaw 官方 skill** → 较低审查（仍需审查）
2. **高 star 仓库（1000+）** → 中等审查
3. **已知作者** → 中等审查
4. **新/未知来源** → 最高审查
5. **请求凭证的 skill** → 必须用户确认

### Step 6: 输出报告

```
SENTINEL 安全审查报告
═══════════════════════════════════════
Skill: [名称]
来源: [ClawdHub / GitHub / 其他]
作者: [用户名]
版本: [版本号]
───────────────────────────────────────
指标:
• Star/下载量: [数量]
• 最后更新: [日期]
• 审查文件数: [数量]
───────────────────────────────────────
红线命中: [无 / 列出具体项]

权限需求:
• 文件: [列表或"无"]
• 网络: [列表或"无"]
• 命令: [列表或"无"]

外部依赖: [列表或"无"]
  → 依赖审查: [通过 / 见 M2 报告]
───────────────────────────────────────
风险等级: [🟢 LOW / 🟡 MEDIUM / 🔴 HIGH / ⛔ EXTREME]

结论: [✅ 可以安装 / ⚠️ 谨慎安装 / ❌ 不建议安装]

备注: [补充说明]
═══════════════════════════════════════
```

---

## M2: 依赖安装拦截（三层纵深防御）

### Hook 安装（必须，否则 M2 不生效）

M2 需要 Claude Code Hook 才能自动拦截。安装方式二选一：

**方式 A：独立 Hook（推荐新用户）**

在 `~/.claude/settings.json` 中添加：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash $HOME/.claude/skills/sentinel/hooks/sentinel-pre-install.sh",
            "timeout": 15000
          }
        ]
      }
    ]
  }
}
```

**方式 B：嵌入已有 Hook（已有 PreToolUse Hook 的用户）**

将 `hooks/sentinel-pre-install.sh` 中的核心逻辑嵌入到你现有的 pre-tool-use hook 中。参考脚本中的 `sentinel_should_block` 函数。

> **重要**：只拦截硬信号（typosquatting、known-malicious、publish-age < 48h、registry 不存在）。OSV 历史漏洞不带版本号查询会误杀正常包（如 express、flask），不作为自动拦截依据。

### 触发条件

Agent 执行 `pip install`、`pip3 install`、`npm install`、`yarn add`、`pnpm add` 时，由 Claude Code Hook 自动触发。

### 第一层：安装前拦截（Pre-Install Gate）

**PreToolUse Hook 拦截命令后，执行以下检查：**

1. 从命令中提取包名和版本号
2. 运行 `scripts/check-package.sh <ecosystem> <package> [version]`
3. 脚本查询 registry + OSV 数据库，返回风险评分

**多维度交叉评估（不只看单一指标）：**

| 维度 | 绿灯 | 黄灯 | 红灯 |
|------|------|------|------|
| 版本发布时间 | > 30 天 | < 7 天 | < 48 小时 |
| 维护者一致性 | 未变更 | — | 变更了 |
| 版本号跳跃 | 正常递增 | 小版本异常跳跃 | 大版本突变 |
| 发布间隔 | 符合历史节奏 | — | 突然插入 |
| OSV 漏洞记录 | 无 | 低危 | 中/高危 |
| known-malicious | 不在名单 | — | 在名单中 |
| typosquatting | 名字无歧义 | — | 与知名包高度相似 |

**判定规则：**
- 🟢 所有维度正常 → 放行，告知用户
- 🟡 单一可疑信号 → 警告用户，让用户决定；同时**自动升级到第三层深度检查**
- 🔴 多个可疑信号叠加 / 命中已知恶意 → 拦截，解释原因

**用户看到的（示例）：**

> 🟢 `requests 2.31.0` — 安全，已放行。

> 🟡 `some-package 3.1.0` — 最新版本 3 小时前刚发布，且维护者变更。建议等几天或锁定上一版本。继续安装还是跳过？

> 🔴 `req-uests 1.0.0` — 名称与知名包 `requests` 高度相似（typosquatting），且发布不到 1 天。已拦截。

### 第二层：安装后扫描（Post-Install Scan）

**堵传递依赖盲区。PostToolUse Hook 在 install 命令成功后触发。**

1. 对比安装前后的包列表（Pre-hook 已保存快照）
2. 找出所有新增的包（包括传递依赖）
3. 对每个新增包运行 `scripts/scan-installed.sh`：
   - 检查版本发布时间
   - 扫描安装目录，查找 `references/suspicious-patterns.md` 中的可疑模式：
     - `.pth` 文件
     - `setup.py` / `setup.cfg` 中的 post_install 钩子
     - base64/hex 编码的大段字符串（>100 字符）
     - 网络调用指向非知名域名
     - 文件系统扫描模式（遍历 `~/.ssh`、`~/.aws`、`~/.kube`）
     - 环境变量批量读取（`os.environ` 大规模遍历）
4. 发现可疑 → 红灯告警 + 建议立即卸载

**用户看到的（示例）：**

> 🔴 紧急警告 — 刚安装的 dspy 带入了一个危险的传递依赖：
>
> **litellm 1.82.8**（45 分钟前发布）包含恶意代码：
> - 发现 `litellm_init.pth` 文件
> - 包含 base64 编码指令，解码后会读取 ~/.ssh、~/.aws 并发送到外部服务器
>
> 建议立即卸载。要我执行 `pip uninstall litellm` 吗？

### 第三层：深度检查（Download & Inspect）

**第一层判定为 🟡 或 🔴 时自动触发。**

1. `pip download --no-deps -d /tmp/sentinel-inspect/ <pkg>==<version>` 下载但不安装
2. 解压 `.whl` 或 `.tar.gz`
3. 运行 `scripts/download-and-inspect.sh` 全面扫描：
   - 所有 `.pth` 文件
   - `__init__.py` 中的顶层网络调用
   - `setup.py` 的 `cmdclass` 覆写
   - 混淆代码特征（`exec()`、`eval()`、`compile()` + 编码字符串）
   - 异常文件类型（二进制文件出现在纯 Python 包中）
4. 生成扫描报告
5. 清理 `/tmp/sentinel-inspect/`

---

## M3: 项目依赖体检

### 触发条件

- 用户说"体检"、"漏洞扫描"、"sentinel check"
- `/sentinel check` — 当前项目
- `/sentinel check --all` — 所有已知项目

### 工作流

1. 检测项目类型（package.json / requirements.txt / pyproject.toml）
2. Node.js 项目：`npm audit --json`
3. Python 项目：`pip-audit -r requirements.txt --format json`（首次运行自动安装 pip-audit）
4. 所有项目：查询 OSV API（`https://api.osv.dev/v1/query`）交叉验证
5. 输出交通灯汇总

**用户看到的（示例）：**

```
📋 项目体检：clawdbot-blog
├── 🟢 0 个高危漏洞
├── 🟡 2 个中危漏洞
│   ├── next 14.2.3 → CVE-2024-xxx（建议升级到 15.x）
│   └── postcss 8.4.1 → CVE-2024-yyy（建议升级到 8.5+）
└── 🟢 无明文凭证泄露
```

---

## M4: 系统安全巡检

### 触发条件

- 用户说"巡检"、"安全审计"、"sentinel audit"
- `/sentinel audit` — 精简版（进程/网络、文件变更、凭证 DLP、skill 完整性）
- `/sentinel audit --full` — 完整版（等同 nightly）
- 每日 03:00 自动执行（nightly cron）

### 精简版巡检项

1. **进程/网络** — 异常监听端口、异常出站连接
2. **文件变更** — 敏感目录 24h 内的文件变更
3. **凭证 DLP** — 扫描 workspace 中是否有明文凭证泄露
4. **Skill 完整性** — SHA256 基线比对，检测 skill 文件是否被篡改
5. **磁盘容量** — 使用率超过 85% 告警

### 完整版额外巡检项

6. SSH 登录记录与爆破检测
7. 系统级定时任务扫描
8. OpenClaw Cron 任务健康检查
9. 关键文件完整性（SHA256 + 权限）
10. 黄线操作交叉验证
11. Gateway 配置检查

### 告警通知

发现红灯时，通过已配置的消息通道（Telegram / 飞书）推送告警：

```
🔴 Sentinel 安全告警
─────────────────────
[告警内容摘要]
详情: [报告文件路径]
```

---

## 诚实边界

sentinel 能防住大多数常见供应链攻击，但以下场景防不住：

- 被替换的已有版本且无可检测特征变化（registry 层面问题）
- 不经过 Claude Code 的直接 shell 操作（如 SSH 后手动 pip install）
- 0day 攻击模式（不在 suspicious-patterns.md 中的新型攻击手法）

这些是客户端安全的固有边界，需要 registry 平台和系统层面的防护配合。

---

## 记住

- 安全不是可选的，是默认的
- 有疑问就拦截，让用户决定
- 红灯 = 拦截 + 解释，黄灯 = 警告 + 用户选择，绿灯 = 放行 + 告知
- 宁可多拦一次，不可漏过一次
- 模式库（suspicious-patterns.md、known-malicious.md）持续更新

*Paranoia is a feature.* 🔒
