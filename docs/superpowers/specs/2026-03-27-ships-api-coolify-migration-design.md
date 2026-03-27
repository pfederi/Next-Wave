# Design: Ships API Migration — Vercel → Coolify

**Date:** 2026-03-27
**Status:** Approved

## Overview

Migrate the ship name scraping backend from Vercel (serverless + KV cache) to a self-hosted Next.js app on Coolify. The first user no longer triggers scraping — a daily cron job at 03:00 Swiss time pre-fills a JSON file cache.

## Architecture

```
GitHub Repo (Next.js)
    └── Coolify: Application (api.nextwaveapp.ch)
        ├── GET  /ships          ← reads ships.json
        └── POST /ships/refresh  ← scrapes ZSG, writes ships.json (Bearer Token protected)
        └── Persistent Volume: /app/cache/ships.json

Coolify: Cron Job
    └── 0 3 * * * (03:00 Europe/Zurich)
        curl -X POST https://api.nextwaveapp.ch/ships/refresh \
             -H "Authorization: Bearer $REFRESH_SECRET"

iOS App (VesselAPI.swift)
    └── baseURL: https://api.nextwaveapp.ch
```

## Components

| File | Purpose |
|---|---|
| `app/ships/route.ts` | GET: reads ships.json, returns 503 if no cache yet |
| `app/ships/refresh/route.ts` | POST: validates Bearer Token, triggers scraper, writes cache |
| `lib/scraper.ts` | Puppeteer + Cheerio scraping logic (migrated from api/ships.ts) |
| `lib/cache.ts` | Read/write ships.json from persistent volume |
| `Dockerfile` | Node 20 slim + system Chromium |

## Data Flow

### Happy path
1. 03:00 cron job → `POST /ships/refresh` with Bearer Token
2. `scraper.ts` launches Puppeteer with system Chromium
3. Scrapes `einsatzderschiffe.zsg.ch` for today + 2 days (3 browser sessions)
4. `cache.ts` writes result to `/app/cache/ships.json`
5. iOS App calls `GET /ships` → reads ships.json → returns data instantly

### Error cases

| Situation | Behaviour |
|---|---|
| ships.json does not exist yet | GET returns 503 `{"error": "no data yet"}` |
| Scraping fails | Old ships.json preserved, cron job returns error |
| Refresh called without/wrong token | 401 Unauthorized |
| ZSG website down | Cron job fails, cache unchanged, previous data still served |

**No on-demand scraping fallback on GET** — cache is exclusively filled by the cron job.

## Dockerfile

System Chromium replaces `@sparticuz/chromium` (which was Lambda-specific):

```dockerfile
FROM node:20-slim
RUN apt-get update && apt-get install -y chromium --no-install-recommends
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV CHROMIUM_PATH=/usr/bin/chromium
```

Puppeteer is configured to use `process.env.CHROMIUM_PATH` as `executablePath`.

## Environment Variables

| Variable | Description |
|---|---|
| `REFRESH_SECRET` | Random secret token for protecting /ships/refresh |
| `CACHE_PATH` | Path to cache file, default `/app/cache/ships.json` |

## Coolify Setup

1. **Application** — GitHub repo, Dockerfile build, domain `api.nextwaveapp.ch`
2. **Persistent Volume** — mounted at `/app/cache`me mount, 
3. **Cron Job Resource** — `0 3 * * *`, calls refresh endpoint with Bearer Token

## iOS App Change

Single change in `Next Wave/API/VesselAPI.swift`:

```swift
// Before
private let baseURL = "https://vesseldata-api.vercel.app/api"

// After
private let baseURL = "https://api.nextwaveapp.ch"
```

All existing URL construction (`\(baseURL)/ships`) works unchanged since `/api` prefix is dropped.

## Out of Scope

- Frontend / dashboard for the API
- Authentication beyond the single Bearer Token for refresh
- Multiple cache formats or versioning
