# GPX Verified Rides & Badges

**Date:** 2026-06-18
**Status:** Design — awaiting implementation plan
**Builds on:** Wave Check-in + Gamification (badges, stats, leaderboards)

## Summary

Let users import a GPX session recorded by **Foilmotion** (via the iOS Share
sheet / "Open in Next Wave"). The app parses the track, auto-detects which ferry
waves the user actually rode (matching the track against the day's schedule by
proximity, time window and motion), computes session metrics (distance, speed,
glide), and stores verified results in Supabase. These power a new set of
**verified badges** (verified ferry waves, longest continuous ride distance, top
speed) shown alongside the existing unverified badges.

## Goals

- Import a `.gpx` file into the app via iOS Share (no extra extension target).
- Parse GPX robustly (with or without `<extensions>` speed/distance).
- Auto-detect verified ferry-wave rides from the track + schedule.
- Compute session metrics (longest continuous ride distance, top speed).
- Persist verified sessions + rides in Supabase (cross-device).
- Add verified badges, visually distinct from unverified ones.

## Non-Goals (YAGNI for v1)

- A dedicated Share Extension target (use document-type "Open in").
- Wake-surf pattern recognition (only proximity + time + motion).
- Glide-**time** badges (dropped per product decision).
- A verified leaderboard (the new tables could feed one later).
- Offline schedule matching (matching + upload require network; parsing works offline).

## Known limitation

Verified data is computed from a client-supplied GPX and uploaded by the client,
so it is **not tamper-proof** (a crafted GPX could fake rides). Accepted for v1.

---

## 1. Import (Approach A — document type)

- **Info.plist:** register `.gpx`:
  - `UTImportedTypeDeclarations`: declare `com.topografix.gpx`, conforming to
    `public.xml`, filename extension `gpx`.
  - `CFBundleDocumentTypes`: role **Viewer**, `LSItemContentTypes = ["com.topografix.gpx", "public.xml"]`.
  This makes Next Wave appear as a target in the Share sheet / Files "Open with".
- **File handling:** extend the existing `.onOpenURL` handler in `NextWaveApp`.
  When `url.isFileURL && url.pathExtension.lowercased() == "gpx"`:
  `url.startAccessingSecurityScopedResource()` → copy to a temp file → stop
  accessing → hand the temp URL to `GPXImportCoordinator`.

## 2. Parsing & Metrics

- **`GPXParser`** (`XMLParser`-based): `.gpx` → `GPXSession`:
  - `metadata: { name, desc, creator, startTime }`
  - `points: [GPXPoint]` where `GPXPoint = { time: Date, lat: Double, lon: Double, ele: Double?, speed: Double?, cumulativeDistance: Double? }`
  - Robust to missing `<extensions>`: if `speed`/`distance` absent, derive them
    from consecutive positions + timestamps (Haversine / Δt).
- **`SessionMetrics`** (pure, no IO → unit-testable), computed from `points`:
  - `totalDistance` (m), `start`, `end`, `duration` (s), `movingTime` (s)
  - `maxSpeed` (m/s)
  - `longestRideDistance` (m): longest **continuous** run of points with
    `speed >= FOIL_SPEED_THRESHOLD`, summing segment distance — the "one go" ride.
  - `boundingBox` (min/max lat/lon) for station candidate search.
- **Tuning constants** (one place, adjustable): `FOIL_SPEED_THRESHOLD = 3.0 m/s`
  (~11 km/h) for "gliding/in motion".

## 3. Wave Matching (`WaveMatcher`)

Orchestrated by `GPXImportCoordinator`:
1. Determine session date (from `metadata.startTime` / first point) + bounding box.
2. **Candidate stations:** from the app's station list, those within
   `STATION_NEARBY_RADIUS = 400 m` of any track point.
3. For each candidate station, fetch that day's ferry departures via
   `TransportAPI.getStationboard(stationId: uic_ref, for: date)`.
4. For each departure at time `T`, mark a **verified ride** when the track has a
   point within `STATION_MATCH_RADIUS = 250 m` of the station inside
   `[T − 120 s, T + 360 s]` with `speed >= FOIL_SPEED_THRESHOLD`.
5. For each match, compute ride metrics from the in-window track segment
   (`ride_distance`, `ride_max_speed`).
6. Build `wave_id` in the existing format `"{stationId}_{departureISO}_{route}"`
   so verified rides align with the check-in/wave system.

## 4. Storage (Supabase — 2 new tables)

```sql
create table public.verified_sessions (
  user_id        uuid not null references auth.users(id) on delete cascade,
  session_key    text not null,        -- dedup hash (creator|startISO|pointCount)
  source         text not null default 'foilmotion',
  start_at       timestamptz not null,
  end_at         timestamptz not null,
  total_distance double precision not null,   -- meters
  duration       int not null,                -- seconds
  moving_time    int not null,                -- seconds
  max_speed      double precision not null,   -- m/s
  longest_ride   double precision not null,   -- meters (longest continuous ride)
  recorded_at    timestamptz not null default now(),
  primary key (user_id, session_key)          -- re-import is idempotent
);

create table public.verified_rides (
  user_id        uuid not null references auth.users(id) on delete cascade,
  wave_id        text not null,
  station_id     text not null,
  departure_at   timestamptz not null,
  session_key    text not null,
  ride_distance  double precision not null,   -- meters
  ride_max_speed double precision not null,   -- m/s
  recorded_at    timestamptz not null default now(),
  primary key (user_id, wave_id)               -- a wave counts once, across sessions
);
```

- **RLS:** owner-only `select`; owner `insert` (`auth.uid() = user_id`). No
  update/delete needed for clients.
- The client upserts after matching (`on conflict do nothing`).
- Separate from `wave_history` (check-in based); existing badges untouched.

## 5. Verified metrics + badges

- **RPC `user_verified_stats()`** (`SECURITY DEFINER`, `auth.uid()`):
  - `verified_waves int` — `count(verified_rides)`
  - `longest_ride_m double precision` — `max(verified_sessions.longest_ride)`
  - `max_speed_ms double precision` — `max(verified_sessions.max_speed)`
  - `session_count int`, `total_distance_m double precision` (sum; for display)
- **`VerifiedStats`** Swift model (Decodable) + **`StatsAPI.verifiedStats()`**.
- **`VerifiedBadgeCatalog`** (reuses `Badge` / `BadgeMedalView`), evaluated from
  `VerifiedStats`. Rendered with a small **verified shield/checkmark** overlay to
  distinguish from unverified badges.

  | Category | Badges (thresholds) |
  |---|---|
  | Verified waves | 1 · 10 · 25 |
  | Longest ride (continuous, m) | 50 · 100 · 250 · 500 · 1000 · 5000 · 10000 |
  | Top speed (km/h; metric stored m/s) | 15 · 20 · 25 · 30 · 35 |

  (Top speed compares `max_speed_ms * 3.6` against the km/h thresholds; 35 = the
  ">30" elite tier. All thresholds adjustable.)

## 6. UI

- **Import summary sheet** (after opening a GPX): "Session imported — N km,
  M verified waves, top speed S km/h", plus any newly unlocked verified badges.
  Re-importing the same file → "Already imported".
- **"My Badges"**: a new **Verified** section (in addition to Earned/Locked) and
  the verified figures (verified waves, longest ride, top speed) in the Stats area.
- No in-app import button needed (entry is the Share sheet); a short hint may be
  added in Settings.

## 7. Components & boundaries

| Unit | Responsibility |
|---|---|
| `GPXParser` | `.gpx` XML → `GPXSession` (points + metadata). No IO beyond reading the file. |
| `SessionMetrics` | pure points → metrics (distance, speed, longest ride). Unit-tested. |
| `WaveMatcher` | track + stations + schedule → `[VerifiedRide]`. |
| `GPXImportCoordinator` | orchestrate import → parse → match → upload → summary. |
| `VerifiedRidesAPI` | upsert sessions/rides + read `user_verified_stats`. |
| `VerifiedBadgeCatalog` / evaluator | verified badge definitions + evaluation. |
| `GPXImportSummaryView` | post-import summary + newly-earned verified badges. |
| Info.plist + `onOpenURL` | receive the `.gpx` file. |

## 8. Data flow

GPX (Share) → `onOpenURL` (file) → copy to temp → `GPXParser` → `SessionMetrics`
→ `WaveMatcher` (fetch schedule for date + nearby stations) → `VerifiedRidesAPI`
upserts `verified_sessions` + `verified_rides` → summary sheet → verified badges
recompute from `user_verified_stats()`.

## 9. Error handling

- Invalid/empty GPX → friendly error, nothing stored.
- No nearby stations / no departures match → session still stored (distance/speed
  count); 0 verified waves.
- Schedule fetch or upload failure → store what succeeded; show a retry hint;
  parsing/metrics work offline, matching + upload need network.
- Re-import (same `session_key`) → idempotent; summary says "already imported".

## 10. Testing

- **`GPXParser`**: the two real Foilmotion files as fixtures → expected point
  counts, metadata, presence of speed/distance; plus a minimal GPX without
  `<extensions>` (derived speed path).
- **`SessionMetrics`**: synthetic points → `totalDistance`, `maxSpeed`,
  `longestRideDistance` incl. threshold boundaries (a point just below/above
  `FOIL_SPEED_THRESHOLD`, a gap splitting two ride segments).
- **`WaveMatcher`**: synthetic track + one station + one departure → match vs
  no-match at the radius/time-window boundaries (149 m vs 151 m; T−120 s vs T−121 s).
- **SQL**: RLS owner-only on the two tables; `user_verified_stats` aggregation;
  upsert idempotency.

## 11. Open implementation decisions (for the plan)

- Exact tuning values (`FOIL_SPEED_THRESHOLD`, radii, time window) — confirm after
  trying real ferry-wave GPX (samples are pumpfoil, no ferry → 0 wave matches).
- Whether the import summary also triggers the existing badge local notification.
- Verified shield styling on `BadgeMedalView` (overlay icon + placement).
