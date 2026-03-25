# 已知恶意包名单

> 持续更新。来源：PyPI/npm 安全公告、OSV、社区报告。
> 最后更新：2026-03-25

## PyPI

- `litellm` v1.82.8 — 供应链攻击，.pth 文件窃取凭证（2026-03-24）
- `colourfool` — 窃取 Discord token 和浏览器密码
- `daborogern` — 窃取 Discord token
- `daborogenr` — typosquatting daborogern
- `pppackage` — 下载执行远程恶意代码
- `paborogenr` — typosquatting
- `crystalfire` — 窃取 Discord token
- `caborogen` — typosquatting
- `locaborogen` — typosquatting
- `aborogen` — typosquatting
- `reqeusts` — typosquatting requests
- `reequests` — typosquatting requests
- `requsets` — typosquatting requests
- `python-binance-sdk` — typosquatting python-binance
- `openai-api` — typosquatting openai（非官方）
- `flassk` — typosquatting flask
- `djang0` — typosquatting django

## npm

- `event-stream` v3.3.6 — 供应链攻击，窃取比特币钱包
- `ua-parser-js` v0.7.29/0.8.0/1.0.0 — 供应链攻击，挖矿+密码窃取
- `coa` v2.0.3+ — 供应链攻击
- `rc` v1.2.9+ — 供应链攻击
- `colors` v1.4.1+ — 恶意破坏（无限循环）
- `faker` v6.6.6+ — 恶意破坏
- `crossenv` — typosquatting cross-env，窃取 npm token
- `babelcli` — typosquatting babel-cli
- `mongose` — typosquatting mongoose
- `expresss` — typosquatting express
- `loadash` — typosquatting lodash

## 高风险 typosquatting 目标

以下包是 typosquatting 高频目标，安装时需格外注意拼写：

- `requests` / `flask` / `django` / `numpy` / `pandas` / `openai` / `anthropic`
- `express` / `react` / `vue` / `axios` / `lodash` / `mongoose` / `next`
- `langchain` / `litellm` / `boto3` / `fastapi` / `pydantic`
