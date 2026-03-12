---
name: public-apis
description: >
  Search and recommend free, public APIs from a curated collection of 1400+ APIs
  across 51 categories. Covers weather, finance, maps, geocoding, music, movies,
  games, news, social, authentication, machine-learning, AI, sports, food, recipes,
  animals, anime, books, calendar, cloud, cryptocurrency, currency, data, development,
  dictionaries, documents, email, entertainment, environment, events, government,
  health, jobs, music, open-data, patent, personality, phone, photography, science,
  security, shopping, social, transportation, URL-shorteners, vehicle, video, and more.
  Helps developers find the right API for their project. API directory, API catalog,
  API discovery, API recommendation, free API, open API, REST API, web service.
---

# Public APIs — 免费 API 推荐助手

> 数据来源：[public-apis/public-apis](https://github.com/public-apis/public-apis)（GitHub 407K+ stars）
> 收录了 1425 个免费 API，覆盖 51 个分类
> 同步日期：2026-03-12

## 字段说明

每个 API 条目包含以下字段：

| 字段 | 含义 | 取值 |
| --- | --- | --- |
| **API** | API 名称（通常含链接） | 文本 |
| **Description** | 功能简述 | 文本 |
| **Auth** | 认证方式 | 空 = 无需认证, `apiKey`, `OAuth`, `X-Mashape-Key`, `User-Agent` |
| **HTTPS** | 是否支持 HTTPS | Yes / No |
| **CORS** | 是否支持跨域 | Yes / No / Unknown |

**认证复杂度排序**（从简到繁）：无需认证 → apiKey → User-Agent → X-Mashape-Key → OAuth

## 分类索引

以下是所有分类及其对应的 reference 文件。**请根据用户需求匹配分类后，使用 Read 工具读取对应的 reference 文件获取详细 API 列表。**

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

## 工作流程

当用户询问 API 推荐时，按以下步骤操作：

1. **理解需求** — 明确用户要实现什么功能（如"天气预报"、"发送短信"、"图像识别"）
2. **匹配分类** — 根据下方「常见关键词映射」和分类索引，定位 1-3 个最相关的分类
3. **读取 reference** — 使用 Read 工具加载对应的 `references/*.md` 文件
4. **筛选推荐** — 根据以下优先级筛选：
   - 认证复杂度（优先推荐无需认证或仅 apiKey 的）
   - HTTPS 支持（优先 Yes）
   - CORS 支持（如用于前端，优先 Yes）
   - 功能匹配度（Description 与需求的相关性）
5. **对比呈现** — 使用下方输出格式模板，给出 2-5 个推荐

## 常见关键词映射

用户输入的关键词不一定精确匹配分类名，以下是常见映射：

| 用户关键词 | 对应分类 |
| --- | --- |
| weather, 天气, 气象 | Weather |
| map, 地图, geocode, 经纬度, 地址 | Geocoding |
| stock, 股票, 金融, payment, 支付 | Finance |
| crypto, 比特币, 以太坊, 区块链 | Cryptocurrency |
| currency, 汇率, 外汇 | Currency Exchange |
| movie, 电影, TV, 电视 | Entertainment |
| music, 音乐, song, 歌曲 | Music |
| book, 书, 图书, 阅读 | Books |
| news, 新闻, 头条 | News |
| game, 游戏, comic, 漫画 | Games & Comics |
| anime, 动漫, 动画 | Anime |
| animal, 动物, cat, dog, 猫, 狗 | Animals |
| food, 食物, recipe, 食谱, 饮料 | Food & Drink |
| health, 健康, medical, 医疗 | Health |
| sport, 运动, fitness, 健身, football, 足球 | Sports & Fitness |
| job, 工作, 招聘 | Jobs |
| email, 邮件 | Email |
| sms, phone, 电话, 短信 | Phone |
| photo, image, 图片, 照片 | Photography |
| video, 视频 | Video |
| AI, machine learning, 机器学习, NLP, OCR | Machine Learning |
| translate, 翻译, dictionary, 词典 | Dictionaries |
| validate, 验证, email check | Data Validation |
| shorten, 短链接, URL | URL Shorteners |
| storage, 云存储, file, 文件 | Cloud Storage & File Sharing |
| calendar, 日历, holiday, 节假日 | Calendar |
| government, 政府, 公共数据 | Government |
| environment, 环境, 空气质量, pollution | Environment |
| security, 安全, malware, 恶意软件 | Security, Anti-Malware |
| track, 物流, 快递, shipping | Tracking |
| transport, 交通, flight, 航班, train, 火车 | Transportation |
| car, 汽车, vehicle | Vehicle |
| shop, 购物, product, 商品 | Shopping |
| social, 社交, twitter, reddit | Social |
| dev, 开发, github, CI/CD | Development, Continuous Integration |
| text, 文本分析, sentiment, 情感分析 | Text Analysis |
| science, 科学, math, 数学 | Science & Math |
| test, 测试数据, mock, fake | Test Data |
| personality, 名言, quote, joke, 笑话 | Personality |
| art, design, 艺术, 设计 | Art & Design |
| document, 文档, PDF, 生产力 | Documents & Productivity |
| patent, 专利 | Patent |
| event, 活动, 会议 | Events |
| open data, 开放数据 | Open Data |
| open source, 开源 | Open Source Projects |
| auth, 认证, OAuth, login | Authentication & Authorization |
| blockchain, 区块链 | Blockchain |
| business, 商业, company | Business |
| programming, 编程, code | Programming |

## 输出格式模板

### 单个推荐

```
**[API 名称](链接)**
- 简介: {Description}
- 认证: {Auth 方式}
- HTTPS: {Yes/No}
- CORS: {Yes/No/Unknown}
- 推荐理由: {简要说明为何适合用户需求}
```

### 多选对比表

| API | 简介 | 认证 | HTTPS | CORS | 推荐理由 |
| --- | --- | --- | --- | --- | --- |
| [名称](链接) | ... | ... | ... | ... | ... |

## 数据同步

数据来自上游仓库的 README.md，通过 `scripts/split_readme.py` 拆分生成。

更新步骤：
```bash
python3 scripts/split_readme.py
```

脚本支持的参数：
- `--input FILE` — 使用本地 README 文件
- `--dry-run` — 预览模式，不写入文件

脚本会自动更新本文件中的分类索引表（API 数量和同步日期）。
