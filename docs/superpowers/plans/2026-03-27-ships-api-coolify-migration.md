# Ships API Coolify Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a new Next.js API server on Coolify that scrapes ZSG ship data daily via cron job and serves it from a JSON file cache, replacing the Vercel serverless setup.

**Architecture:** A minimal Next.js app with two routes (`GET /ships`, `POST /ships/refresh`). A persistent volume holds `ships.json`. A Coolify cron job calls `/ships/refresh` at 03:00 Swiss time to pre-fill the cache — no user ever triggers scraping.

**Tech Stack:** Next.js 14 (App Router), TypeScript, puppeteer-core, cheerio, system Chromium (Debian slim), Jest

---

## File Map

**New repo: `next-wave-api` (separate GitHub repo)**

| File | Action | Purpose |
|---|---|---|
| `app/ships/route.ts` | Create | GET /ships — reads ships.json |
| `app/ships/refresh/route.ts` | Create | POST /ships/refresh — scrapes + writes ships.json |
| `lib/types.ts` | Create | Shared TypeScript interfaces |
| `lib/cache.ts` | Create | Read/write ships.json on disk |
| `lib/scraper.ts` | Create | Puppeteer + Cheerio scraping logic |
| `__tests__/cache.test.ts` | Create | Tests for cache read/write |
| `__tests__/scraper.test.ts` | Create | Tests for HTML parsing |
| `Dockerfile` | Create | Node 20 slim + system Chromium |
| `next.config.ts` | Create | Standalone output mode |
| `package.json` | Create | Dependencies |

**Existing iOS repo: `Next-Wave`**

| File | Action | Purpose |
|---|---|---|
| `Next Wave/API/VesselAPI.swift` | Modify | Update baseURL |

---

## Task 1: Create GitHub Repo and Initialize Next.js Project

**Files:**
- Create: `package.json`
- Create: `tsconfig.json`
- Create: `next.config.ts`

- [ ] **Step 1: Create new GitHub repo**

Go to github.com → New repository → Name: `next-wave-api` → Private → No README → Create.

- [ ] **Step 2: Clone and initialize Next.js project**

```bash
git clone git@github.com:<your-username>/next-wave-api.git
cd next-wave-api
npx create-next-app@14 . --typescript --app --no-src-dir --no-tailwind --no-eslint --import-alias "@/*"
```

When prompted, accept defaults. This creates the base structure.

- [ ] **Step 3: Remove boilerplate files**

```bash
rm -rf app/page.tsx app/layout.tsx app/globals.css public/
```

- [ ] **Step 4: Install dependencies**

```bash
npm install puppeteer-core cheerio
npm install --save-dev @types/cheerio jest @types/jest ts-jest
```

- [ ] **Step 5: Configure next.config.ts for standalone output**

Replace the contents of `next.config.ts` with:

```typescript
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  output: 'standalone',
}

export default nextConfig
```

- [ ] **Step 6: Configure Jest**

Add to `package.json` (merge with existing scripts section):

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "test": "jest"
  },
  "jest": {
    "preset": "ts-jest",
    "testEnvironment": "node",
    "testMatch": ["**/__tests__/**/*.test.ts"]
  }
}
```

- [ ] **Step 7: Create app directory structure**

```bash
mkdir -p app/ships/refresh lib __tests__
```

- [ ] **Step 8: Initial commit**

```bash
git add .
git commit -m "chore: initialize Next.js project for ships API"
```

---

## Task 2: Shared Types

**Files:**
- Create: `lib/types.ts`

- [ ] **Step 1: Create lib/types.ts**

```typescript
export interface ShipRoute {
  shipName: string
  courseNumber: string
}

export interface DailyDeployment {
  date: string
  routes: ShipRoute[]
}

export interface ShipsCache {
  dailyDeployments: DailyDeployment[]
  lastUpdated: string
  debug: {
    daysProcessed: number
    firstDay: string
    lastDay: string
    processedDates: string[]
    swissTime: string
    detailedStats: Array<{
      date: string
      routesFound: number
      shipsFound: number
      htmlLength: number
    }>
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/types.ts
git commit -m "feat: add shared TypeScript types"
```

---

## Task 3: Cache Module

**Files:**
- Create: `lib/cache.ts`
- Create: `__tests__/cache.test.ts`

- [ ] **Step 1: Write the failing test**

Create `__tests__/cache.test.ts`:

```typescript
import fs from 'fs'
import path from 'path'
import os from 'os'

// Point cache at a temp file for tests
const tmpFile = path.join(os.tmpdir(), `ships-test-${Date.now()}.json`)
process.env.CACHE_PATH = tmpFile

// Import after setting env var
import { readCache, writeCache } from '../lib/cache'
import type { ShipsCache } from '../lib/types'

const sampleCache: ShipsCache = {
  dailyDeployments: [
    { date: '2026-03-27', routes: [{ shipName: 'Stadt Zürich', courseNumber: '1' }] }
  ],
  lastUpdated: '2026-03-27T03:00:00.000Z',
  debug: {
    daysProcessed: 1,
    firstDay: '2026-03-27',
    lastDay: '2026-03-27',
    processedDates: ['2026-03-27'],
    swissTime: '27.3.2026, 04:00:00',
    detailedStats: [{ date: '2026-03-27', routesFound: 1, shipsFound: 1, htmlLength: 5000 }]
  }
}

afterAll(() => {
  if (fs.existsSync(tmpFile)) fs.unlinkSync(tmpFile)
})

test('readCache returns null when file does not exist', () => {
  expect(readCache()).toBeNull()
})

test('writeCache writes JSON to disk, readCache reads it back', () => {
  writeCache(sampleCache)
  const result = readCache()
  expect(result).toEqual(sampleCache)
})

test('readCache returns null when file contains invalid JSON', () => {
  fs.writeFileSync(tmpFile, 'not json', 'utf-8')
  expect(readCache()).toBeNull()
})
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --testPathPattern=cache
```

Expected: FAIL — `lib/cache` module not found

- [ ] **Step 3: Implement lib/cache.ts**

```typescript
import fs from 'fs'
import path from 'path'
import type { ShipsCache } from './types'

function getCachePath(): string {
  return process.env.CACHE_PATH || '/app/cache/ships.json'
}

export function readCache(): ShipsCache | null {
  try {
    const raw = fs.readFileSync(getCachePath(), 'utf-8')
    return JSON.parse(raw) as ShipsCache
  } catch {
    return null
  }
}

export function writeCache(data: ShipsCache): void {
  const filePath = getCachePath()
  fs.mkdirSync(path.dirname(filePath), { recursive: true })
  fs.writeFileSync(filePath, JSON.stringify(data), 'utf-8')
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --testPathPattern=cache
```

Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/cache.ts __tests__/cache.test.ts
git commit -m "feat: add cache module with read/write"
```

---

## Task 4: Scraper Module

**Files:**
- Create: `lib/scraper.ts`
- Create: `__tests__/scraper.test.ts`

- [ ] **Step 1: Write failing tests for the HTML parsing logic**

Create `__tests__/scraper.test.ts`:

```typescript
import { cleanShipName, parseShipsHTML } from '../lib/scraper'

test('cleanShipName removes newlines and trims', () => {
  expect(cleanShipName('  Stadt Zürich\n  ')).toBe('Stadt Zürich')
})

test('cleanShipName strips everything from "Kurs" onwards', () => {
  expect(cleanShipName('Stadt ZürichKurs 1')).toBe('Stadt Zürich')
})

test('parseShipsHTML returns empty array for empty HTML', () => {
  expect(parseShipsHTML('<html></html>')).toEqual([])
})

test('parseShipsHTML extracts ship name and course number', () => {
  const html = `
    <div class="ship">
      <div class="legend"><span class="title">Stadt Zürich</span></div>
      <div class="disposition">
        <div class="cruise"><span>Kurs</span><span>101</span></div>
      </div>
    </div>
  `
  const routes = parseShipsHTML(html)
  expect(routes).toHaveLength(1)
  expect(routes[0].shipName).toBe('Stadt Zürich')
  expect(routes[0].courseNumber).toBe('101')
})

test('parseShipsHTML skips ships with no course number', () => {
  const html = `
    <div class="ship">
      <div class="legend"><span class="title">Stadt Zürich</span></div>
      <div class="disposition">
        <div class="cruise"></div>
      </div>
    </div>
  `
  expect(parseShipsHTML(html)).toHaveLength(0)
})
```

- [ ] **Step 2: Run test to verify it fails**

```bash
npm test -- --testPathPattern=scraper
```

Expected: FAIL — `lib/scraper` module not found

- [ ] **Step 3: Implement lib/scraper.ts**

```typescript
import puppeteer from 'puppeteer-core'
import * as cheerio from 'cheerio'
import type { ShipRoute, DailyDeployment, ShipsCache } from './types'

export function cleanShipName(rawName: string): string {
  const name = rawName.replace(/\n/g, ' ').trim()
  return name.split('Kurs')[0].trim()
}

export function parseShipsHTML(html: string): ShipRoute[] {
  const $ = cheerio.load(html)
  const routes: ShipRoute[] = []

  $('.ship').each((_shipIndex, shipElement) => {
    const $ship = $(shipElement)
    const rawShipName = $ship.find('.legend .title').first().text()
    const shipName = cleanShipName(rawShipName)

    $ship.find('.disposition').each((_dispIndex, routeElement) => {
      const $route = $(routeElement)
      let courseNumber = $route.find('.cruise span:last-child').first().text().trim()
      if (!courseNumber) {
        courseNumber = $route.find('.cruise span').last().text().trim()
      }
      if (courseNumber && shipName) {
        routes.push({ shipName, courseNumber })
      }
    })
  })

  return routes
}

function getCurrentSwissDate(): Date {
  return new Date(new Date().toLocaleString('en-US', { timeZone: 'Europe/Zurich' }))
}

async function fetchDayData(
  dayOffset: number
): Promise<{ routes: ShipRoute[]; stats: { shipsFound: number; htmlLength: number } }> {
  const executablePath =
    process.env.CHROMIUM_PATH ||
    (process.platform === 'darwin' ? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' : '/usr/bin/chromium')

  const browser = await puppeteer.launch({
    executablePath,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
    headless: true,
  })

  try {
    const page = await browser.newPage()
    await page.goto('https://einsatzderschiffe.zsg.ch/', { waitUntil: 'networkidle0', timeout: 30000 })

    for (let i = 0; i < dayOffset; i++) {
      await page.waitForSelector('.add-on.next', { timeout: 10000 })
      await page.click('.add-on.next')
      await new Promise((resolve) => setTimeout(resolve, 2000))
    }

    const htmlContent = await page.content()
    const routes = parseShipsHTML(htmlContent)
    const shipsFound = routes.map((r) => r.shipName).filter((v, i, a) => a.indexOf(v) === i).length

    return { routes, stats: { shipsFound, htmlLength: htmlContent.length } }
  } finally {
    await browser.close()
  }
}

export async function scrapeShips(): Promise<ShipsCache> {
  const today = getCurrentSwissDate()
  const dailyDeployments: DailyDeployment[] = []
  const processedDates: string[] = []
  const detailedStats: ShipsCache['debug']['detailedStats'] = []

  for (let i = 0; i < 3; i++) {
    const targetDate = new Date(today.getTime())
    targetDate.setDate(today.getDate() + i)

    const year = targetDate.getFullYear()
    const month = String(targetDate.getMonth() + 1).padStart(2, '0')
    const day = String(targetDate.getDate()).padStart(2, '0')
    const dateString = `${year}-${month}-${day}`

    try {
      const result = await fetchDayData(i)
      dailyDeployments.push({ date: dateString, routes: result.routes })
      processedDates.push(dateString)
      detailedStats.push({
        date: dateString,
        routesFound: result.routes.length,
        shipsFound: result.stats.shipsFound,
        htmlLength: result.stats.htmlLength,
      })
    } catch (error) {
      console.error(`Error fetching data for ${dateString}:`, error)
      dailyDeployments.push({ date: dateString, routes: [] })
      processedDates.push(dateString)
      detailedStats.push({ date: dateString, routesFound: 0, shipsFound: 0, htmlLength: 0 })
    }
  }

  return {
    dailyDeployments,
    lastUpdated: getCurrentSwissDate().toISOString(),
    debug: {
      daysProcessed: processedDates.length,
      firstDay: processedDates[0] || '',
      lastDay: processedDates[processedDates.length - 1] || '',
      processedDates,
      swissTime: today.toLocaleString('de-CH', { timeZone: 'Europe/Zurich' }),
      detailedStats,
    },
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
npm test -- --testPathPattern=scraper
```

Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/scraper.ts __tests__/scraper.test.ts
git commit -m "feat: add scraper module with HTML parsing"
```

---

## Task 5: GET /ships Route

**Files:**
- Create: `app/ships/route.ts`

- [ ] **Step 1: Implement app/ships/route.ts**

```typescript
import { NextResponse } from 'next/server'
import { readCache } from '@/lib/cache'

export async function GET() {
  const data = readCache()

  if (!data) {
    return NextResponse.json({ error: 'no data yet' }, { status: 503 })
  }

  return NextResponse.json(data)
}
```

- [ ] **Step 2: Smoke test locally**

```bash
npm run dev
# In another terminal:
curl http://localhost:3000/ships
```

Expected: `{"error":"no data yet"}` with HTTP 503 (no cache file exists yet)

- [ ] **Step 3: Commit**

```bash
git add app/ships/route.ts
git commit -m "feat: add GET /ships route"
```

---

## Task 6: POST /ships/refresh Route

**Files:**
- Create: `app/ships/refresh/route.ts`

- [ ] **Step 1: Implement app/ships/refresh/route.ts**

```typescript
import { NextRequest, NextResponse } from 'next/server'
import { scrapeShips } from '@/lib/scraper'
import { writeCache } from '@/lib/cache'

export async function POST(request: NextRequest) {
  const authHeader = request.headers.get('authorization')
  const expected = `Bearer ${process.env.REFRESH_SECRET}`

  if (!process.env.REFRESH_SECRET || authHeader !== expected) {
    return NextResponse.json({ error: 'unauthorized' }, { status: 401 })
  }

  try {
    console.log('Starting ship data scrape...')
    const data = await scrapeShips()
    writeCache(data)
    console.log(`Scrape complete: ${data.dailyDeployments.length} days cached`)

    return NextResponse.json({
      success: true,
      daysScraped: data.dailyDeployments.length,
      lastUpdated: data.lastUpdated,
    })
  } catch (error) {
    console.error('Scrape failed:', error)
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'scrape failed' },
      { status: 500 }
    )
  }
}
```

- [ ] **Step 2: Smoke test the 401 protection locally**

```bash
# Should return 401
curl -X POST http://localhost:3000/ships/refresh
```

Expected: `{"error":"unauthorized"}` with HTTP 401

- [ ] **Step 3: Smoke test with correct token**

```bash
REFRESH_SECRET=testtoken npm run dev
# In another terminal:
curl -X POST http://localhost:3000/ships/refresh \
     -H "Authorization: Bearer testtoken"
```

Expected: scraping starts (will take ~2 min), then returns `{"success":true,...}`

Note: This requires a local Chrome/Chromium to be installed. On macOS, Chrome at `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` is used automatically.

- [ ] **Step 4: Commit**

```bash
git add app/ships/refresh/route.ts
git commit -m "feat: add POST /ships/refresh route with Bearer token auth"
```

---

## Task 7: Dockerfile

**Files:**
- Create: `Dockerfile`
- Create: `.dockerignore`

- [ ] **Step 1: Create Dockerfile**

```dockerfile
FROM node:20-slim AS base

# Install Chromium and dependencies
RUN apt-get update && apt-get install -y \
    chromium \
    fonts-ipafont-gothic \
    fonts-wqy-zenhei \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV CHROMIUM_PATH=/usr/bin/chromium

WORKDIR /app

# Install dependencies
FROM base AS deps
COPY package*.json ./
RUN npm ci

# Build
FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# Production runner
FROM base AS runner
ENV NODE_ENV=production
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"
CMD ["node", "server.js"]
```

- [ ] **Step 2: Create .dockerignore**

```
node_modules
.next
__tests__
*.md
.git
```

- [ ] **Step 3: Build Docker image locally to verify it works**

```bash
docker build -t next-wave-api .
```

Expected: Build succeeds, image created.

- [ ] **Step 4: Test the Docker image locally**

```bash
docker run -p 3000:3000 \
  -e REFRESH_SECRET=testtoken \
  -e CACHE_PATH=/tmp/ships.json \
  next-wave-api
```

```bash
curl http://localhost:3000/ships
```

Expected: `{"error":"no data yet"}` — container running, no cache yet.

- [ ] **Step 5: Commit**

```bash
git add Dockerfile .dockerignore
git commit -m "feat: add Dockerfile with Chromium support"
git push origin main
```

---

## Task 8: Coolify Deployment

- [ ] **Step 1: Create Application resource in Coolify**

In Coolify dashboard:
1. New Resource → Application
2. Source: GitHub → select `next-wave-api` repo
3. Branch: `main`
4. Build Pack: **Dockerfile**
5. Port: `3000`
6. Domain: `api.nextwaveapp.ch`

- [ ] **Step 2: Add environment variables in Coolify**

In the application settings → Environment Variables:

```
REFRESH_SECRET=<generate a random string, e.g. openssl rand -hex 32>
CACHE_PATH=/app/cache/ships.json
```

- [ ] **Step 3: Add persistent volume in Coolify**

In the application settings → Storages:
- Mount path: `/app/cache`
- Size: 100MB (more than enough)

- [ ] **Step 4: Deploy**

Click Deploy in Coolify. Wait for build to finish.

- [ ] **Step 5: Verify deployment**

```bash
curl https://api.nextwaveapp.ch/ships
```

Expected: `{"error":"no data yet"}` with HTTP 503

- [ ] **Step 6: Trigger first manual scrape**

```bash
curl -X POST https://api.nextwaveapp.ch/ships/refresh \
     -H "Authorization: Bearer <your-REFRESH_SECRET>"
```

Expected: Takes ~2 minutes, then returns:
```json
{"success":true,"daysScraped":3,"lastUpdated":"..."}
```

- [ ] **Step 7: Verify data is cached**

```bash
curl https://api.nextwaveapp.ch/ships
```

Expected: Full JSON with `dailyDeployments` array containing 3 days of ship data.

- [ ] **Step 8: Create Cron Job resource in Coolify**

In Coolify dashboard:
1. New Resource → Cron Job (or Scheduled Task)
2. Schedule: `0 3 * * *`
3. Timezone: `Europe/Zurich`
4. Command:
```bash
curl -X POST https://api.nextwaveapp.ch/ships/refresh \
     -H "Authorization: Bearer <your-REFRESH_SECRET>"
```

---

## Task 9: Update iOS App

**Files:**
- Modify: `Next Wave/API/VesselAPI.swift`

- [ ] **Step 1: Update baseURL**

In `Next Wave/API/VesselAPI.swift` line 45, change:

```swift
// Before
private let baseURL = "https://vesseldata-api.vercel.app/api"

// After
private let baseURL = "https://api.nextwaveapp.ch"
```

- [ ] **Step 2: Update URL construction in fetchShipData**

In the same file, find the URL construction (around line 103) and update:

```swift
// Before
guard let url = URL(string: "\(self.baseURL)/ships") else {

// After  — no change needed, this already works correctly
// baseURL is now "https://api.nextwaveapp.ch"
// so "\(baseURL)/ships" = "https://api.nextwaveapp.ch/ships" ✓
```

No further changes needed — the URL construction already appends `/ships` correctly.

- [ ] **Step 3: Build and run iOS app**

In Xcode: Product → Run (⌘R)

Navigate to any departure view that shows ship names. Verify ship names load correctly.

- [ ] **Step 4: Commit**

```bash
git add "Next Wave/API/VesselAPI.swift"
git commit -m "feat: update ships API URL to Coolify server"
```

---

## Task 10: Decommission Vercel (after iOS app is live)

- [ ] **Step 1: Verify new server works in production**

After deploying the iOS app update, monitor for at least one day that the cron job runs successfully and ship names appear correctly.

- [ ] **Step 2: Remove old Vercel API files**

```bash
rm api/ships.ts
npm uninstall @sparticuz/chromium puppeteer-core cheerio @vercel/node
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove Vercel ships API (migrated to Coolify)"
```
