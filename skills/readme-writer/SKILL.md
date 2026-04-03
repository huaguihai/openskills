---
name: readme-writer
description: |
  生成、优化或质检项目 README，同时服务人类读者和 AI Agent。自动分析项目规模（S/M/L），
  按弹性骨架生成结构，包含 AI-CONTEXT 元数据、Agent Quick Start、工作原理、质检 Checklist。
  当用户提到以下任何场景时使用此 skill：写 README、生成 README、优化 README、README 质检、
  改善 README、README 不好看、项目文档、帮我写个说明文档、这个项目缺个 README、
  review 一下 README。即使用户没有明确说"README"，只要他们在讨论项目文档、
  项目介绍、或者让你帮忙写项目说明，都应该触发此 skill。
---

# README Writer

生成同时服务人类和 AI Agent 的高质量 README。

## 核心理念

README 有两类读者：人类（3 秒判断项目相关性，30 秒跑起来）和 AI Agent（拿到 README 自主跑通全流程）。这个 skill 确保两类读者都满意。

## 工作流程

### Step 1：分析项目

在动手写之前，先搞清楚项目是什么。

1. **读代码**：扫描项目根目录的 `package.json`、`Cargo.toml`、`pyproject.toml`、`go.mod` 等，确定语言、依赖、入口文件
2. **读现有 README**：如果已有 README，先读一遍，保留有价值的内容
3. **判断项目级别**：

| 级别 | 判断标准 |
|------|---------|
| **S 级** | 单文件或 < 500 行，无配置文件 |
| **M 级** | 多文件、有配置、有依赖 |
| **L 级** | 多模块/多服务、有 API、面向外部用户 |

4. **确认操作模式**——问用户（如果不明确的话）：
   - **生成**：从零写一份新 README
   - **优化**：基于现有 README 改进
   - **质检**：只做检查，输出报告，不改文件

### Step 2：确认关键信息

向用户确认以下内容（如果从代码中无法自动推断）：

- 项目一句话定位（≤ 20 字）
- License 类型
- 是否需要中文版
- 有没有特殊的扩展需求（Roadmap、Benchmarks、Docker 部署等）

不要问太多问题。能从代码推断的就直接用，只问真正不确定的。

### Step 3：按弹性骨架生成

读取 `references/guidelines.md` 中第七节的弹性骨架，按项目级别生成对应内容。

**所有级别都必须有的 section**（按顺序）：

1. 项目名 + 一句话定位
2. Badges（有信息量的，不堆装饰）
3. AI-CONTEXT 元数据（HTML 注释块）
4. Agent Quick Start（完整可执行：环境检查 → 安装 → 配置 → 验证）
5. 核心功能（表格或短列表）
6. 安装（含环境要求）
7. 基本用法（可直接复制运行）
8. 常见问题（Top 3）
9. License

**M 级额外增加**：
- 工作原理（Mermaid 架构图 + 核心流程 + 设计决策）
- 配置参考（参数表格）

**L 级额外增加**：
- 目录（TOC）
- 适用/不适合场景
- 信息分层（高级功能用 `<details>` 折叠）
- 中文版
- 个性化扩展区（按需选择 Roadmap、Migration Guide 等）

### Step 4：去 AI 味

写完初稿后，做一遍去 AI 味检查。详细禁止清单见 `references/guidelines.md` 第六节，核心规则：

- 不用空泛形容词（"强大的"、"优雅的"、"无缝"）
- 不用 AI 八股开头（"在当今…"）
- 不用均匀三段式（每个功能都 What/Why/How）
- 不用虚假亲切（"让我们开始吧！"）
- 标题用中文自然表达（"核心功能"而非"What It Does"）
- 像给同事写使用说明一样写，不像产品宣传页

### Step 5：质检

对照 Checklist 检查。不同级别检查项数不同：

- **S 级**：7 项（首屏 + AI-CONTEXT + Agent Quick Start + 核心功能 + 安装用法 + 验证命令 + 去 AI 味）
- **M 级**：11 项（S 级 + 常见问题 + 工作原理 + 设计决策 + 配置参考）
- **L 级**：14 项（M 级 + 信息分层 + 中文版 + 扩展区）

完整 Checklist 在 `references/guidelines.md` 第八节。

**判定标准**：
- 全过 = 可发布
- 差 1-2 项 = 需小改
- 差 3 项以上 = 重写

### Step 6：输出

**生成/优化模式**：直接写入 `README.md`（如有中文版，同时写 `README.zh-CN.md`）

**质检模式**：输出质检报告，格式：

```markdown
## README 质检报告

**项目**：xxx
**级别**：M 级
**判定**：⚠️ 需小改

### Checklist

| # | 检查项 | 状态 | 备注 |
|---|--------|------|------|
| 1 | 首屏信息密度 | ✅ | — |
| 2 | AI-CONTEXT 元数据 | ❌ | 缺少 verify 字段 |
| ... | ... | ... | ... |

### 改进建议

1. 在 badges 后添加 AI-CONTEXT 元数据块，补充 verify 字段
2. ...
```

## 参考文档

完整规范细节（包括 AI-CONTEXT 字段表、Agent Quick Start 写法、去 AI 味禁止清单、弹性骨架、个性化扩展区、分级 Checklist）都在：

→ `references/guidelines.md`

写 README 时如果对任何细节不确定，先读这个文件对应章节。不要凭记忆猜规则。
