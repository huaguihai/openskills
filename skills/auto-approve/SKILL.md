---
name: auto-approve
version: 1.0.0
description: >
  分析 Claude Code 工具授权日志，发现高频操作模式，交互确认后加入自动授权清单。
  减少重复审批，提升效率。使用 /auto-approve 触发分析。
  Analyzes Claude Code tool approval logs, discovers high-frequency patterns,
  and adds user-confirmed patterns to an auto-approve list to reduce repetitive approvals.
metadata:
  author: github.com/huaguihai
  requires: jq, python3
allowed-tools:
  - Bash
  - Read
---

# /auto-approve — Claude Code 授权自学习

通过 Hooks 记录工具授权习惯，分析高频模式，经用户确认后自动放行，减少重复审批。

## 架构

```
PostToolUse hook (每次工具执行后自动记录)
        │
        ▼
approval-log.jsonl  ──→  /auto-approve (用户手动触发)
                              │
                              ▼
                    候选规则 → 用户逐条确认 → learned-rules.json
                                                    │
                                                    ▼
                              PreToolUse hook (命中规则 → 自动放行)
```

## 安装

### 前置要求

- `jq` (命令行 JSON 处理器)
- `python3` (3.6+)

### 一键安装

```bash
bash ~/.claude/skills/auto-approve/scripts/install.sh
```

安装脚本会:
1. 复制 hooks 和分析脚本到 `~/.claude/auto-approve/`
2. 在 `~/.claude/settings.json` 注册 PreToolUse / PostToolUse hooks
3. 创建数据目录

### 手动安装

如果你更喜欢手动操作，参见 `scripts/install.sh` 中的步骤。

## 使用

1. **安装后重启 Claude Code** — hooks 自动生效，开始静默记录工具调用日志
2. **正常使用几天** — 积累数据（同类操作至少 ≥ 3 次，跨 ≥ 2 天）
3. **在 Claude Code 中输入 `/auto-approve`** — 触发分析
4. **逐条确认候选规则** — 通过的规则立即生效，下次自动放行

## 安全机制

- **危险命令黑名单**: `rm -rf`、`sudo`、`git push`、`chmod` 等 20 种危险模式永不推荐
- **阈值保护**: 必须 ≥ 3 次且跨 ≥ 2 天才会被推荐
- **泛化上限**: Bash 通配前缀至少保留 2 个 token，防止出现 `Bash(*)`
- **人工确认**: 所有规则必须用户逐条 Y/n 确认，不会静默生效
- **审计日志**: 全量记录保留在 `approval-log.jsonl`，包括自动放行的记录

## 文件结构

```
~/.claude/auto-approve/
├── hooks/
│   ├── pre-tool-use.sh     # PreToolUse: 查规则匹配则放行
│   └── post-tool-use.sh    # PostToolUse: 记录每次工具执行
├── analyze.py              # 分析引擎（/auto-approve 触发）
├── deny-patterns.json      # 危险模式黑名单
└── data/
    ├── approval-log.jsonl   # 审计日志（自动生成）
    └── learned-rules.json   # 已确认的自动授权规则
```

## 卸载

```bash
bash ~/.claude/skills/auto-approve/scripts/uninstall.sh
```

## 执行步骤

运行分析脚本:

```bash
python3 ~/.claude/auto-approve/analyze.py
```

脚本会交互式地让用户逐条 Y/n 确认候选规则。确认的规则立即写入 `learned-rules.json`。
