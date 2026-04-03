# README 编写规范（AI 时代版）

**制定时间**：2026-04-03
**制定人**：老大
**版本**：v2.0

---

## 设计目标

一份好的 README 要同时服务两类读者：

- **人类**：3 秒判断"这项目跟我有没有关系"，30 秒跑起来
- **AI Agent**：拿到 README 就能自主完成 clone → install → configure → run → verify 全流程，不需要人类补充信息

---

## 一、首屏黄金区（3 秒定生死）

打开 README 的前 3 秒决定用户去留。首屏必须包含：

1. **项目名 + 一句话定位**（≤ 20 字，说清楚"这东西是干嘛的"）
2. **Badges**：语言/框架版本、License、CI 状态、包版本号——只放有信息量的，不要堆装饰
3. **适用 / 不适用场景**（可选但推荐，帮用户快速排除）

```markdown
# cckey

管理多个 Anthropic API key 自动轮换的 CLI 工具。

[![Node](https://img.shields.io/badge/node-%3E%3D18-brightgreen)]()
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)]()

**适合**：需要多 key 负载均衡、自动容错的 API 重度用户
**不适合**：只有一个 key 的轻度使用者
```

**不要**：用大段文字描述项目愿景。没人在首屏看小作文。

---

## 二、AI Agent 快速接入

> 这是整份规范的核心差异点。传统 README 假设用户懂代码、会操作；AI 时代的 README 要让 Agent 能"自助"跑通。

### 2.1 结构化元数据块

在 README 顶部（badges 之后）放一段 HTML 注释，AI 解析这段比读自然语言快且准：

```html
<!-- AI-CONTEXT
project: cckey
one-liner: Anthropic API key 轮换管理 CLI
language: Node.js
min_runtime: node >= 18.0.0
package_manager: npm
install: npm install -g cckey
config_file: ~/.cckey/config.json
test: npm test
verify: cckey --version
entry: src/index.js
-->
```

字段说明：

| 字段 | 必填 | 说明 |
|------|------|------|
| `project` | 是 | 项目名 |
| `one-liner` | 是 | 一句话说明 |
| `language` | 是 | 主语言 |
| `min_runtime` | 是 | 运行环境最低版本 |
| `package_manager` | 是 | 包管理器（npm / pip / cargo 等） |
| `install` | 是 | 安装命令 |
| `test` | 否 | 测试命令 |
| `verify` | 是 | 安装成功的验证命令 |
| `config_file` | 否 | 配置文件路径 |
| `entry` | 否 | 程序入口文件 |

### 2.2 Agent Quick Start 区块

面向"用户把 README 丢给 AI"的场景。要求：

1. **完整可执行**——从 clone 到验证成功，中间不需要人类补充任何信息
2. **环境检查在前**——先确认环境，再装东西
3. **验证在后**——必须有明确的"成功标志"

```markdown
## Agent Quick Start

复制以下内容给你的 AI 助手，它会自主完成所有操作：

\```bash
# 环境检查
node -v  # 需要 >= 18.0.0，不满足请先升级

# 安装
git clone https://github.com/xxx/cckey.git
cd cckey
npm install

# 配置（首次使用）
mkdir -p ~/.cckey
cat > ~/.cckey/config.json << 'EOF'
{
  "keys": ["sk-ant-xxx-your-key-1", "sk-ant-xxx-your-key-2"],
  "strategy": "round-robin"
}
EOF

# 验证安装成功
cckey --version   # 应输出 1.x.x
cckey health      # 应显示所有 key 状态为 active
\```
```

### 2.3 Troubleshooting（Top 3 即可）

AI 跑到一半报错时，需要 README 里有对应的恢复指引。**只写最常见的 3 个问题**，不要写成 FAQ 大全：

```markdown
## 常见问题

**`EACCES: permission denied` 安装失败？**
→ `sudo npm install -g cckey` 或改用 `npx cckey`

**`API key invalid` 报错？**
→ 运行 `cckey health` 检查各 key 状态，过期的 key 从配置中移除

**启动后端口被占用？**
→ `lsof -i :3000` 找到占用进程，`kill` 掉或改配置文件里的 port
```

---

## 三、视觉友好——让人快速扫读

### 3.1 信息分层

| 层级 | 内容 | 展示方式 |
|------|------|---------|
| 必读 | 首屏、安装、基本用法 | 直接展开 |
| 按需 | 高级配置、自定义模板 | `<details>` 折叠 |
| 参考 | 完整配置项、API 列表 | 表格，或链接到独立文档 |

### 3.2 图表优先

- 架构图、流程图**优先用 Mermaid**（GitHub 原生渲染，AI 可读可改）
- Mermaid 不够用时再用 ASCII art 或 PNG
- 每张图必须有文字标题，不要让图"裸奔"

```markdown
### 架构总览

\```mermaid
graph LR
    A[CLI 输入] --> B[命令解析]
    B --> C[上下文构建]
    C --> D[AI 引擎]
    D --> E[输出格式化]
    E --> F[写入文件/stdout]
\```
```

### 3.3 超过 300 行加目录

长文档在首屏之后、正文之前加 TOC。手写或用工具生成都行，保持更新即可。

### 3.4 Badge 克制

只放有信息量的 badge（CI 状态、版本号、License）。不要堆 10 个装饰性 badge，那是视觉噪音。

---

## 四、工作原理——降低理解成本

这是让 AI（和人类）快速理解项目的关键区块。

### 必须包含

1. **架构图**（Mermaid 优先）
2. **核心流程**：4-6 个步骤，每步标注对应源文件路径
3. **关键设计决策**：3-5 个，用"为什么"句式，解释 tradeoff

### 示例

```markdown
## 工作原理

### 核心流程

1. **命令解析**（`src/cli/parser.js`）
   - commander.js 解析参数，提取意图和目标文件

2. **上下文构建**（`src/context/builder.js`）
   - 读取文件内容 + 分析 import 依赖
   - 控制上下文不超过 8K tokens

3. **AI 调用**（`src/ai/engine.js`）
   - 流式 API 请求，3 次指数退避重试

4. **输出处理**（`src/output/formatter.js`）
   - 提取代码块 → 语法验证 → 格式化 → 写入

### 关键设计决策

- **为什么用流式 API？** 大文件生成时用户实时看到进度，不用干等
- **为什么限制 8K tokens？** 超过这个阈值，成本涨但效果不涨
- **为什么做语法验证？** AI 生成的代码可能有语法错，先验后写避免破坏项目
```

---

## 五、中文版

- 所有对外项目必须有中文版（双语同文件或独立 `README.zh-CN.md`）
- 中文版不是逐句翻译，是**本地化适配**：
  - 命令和代码保持英文，注释用中文
  - 补充国内替代方案（npm 镜像、GitHub 加速等）
  - 可以省略对国内用户无意义的段落（如 Contributing guidelines）

---

## 六、文案去 AI 味

README 是工具说明书，不是产品宣传页。像给同事写使用说明一样写。

### 禁止清单

| 类型 | 反例 | 改成 |
|------|------|------|
| 空泛形容 | "强大的"、"优雅的"、"无缝集成" | 删掉，或换成具体数字/场景 |
| 技术吹嘘 | "采用先进的微服务架构" | "4 个独立服务，通过 HTTP 通信" |
| AI 八股开头 | "在当今快速发展的…" | 直接说是什么、干什么 |
| 均匀三段式 | 每个功能都 What/Why/How | 有话则长，无话则短 |
| AI 味标题 | What It Does / How It Works | 核心功能 / 工作原理 |
| 虚假亲切 | "让我们开始吧！🚀" | 删掉 |

### 检验方法

读一遍你写的 README，问自己：**"这像是一个真正在用这个工具的人写的，还是像 AI 生成后没改过的？"** 如果答案是后者，重写。

---

## 七、弹性骨架

骨架分三层。必选项保证基本质量，推荐项提升体验，可选项按项目需要自由组合。

### Section 顺序与分层

| 顺序 | Section | 层级 | 说明 |
|------|---------|------|------|
| 1 | 项目名 + 一句话定位 | **必选** | ≤ 20 字说清是什么 |
| 2 | Badges | **必选** | 只放有信息量的 |
| 3 | AI-CONTEXT 元数据 | **必选** | HTML 注释，AI 机器可读 |
| 4 | 适用 / 不适合场景 | 推荐 | 帮用户 3 秒内判断相关性 |
| 5 | 目录（TOC） | 条件必选 | 超过 300 行时必须有 |
| 6 | Agent Quick Start | **必选** | 完整可执行的自动化流程 |
| 7 | 核心功能 | **必选** | 表格或短列表 |
| 8 | 工作原理 | 推荐 | 架构图 + 流程 + 设计决策 |
| 9 | 安装 | **必选** | 含环境要求 |
| 10 | 配置 | 条件必选 | 有配置文件的项目必须有 |
| 11 | 基本用法 | **必选** | 可直接复制运行的示例 |
| 12 | 高级功能 | 可选 | `<details>` 折叠 |
| 13 | 配置参考 | 可选 | 完整参数表格 |
| 14 | 常见问题 | **必选** | Top 3 报错及解法 |
| 15 | — 扩展插槽 — | 可选 | 见下方"个性化扩展区" |
| 16 | License | **必选** | — |
| 17 | 中文版 | 推荐 | 对外项目必须有 |

### 个性化扩展区（第 15 槽位）

不同项目有不同需求，以下 section 按需插入，位置统一放在"常见问题"之后、"License"之前：

| Section | 适用场景 | 放置建议 |
|---------|---------|---------|
| **Roadmap** | 有明确迭代计划的项目 | checkbox 列表，标注预期版本号 |
| **Migration Guide** | 有破坏性变更的大版本升级 | 按版本号分区，列出 breaking changes + 迁移步骤 |
| **Benchmarks** | 性能敏感的项目（数据库、网络库等） | 表格或图表，标注测试环境和方法 |
| **Security Policy** | 处理认证/加密/用户数据的项目 | 漏洞上报方式 + 支持的版本范围 |
| **Examples 目录** | SDK、框架类项目 | 链接到 `/examples` 目录，每个示例一行简介 |
| **Changelog** | 发布频率高的项目 | 链接到 `CHANGELOG.md`，README 里只放最近 3 个版本摘要 |
| **Contributing** | 接受外部贡献的开源项目 | 链接到 `CONTRIBUTING.md`，README 里只放"我们需要帮助的方向" |
| **致谢 / Sponsors** | 有赞助或重要依赖致谢 | 简短列表或 logo 行 |
| **相关项目** | 生态内有配套工具 | 表格：项目名 + 一句话说明 + 链接 |
| **API Reference** | 提供 API 的库 | 链接到独立文档站或 `/docs`，README 里只放快速示例 |
| **Docker / 部署** | 提供容器化部署的项目 | docker run 一行命令 + docker-compose 示例 |

**原则**：扩展区的 section 不设上限，但每个 section 在 README 里的篇幅要克制——详细内容链接到独立文件，README 里只放摘要和入口。

### AI-CONTEXT 元数据扩展字段

当项目有个性化内容时，在基础字段之外追加对应字段，让 AI 也能感知：

```html
<!-- AI-CONTEXT
project: my-db-driver
one-liner: 高性能 PostgreSQL 连接池
language: Rust
min_runtime: rustc >= 1.75
package_manager: cargo
install: cargo install my-db-driver
verify: my-db-driver --version
# — 以下为可选扩展字段 —
docker: docker run -p 5432:5432 my-db-driver
docs: https://my-db-driver.dev/docs
changelog: CHANGELOG.md
benchmark: benches/README.md
migration_guide: docs/MIGRATION-v3.md
-->

---

## 八、质检 Checklist（按项目规模分级）

不同规模的项目，要求不同。先判断项目级别，再对照对应的 checklist。

### 项目分级

| 级别 | 判断标准 | 典型例子 |
|------|---------|---------|
| **S 级（小）** | 单文件或 < 500 行代码，无配置文件 | 一个 shell 脚本、一个 utils 库 |
| **M 级（中）** | 多文件、有配置、有依赖 | CLI 工具、小型 Web 应用 |
| **L 级（大）** | 多模块/多服务、有 API、面向外部用户 | 框架、SDK、开源项目 |

### Checklist

| # | 检查项 | S 级 | M 级 | L 级 | 通过标准 |
|---|--------|------|------|------|---------|
| 1 | 首屏信息密度 | ✅ | ✅ | ✅ | 项目名 + 一句话定位 + badges |
| 2 | AI-CONTEXT 元数据 | ✅ | ✅ | ✅ | 基础字段完整 |
| 3 | Agent Quick Start | ✅ | ✅ | ✅ | clone → install → verify 可执行 |
| 4 | 核心功能 | ✅ | ✅ | ✅ | 表格或列表 |
| 5 | 安装 + 基本用法 | ✅ | ✅ | ✅ | 可直接复制运行 |
| 6 | 验证命令 | ✅ | ✅ | ✅ | 有明确的成功标志 |
| 7 | 去 AI 味 | ✅ | ✅ | ✅ | 无空泛形容、无八股开头 |
| 8 | 常见问题 | — | ✅ | ✅ | Top 3 报错及解法 |
| 9 | 工作原理 | — | ✅ | ✅ | 架构图 + 流程 + 源文件路径 |
| 10 | 设计决策 | — | ✅ | ✅ | 3-5 个"为什么" |
| 11 | 配置参考 | — | ✅ | ✅ | 完整参数表格 |
| 12 | 信息分层 | — | — | ✅ | 必读展开、按需折叠 |
| 13 | 中文版 | — | — | ✅ | 本地化（非翻译） |
| 14 | 扩展区按需填充 | — | — | ✅ | Roadmap/Migration 等该有的都有 |

### 判定标准

- **S 级**（7 项必查）：7/7 = ✅ ｜ 6/7 = ⚠️ ｜ < 6 = ❌
- **M 级**（11 项必查）：11/11 = ✅ ｜ 9-10 = ⚠️ ｜ < 9 = ❌
- **L 级**（14 项必查）：14/14 = ✅ ｜ 12-13 = ⚠️ ｜ < 12 = ❌

---

## 九、应用场景

- 所有新项目的 README 必须遵循本规范
- 现有项目逐步改造，优先级：对外开源 > 内部工具 > 个人项目
- 做成 skill 后，触发词：`写 README`、`生成 README`、`优化 README`、`README 质检`
