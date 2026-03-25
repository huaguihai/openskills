# openskills

开源 AI Agent 技能集，适用于 [OpenClaw](https://github.com/anthropics/openclaw) 和 Claude Code。

[🇺🇸 English](README.md)

## 技能列表

| 技能 | 简介 |
|------|------|
| [sentinel](skills/sentinel/) | 统一安全防护 — Skill 审查、依赖安装拦截（三层纵深防御）、项目漏洞体检、系统巡检 |
| [blog-pipeline](skills/blog-pipeline/) | 端到端博客写作流水线，含风格规范和独立审核 |
| [public-apis](skills/public-apis/) | 从 51 个分类中查找和推荐免费公共 API |

## Sentinel — 供应链防御

起因是 [LiteLLM PyPI 供应链攻击事件（2026-03-24）](https://x.com/karpathy/status/2036487306585268612)。一个简单的 `pip install` 就能从一个月下载量 9700 万的包中窃取 SSH 密钥、AWS 凭证和 API key。

Sentinel 把安全能力内化到 agent 自身 — 用户不需要任何技术知识。

**4 个模块：**

| 模块 | 功能 | 触发方式 |
|------|------|----------|
| M1: Skill 审查 | 安装 skill 前代码审计（13 项基础红线 + 6 项增强检查） | 安装 skill 时自动触发 |
| M2: 依赖拦截 | 三层防御：安装前元数据检查 → 安装后代码扫描 → 深度下载解包检查 | Claude Code Hook 自动触发 |
| M3: 项目体检 | 扫描现有依赖的已知漏洞（npm audit + pip-audit + OSV） | `/sentinel check` |
| M4: 系统巡检 | 进程/网络异常、凭证 DLP、文件完整性、磁盘容量 | `/sentinel audit` |

**M2 vs LiteLLM 攻击路径：**

| 攻击路径 | 第一层（安装前） | 第二层（安装后） | 第三层（深度） | 结果 |
|----------|:---:|:---:|:---:|------|
| 直接 `pip install litellm` | 标记新版本 + 维护者变更 | — | 检出 .pth + base64 | 拦截 |
| 经 `pip install dspy` 传递依赖 | dspy 本身通过 | 发现新增包 litellm 含 .pth | — | 告警 + 建议回滚 |

## 安装

```bash
# 复制单个 skill 到 OpenClaw
cp -r skills/sentinel ~/.openclaw/skills/

# 或复制到 Claude Code
cp -r skills/sentinel ~/.claude/skills/
```

sentinel 的依赖自动拦截（M2）需要配置 Claude Code hooks，详见 [sentinel/SKILL.md](skills/sentinel/SKILL.md)。

## 目录结构

```
skills/
├── sentinel/          # 安全：审查 + 依赖防御 + 巡检
│   ├── SKILL.md
│   ├── scripts/       # check-package.sh, scan-installed.sh 等
│   └── references/    # red-flags.md, known-malicious.md, suspicious-patterns.md
├── blog-pipeline/     # 博客写作流水线
└── public-apis/       # 公共 API 发现
```

## 许可证

MIT
