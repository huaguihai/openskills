---
name: smart-fetch
description: >
  智能网页抓取路由。拿到任意 URL，自动选择最合适的工具抓取内容，无需试错。
  触发场景：抓取网页、读取文章、获取推文、访问公开页面、提取 URL 内容。
  零依赖，无需 Chrome/CDP，适合服务器和无头环境。
version: "1.0.0"
metadata:
  author: github.com/huaguihai
---

# smart-fetch — 智能网页抓取路由

拿到 URL，按场景自动选择最合适的工具，不试错，5 秒出结果。

## 路由规则（按优先级执行）

| 优先级 | 场景 | 判断条件 | 工具 |
|--------|------|---------|------|
| 1 | 推文 / X | URL 含 `x.com` 或 `twitter.com` | Jina + curl |
| 2 | 文章 / 博客 / 文档 | 内容型页面（Medium、知乎、掘金、少数派、GitHub README、SubStack 等） | Jina + WebFetch |
| 3 | 关键词搜索 | 无具体 URL，需要发现信息 | WebSearch |
| 4 | 普通公开网页 | URL 已知，内容公开 | WebFetch |
| 5 | 需要原始 HTML | 需要 meta / JSON-LD / 结构化数据 | curl |
| 6 | 兜底 | 前几步返回空或错误 | curl + 浏览器 UA |

## 决策流程

1. **拿到请求** — 明确目标：是 URL 还是关键词？要提取什么内容？
2. **匹配路由** — 按上表优先级从高到低匹配场景，选第一个命中的工具
3. **执行** — 调用对应工具
4. **校验结果** — 返回内容是否有效？空内容 / 登录墙 / 报错 → 降级到下一个工具
5. **全部失败** — 告知用户：该页面需要登录态或浏览器环境（CDP），建议使用 web-access skill

## 工具使用规范

### Jina（首选预处理层）

将网页转为干净的 Markdown，大幅节省 token，适合正文提取。

```
调用方式：https://r.jina.ai/{原始完整URL}
示例：https://r.jina.ai/https://x.com/user/status/123
```

- 速率限制：20 RPM
- 适合：推文、文章、博客、文档、PDF
- 不适合：数据面板、商品列表、需要登录的内容
- 失败信号：返回 "Sign in" / "Log in" / 空内容 → 降级

**使用 curl 调用 Jina：**
```bash
curl -s "https://r.jina.ai/https://x.com/user/status/123" \
  -H "Accept: text/plain" \
  --max-time 30
```

**使用 WebFetch 调用 Jina：**
- url: `https://r.jina.ai/https://example.com/article`
- prompt: 描述要提取的内容

### WebSearch

用于关键词搜索、发现信息来源。无具体 URL 时的第一选择。

### WebFetch

已知 URL、内容公开时直接使用。由模型根据 prompt 提取内容，返回处理后结果。

### curl

需要原始 HTML 或 Jina/WebFetch 均失败时使用。

```bash
curl -s "{URL}" \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
  --max-time 30
```

## 站点经验

操作前先查 `references/site-patterns.md`，有命中站点则按已验证模式执行。

操作成功后，如发现新的有效模式或陷阱，主动更新 `references/site-patterns.md`。

## 边界说明

smart-fetch 覆盖**零依赖的公开内容抓取**。以下场景超出范围，建议使用 web-access skill：

- 需要登录态的内容（小红书、微信公众号、付费内容）
- 需要页面交互（点击、滚动、填表）
- 反爬强的平台（多次降级后仍失败）
- 需要 JS 渲染的动态页面
