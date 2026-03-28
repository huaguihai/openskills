# smart-fetch 站点经验库

记录已验证的站点抓取模式。使用前查表，命中则直接按验证模式执行，跳过路由试错。

---

## x.com / twitter.com

- **有效方式**：Jina 前缀 + curl
- **命令**：`curl -s "https://r.jina.ai/https://x.com/{user}/status/{id}" -H "Accept: text/plain" --max-time 30`
- **失败方式**：直接 WebFetch / curl 返回登录墙（"Don't miss what's happening"）
- **注意**：Jina URL 保留 `https://`，即 `r.jina.ai/https://x.com/...`
- **验证时间**：2026-03-28

---

## github.com

- **有效方式**：WebFetch 直接抓取，Jina 也可
- **README**：直接访问仓库主页或 raw 链接
- **验证时间**：通用经验

---

## zhihu.com（知乎）

- **有效方式**：Jina 前缀 + WebFetch
- **注意**：部分专栏文章需要登录，Jina 可绕过大部分
- **失败信号**：返回「登录后查看完整内容」→ 降级或告知用户

---

## juejin.cn（掘金）

- **有效方式**：Jina 前缀 + WebFetch
- **验证时间**：通用经验

---

## sspai.com（少数派）

- **有效方式**：Jina 前缀 + WebFetch
- **验证时间**：通用经验

---

## medium.com

- **有效方式**：Jina 前缀（绕过 paywall 效果较好）
- **注意**：付费文章 Jina 也可能被截断

---

## xiaohongshu.com（小红书）

- **有效方式**：需要 CDP（web-access skill）
- **失败方式**：Jina / WebFetch / curl 均返回空或登录墙
- **结论**：超出 smart-fetch 范围，转 web-access

---

## mp.weixin.qq.com（微信公众号）

- **有效方式**：Jina 对部分公开文章有效
- **失败信号**：返回「请在微信客户端打开」→ 需要 CDP
- **结论**：公开文章先试 Jina，失败转 web-access
