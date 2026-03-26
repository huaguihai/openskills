# Known Malicious Packages List

> Continuously updated. Sources: PyPI/npm security advisories, OSV, community reports.
> Last updated: 2026-03-25

## PyPI

- `litellm` v1.82.8 — supply chain attack, .pth file stealing credentials (2026-03-24)
- `colourfool` — steals Discord tokens and browser passwords
- `daborogern` — steals Discord tokens
- `daborogenr` — typosquatting daborogern
- `pppackage` — downloads and executes remote malicious code
- `paborogenr` — typosquatting
- `crystalfire` — steals Discord tokens
- `caborogen` — typosquatting
- `locaborogen` — typosquatting
- `aborogen` — typosquatting
- `reqeusts` — typosquatting requests
- `reequests` — typosquatting requests
- `requsets` — typosquatting requests
- `python-binance-sdk` — typosquatting python-binance
- `openai-api` — typosquatting openai (unofficial)
- `flassk` — typosquatting flask
- `djang0` — typosquatting django

## npm

- `event-stream` v3.3.6 — supply chain attack, stealing Bitcoin wallets
- `ua-parser-js` v0.7.29/0.8.0/1.0.0 — supply chain attack, cryptomining + password theft
- `coa` v2.0.3+ — supply chain attack
- `rc` v1.2.9+ — supply chain attack
- `colors` v1.4.1+ — malicious sabotage (infinite loop)
- `faker` v6.6.6+ — malicious sabotage
- `crossenv` — typosquatting cross-env, stealing npm tokens
- `babelcli` — typosquatting babel-cli
- `mongose` — typosquatting mongoose
- `expresss` — typosquatting express
- `loadash` — typosquatting lodash

## High-Risk Typosquatting Targets

The following packages are frequent typosquatting targets; pay extra attention to spelling when installing:

- `requests` / `flask` / `django` / `numpy` / `pandas` / `openai` / `anthropic`
- `express` / `react` / `vue` / `axios` / `lodash` / `mongoose` / `next`
- `langchain` / `litellm` / `boto3` / `fastapi` / `pydantic`
