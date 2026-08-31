# Water Level History Chart

**Date:** 2026-08-31
**Status:** Design
**Builds on:** existing current-water-level display (`Lake.waterLevel`, `MeteoNewsAPI`)

## Summary

Add a "Wasserstand" (water level) section to the spot analytics screen
(`WaveAnalyticsView`, opened from the departures list — where "Best Surf
Sessions" is shown), placed above the Best Surf Sessions content. It shows a
40-day line chart of the lake's water level plus three key figures: current
level, 40-day min/max, and the change since yesterday.

There is no public Swiss source for a lake water-level *forecast* (checked:
BAFU/LINDAS only exposes the current reading, not history or forecast; the
Alplakes/Eawag hydrodynamic API has no water-level product at all). This
feature is history-only — no forecast line.

## Goals

- 40-day water level history chart per lake, shown above "Best Surf Sessions"
  in the spot analytics view.
- Three key figures next to the chart: current level, 40-day min/max, delta
  vs. yesterday.
- Build the history ourselves by persisting the water level the app already
  fetches daily — no new external data source, no reverse-engineering
  hydrodaten.admin.ch's undocumented frontend API.

## Non-Goals (YAGNI)

- Forecast (no reliable public source; see Summary).
- Backfilling history from before this feature ships — the chart starts thin
  and fills in over ~40 days.
- Sub-daily resolution — one reading per lake per day is enough for a 40-day
  trend view.
- Validating the proxy's accuracy against the official BAFU figures (the app
  already relies on it elsewhere for the current-value badge).
- An admin UI for correcting/managing stored readings.

## Known limitation

Like `verified_sessions`, rows are written directly by the client after an
anonymous sign-in — not tamper-proof, just the existing trust level the app
already uses elsewhere. Coverage for a given lake/day also depends on *some*
user opening the app for that lake that day; low-traffic lakes may show
occasional gaps in the 40-day window. Accepted for v1.

---

## 1. Storage (Supabase — one table)

```sql
create table public.lake_water_levels (
  lake_name   text not null,
  date        date not null,
  level_m     double precision not null,
  recorded_at timestamptz not null default now(),
  primary key (lake_name, date)
);

create index if not exists lake_water_levels_lake_date_idx
  on public.lake_water_levels (lake_name, date desc);

alter table public.lake_water_levels enable row level security;

-- Public read (same as the existing current-level badge)
create policy "lake_water_levels_select_public"
  on public.lake_water_levels for select
  using (true);

-- Any signed-in client (incl. anonymous) may write — no per-user ownership,
-- this mirrors the app's existing anonymous-write trust level.
create policy "lake_water_levels_insert_authenticated"
  on public.lake_water_levels for insert
  to authenticated
  with check (true);

create policy "lake_water_levels_update_authenticated"
  on public.lake_water_levels for update
  to authenticated
  using (true)
  with check (true);

-- Retention: keep a buffer beyond the 40-day chart window
create extension if not exists pg_cron;
select cron.schedule(
  'lake_water_levels_cleanup',
  '0 3 * * *',
  $$delete from public.lake_water_levels where date < current_date - interval '60 days'$$
);
```

Upsert on `(lake_name, date)` with `on conflict do update` — a later same-day
fetch overwrites that day's row with the freshest reading rather than
duplicating.

## 2. Swift API layer

`WaterLevelHistoryAPI` (actor, follows the `StatsAPI.swift` pattern):

```swift
actor WaterLevelHistoryAPI {
    static let shared = WaterLevelHistoryAPI()

    struct WaterLevelPoint: Codable {
        let date: Date
        let levelM: Double
    }

    func recordLevel(lake: String, levelMeters: Double, date: Date = Date()) async throws
    func getHistory(lake: String, days: Int = 40) async throws -> [WaterLevelPoint]
}
```

- `recordLevel`: `client.from("lake_water_levels").upsert(...)`, matches the
  `ensureSession()` + `try await` pattern used throughout `StatsAPI.swift`.
- `getHistory`: `select` ordered by `date`, filtered to `date >=
  today - days`.

## 3. Write path (piggyback on the existing fetch)

`LakeStationsViewModel`, right after merging `MeteoNewsAPI.shared.getWaterLevels()`
results (around lines 147–159): for each lake with a parsed numeric
`waterLevel`, call `WaterLevelHistoryAPI.shared.recordLevel(lake:levelMeters:)`
as a fire-and-forget `Task` (errors logged, never surfaced to the UI — this is
a background write, not user-facing).

The numeric parse ("405.96 m.ü.M." → `405.96`) reuses the parsing already
written for `calculateWaterLevelDifference` in `Lake.swift` rather than
duplicating it.

To avoid a redundant write on every app foreground, check a small
`UserDefaults` cache ("last lake+date recorded") before calling
`recordLevel` — the DB upsert makes this correct either way; the local check
just saves a network round trip.

## 4. Read path & lake lookup

`WaveAnalyticsView` currently only receives `spotId`/`spotName` (from
`DeparturesListView`, which holds `selectedStation: Lake.Station?` and
`viewModel: LakeStationsViewModel`). `Lake.Station` has no back-reference to
its parent `Lake`, so `DeparturesListView` resolves it —
`viewModel.lakes.first(where: { $0.stations.contains(selectedStation) })` —
and passes the lake name down into `WaveAnalyticsView` alongside the existing
`spotId`/`spotName`.

`WaveAnalyticsViewModel` gains a `loadWaterLevelHistory(lake:)` that calls
`WaterLevelHistoryAPI.shared.getHistory(lake:days: 40)` and publishes the
result for the new section to render.

## 5. UI

New `WaterLevelSectionView`, inserted in `WaveAnalyticsView`'s `ScrollView {
VStack }` before the existing `Text("Best Surf Sessions")` (line 40), shown
regardless of whether `analytics.timeSlots` is empty:

- **Chart:** Swift Charts (`import Charts`) `LineMark` (+ subtle `AreaMark`
  gradient fill) over the up-to-40 daily points, x = date, y = level in
  m.ü.M. The app has no existing Swift Charts usage (its one chart,
  `WaveTimelineChart`, is a hand-drawn hourly timeline for a different job),
  but the deployment target (iOS 17.5 / 18.1) supports it — cleaner than
  hand-rolling axis/point math for a value-over-time trend line.
- **Key figures row:** three small stat tiles — Aktuell, Min/Max (40 Tage),
  Δ seit gestern (colored red/green with an arrow, matching the existing
  `waterLevelDifference` badge convention used in `FavoriteStationTileView` /
  `NearestStationTileView` / `DepartureRowView`).
- **Thin-history state:** with under ~7 days of data, the chart just renders
  the shorter span — no special empty state beyond that.

## 6. Localization

New strings in `Localizable.xcstrings` (de/fr/it/en): section title
("Wasserstand"), key-figure labels ("Aktuell", "Min", "Max", "seit gestern"),
following the string-catalog patterns from the recent i18n commits.

## 7. Components & boundaries

| Unit | Responsibility |
|---|---|
| `lake_water_levels` (SQL) | one row per lake per day, public read, authenticated write, 60-day retention via `pg_cron`. |
| `WaterLevelHistoryAPI` | upsert current reading; read last N days for a lake. |
| `LakeStationsViewModel` (extended) | after fetching current levels, fire-and-forget persist today's reading per lake. |
| `WaveAnalyticsViewModel` (extended) | load 40-day history for the spot's lake. |
| `WaterLevelSectionView` | chart + key-figure tiles. |
| `DeparturesListView` (extended) | resolve `selectedStation` → parent `Lake`, pass its name into `WaveAnalyticsView`. |

## 8. Data flow

App foreground → `LakeStationsViewModel` loads current levels
(`MeteoNewsAPI`) → parses numeric level → `WaterLevelHistoryAPI.recordLevel`
(upsert, fire-and-forget) ⟶ *(separately, on demand)* user opens spot
analytics → `DeparturesListView` resolves the spot's `Lake` →
`WaveAnalyticsViewModel.loadWaterLevelHistory` →
`WaterLevelHistoryAPI.getHistory` (last 40 days) → `WaterLevelSectionView`
renders chart + key figures.

## 9. Error handling

- Write failures (`recordLevel`) are logged only — never surfaced, since this
  is a background best-effort persistence step piggybacking on an existing
  fetch.
- Read failures (`getHistory`) leave the water level section showing nothing
  (or a lightweight inline error), without blocking the rest of
  `WaveAnalyticsView` (Best Surf Sessions must still work if history fails to
  load).
- Missing/unparseable `waterLevel` string for a lake on a given day → skip
  the write for that day (no row), rather than storing a bad value.

## 10. Testing

- **Level-string parsing:** unit test extending whatever already covers
  `calculateWaterLevelDifference` in `Lake.swift`, confirming the reused
  parse path.
- **`WaterLevelHistoryAPI`:** upsert idempotency (same lake+date twice →
  one row, latest value wins) and 40-day read filtering.
- **SQL:** RLS (public select; write requires an authenticated — incl.
  anonymous — session); retention job deletes rows older than 60 days.
- **Manual:** run the app, open a spot's analytics view, confirm the section
  renders above Best Surf Sessions, confirm the chart/key figures match the
  raw rows for that lake in the Supabase table, and confirm the thin-history
  case (a lake with only a few days of rows) still renders sensibly.

## 11. Open implementation decisions (for the plan)

- Exact `WaterLevelPoint` → Swift Charts styling (colors, gradient) — match
  existing chart/badge color conventions during implementation.
- Whether the local "already recorded today" `UserDefaults` check is worth
  the small added state, or whether relying purely on the DB upsert is
  simpler and good enough (§3).
