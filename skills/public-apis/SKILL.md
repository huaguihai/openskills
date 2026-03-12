---
name: public-apis
description: >
  Find and recommend free, public APIs for any project. Use this skill whenever someone
  needs an API — whether they ask "is there a free weather API?", "I need to add payment
  to my app", "find me something for sending emails", or are building a feature that
  clearly requires a third-party service (maps, auth, data feeds, etc.). Covers 1400+
  APIs across 51 categories including weather, finance, geocoding, entertainment, games,
  social media, machine learning, health, transportation, and more. Also use this when
  someone asks about public-apis, the GitHub API directory, or wants to compare API
  options for a given use case. Handles both English and Chinese queries (天气API, 免费接口, 地图服务).
---

# Public APIs — 免费 API 推荐助手

> 数据来源：[public-apis/public-apis](https://github.com/public-apis/public-apis)（GitHub 407K+ stars）
> 收录了 1425 个免费 API，覆盖 51 个分类
> 同步日期：2026-03-12

## 工作流程

1. **理解需求** — 用户想实现什么功能？是前端调用（需要 CORS）还是后端？对认证复杂度有偏好吗？
2. **匹配分类** — 从下方分类索引中找到 1-3 个最相关的分类。分类名本身语义清晰，大部分情况可以直接匹配；对于不太直观的映射，参考底部的「易混淆分类映射」。
3. **读取 reference 文件** — 用 Read 工具加载对应的 `references/<slug>.md`，文件内是该分类下所有 API 的表格。
4. **筛选并推荐 3-5 个 API** — 优先考虑：
   - 功能与需求的匹配度（最重要）
   - 认证简单性：无需认证 > `apiKey` > `User-Agent` > `OAuth`
   - HTTPS 支持（优先 Yes）
   - CORS 支持（前端场景优先 Yes）
5. **结构化输出** — 使用下方的推荐格式呈现结果，给出推荐理由帮助用户决策。

## 分类索引

根据用户需求匹配分类后，使用 Read 工具读取对应 reference 文件。reference 文件路径相对于本 skill 目录。

<!-- CATEGORY_TABLE_START -->
| 分类 | API 数量 | Reference 文件 |
| --- | --- | --- |
| Animals | 27 | `references/animals.md` |
| Anime | 19 | `references/anime.md` |
| Anti-Malware | 15 | `references/anti-malware.md` |
| Art & Design | 20 | `references/art-and-design.md` |
| Authentication & Authorization | 7 | `references/authentication-and-authorization.md` |
| Blockchain | 11 | `references/blockchain.md` |
| Books | 23 | `references/books.md` |
| Business | 23 | `references/business.md` |
| Calendar | 16 | `references/calendar.md` |
| Cloud Storage & File Sharing | 19 | `references/cloud-storage-and-file-sharing.md` |
| Continuous Integration | 6 | `references/continuous-integration.md` |
| Cryptocurrency | 64 | `references/cryptocurrency.md` |
| Currency Exchange | 17 | `references/currency-exchange.md` |
| Data Validation | 7 | `references/data-validation.md` |
| Development | 120 | `references/development.md` |
| Dictionaries | 13 | `references/dictionaries.md` |
| Documents & Productivity | 28 | `references/documents-and-productivity.md` |
| Email | 17 | `references/email.md` |
| Entertainment | 10 | `references/entertainment.md` |
| Environment | 17 | `references/environment.md` |
| Events | 3 | `references/events.md` |
| Finance | 45 | `references/finance.md` |
| Food & Drink | 24 | `references/food-and-drink.md` |
| Games & Comics | 96 | `references/games-and-comics.md` |
| Geocoding | 86 | `references/geocoding.md` |
| Government | 86 | `references/government.md` |
| Health | 31 | `references/health.md` |
| Jobs | 17 | `references/jobs.md` |
| Machine Learning | 22 | `references/machine-learning.md` |
| Music | 33 | `references/music.md` |
| News | 19 | `references/news.md` |
| Open Data | 35 | `references/open-data.md` |
| Open Source Projects | 9 | `references/open-source-projects.md` |
| Patent | 4 | `references/patent.md` |
| Personality | 23 | `references/personality.md` |
| Phone | 5 | `references/phone.md` |
| Photography | 29 | `references/photography.md` |
| Programming | 5 | `references/programming.md` |
| Science & Math | 33 | `references/science-and-math.md` |
| Security | 38 | `references/security.md` |
| Shopping | 14 | `references/shopping.md` |
| Social | 40 | `references/social.md` |
| Sports & Fitness | 32 | `references/sports-and-fitness.md` |
| Test Data | 25 | `references/test-data.md` |
| Text Analysis | 15 | `references/text-analysis.md` |
| Tracking | 9 | `references/tracking.md` |
| Transportation | 69 | `references/transportation.md` |
| URL Shorteners | 19 | `references/url-shorteners.md` |
| Vehicle | 6 | `references/vehicle.md` |
| Video | 43 | `references/video.md` |
| Weather | 31 | `references/weather.md` |
<!-- CATEGORY_TABLE_END -->

## Reference 文件字段说明

每个 reference 文件是一个 Markdown 表格，字段含义：

| 字段 | 含义 |
| --- | --- |
| **API** | 名称 + 链接 |
| **Description** | 功能简述 |
| **Auth** | 认证方式（空 = 无需认证, `apiKey`, `OAuth`, `User-Agent`） |
| **HTTPS** | 是否支持 HTTPS |
| **CORS** | 是否支持跨域（Yes / No / Unknown） |

## 推荐输出格式

推荐 3 个以上时用对比表，少于 3 个用卡片格式：

### 对比表（优先使用）

| API | 简介 | 认证 | HTTPS | CORS | 推荐理由 |
| --- | --- | --- | --- | --- | --- |
| [名称](链接) | 功能描述 | 认证方式 | Yes/No | Yes/No | 为什么适合 |

### 卡片格式

**[API 名称](链接)**
- 简介：功能描述
- 认证：认证方式 | HTTPS：Yes/No | CORS：Yes/No
- 推荐理由：为什么适合用户需求

## 易混淆分类映射

大部分需求可以直接从分类名匹配，以下列出容易映射错误的场景：

| 用户需求 | 正确分类（非直觉） |
| --- | --- |
| 地图、经纬度、地址解析、IP 定位 | Geocoding（不是 Geography） |
| 电影、电视剧 | Entertainment（不是 Video） |
| 笑话、名言、随机趣味内容 | Personality |
| 翻译、词典 | Dictionaries |
| 短信、电话号码验证 | Phone |
| 物流追踪、快递查询 | Tracking（不是 Transportation） |
| 空气质量、污染数据 | Environment |
| 测试用假数据、mock data | Test Data |
| 恶意软件检测、病毒扫描 | Anti-Malware（不是 Security） |
| 占位图片（placeholder） | Photography（如 PlaceKitten 在 Animals） |
| 比特币、以太坊价格 | Cryptocurrency（不是 Finance） |
| 汇率转换 | Currency Exchange（不是 Finance） |

## 数据同步

运行 `scripts/split_readme.py` 从上游仓库更新数据。脚本会自动更新本文件的分类索引表。

```bash
python3 scripts/split_readme.py              # 从 GitHub 下载
python3 scripts/split_readme.py --input FILE # 使用本地文件
python3 scripts/split_readme.py --dry-run    # 预览模式
```
