# GPX Verified Foil Sessions & Badges

**Date:** 2026-06-18
**Status:** Implemented (branch `feat/gpx-verified-rides`) — revised: metrics counted **only over ferry-matched (wake-thieving) segments**.
**Builds on:** Wave Check-in + Gamification (badges, stats, leaderboards)

## Summary

Let users import a **Foilmotion** GPX session via the iOS Share sheet / "Open in
Next Wave". The app verifies the file is a genuine Foilmotion recording, parses
the track, reconstructs the trajectories of nearby **Kursschiffe** (scheduled lake
passenger boats) from the timetable, and matches the track against them so that
**only the segments ridden behind a boat (the "wake-thieving" rides) count**.
Metrics (longest ride, top speed, total distance) are aggregated over those matched
segments only, the verified session is stored in Supabase, and a set of **verified
badges** is awarded alongside the existing unverified badges.

Recordings may contain both pump-foil and wake-thieving portions; only the
wake-thieving portions are credited. A purely pump-foil session matches nothing
and yields ~0 metrics (accepted). Verification means "a real Foilmotion session
that includes rides behind a scheduled boat."

## Goals

- Import a `.gpx` into the app via iOS Share (no extra extension target).
- Accept only genuine **Foilmotion** files (creator check).
- Parse GPX robustly (with or without `<extensions>` speed/distance).
- Match the track against scheduled Kursschiff departures/arrivals at nearby docks (≤500 m): each event opens a time window during which the foiler's moving track counts ("wake-thieving" rides).
- Compute metrics over the matched rides only (speed/distance derived from the raw GPS points): longest ride distance, max speed, total distance, plus the count of detected wake-thieving rides.
- Persist verified sessions in Supabase (cross-device, idempotent re-import).
- Award verified badges (longest ride, top speed, total distance, session count),
  visually distinct (verified shield) from unverified badges.

## Non-Goals (YAGNI)

- A dedicated Share Extension target (use document-type "Open in").
- Persisting individual matched-ride / wave records (we keep only aggregate session metrics + ride count).
- A verified leaderboard (the table could feed one later).
- Offline upload (parsing works offline; upload needs network).

## Known limitation

Verified data is computed from a client-supplied GPX and uploaded by the client,
so it is **not tamper-proof**. The Foilmotion creator check is a light authenticity
gate, not real proof. Accepted for v1.

---

## 1. Import (Approach A — document type)

- **Info.plist:** register `.gpx`:
  - `UTImportedTypeDeclarations`: `com.topografix.gpx` conforming to `public.xml`, extension `gpx`.
  - `CFBundleDocumentTypes`: role **Viewer**, `LSItemContentTypes = ["com.topografix.gpx", "public.xml"]`.
- **File handling:** extend the existing `.onOpenURL` handler in `NextWaveApp`. For a
  `.gpx` file URL: start security-scoped access → copy to a temp file → stop access →
  hand to `GPXImportCoordinator`.

## 2. Parsing, Foilmotion check & metrics

- **`GPXParser`** (`XMLParser`): `.gpx` → `GPXSession { metadata, points }`,
  `GPXPoint = { time, lat, lon, ele?, speed?, cumulativeDistance? }`. Robust to
  missing `<extensions>` (derive speed/distance from positions + Δt).
- **Foilmotion gate:** accept only when `metadata.creator` contains "foilmotion"
  (case-insensitive). Otherwise the import is rejected with a clear message.
- **Simplified time-based matching.** The rideable boats are **Kursschiffe**
  (scheduled lake passenger boats, category `BAT`), not ferries. The model: a boat
  departs from / arrives at a dock near the foiler; the foiler launches shortly
  after a departure (chasing the wake) or shortly before an arrival, and rides it.
  We mainly match on **time** — no boat-position interpolation. For every station
  within `dockRadius = 500 m` of any track point, fetch that day's departures
  (`type=departure`, `departureTimestamp`) and arrivals (`type=arrival`,
  `arrivalTimestamp`) → a list of `BoatEvent { time, isArrival, routeNumber }`.
- **`WaveMatcher`** (`Services/WaveMatcher.swift`): each event opens a wake window —
  departure → `[T + chaseLead, T + chaseLead + rideWindow]`; arrival → mirrored
  `[T − chaseLead − rideWindow, T − chaseLead]` — with `chaseLead = 30 s` (a foiler
  is underway ~30 s before catching the wake) and `rideWindow = 180 s`. A track
  point counts when it falls inside any window **and** the foiler is moving
  (`speed >= FOIL_SPEED_THRESHOLD`). Contiguous such points form a `MatchedRide`.
  Speed is derived from the **raw GPS points** (`distance/Δt`); Foilmotion's recorded
  speed is only a fallback when `Δt = 0`. (An earlier boat-trajectory-interpolation
  model was tried but added complexity for little gain; this time+dock heuristic is
  simpler and robust.)
- **`SessionMetrics`** (pure, unit-testable) computed **per matched ride** then
  aggregated by `GPXImportCoordinator`: `totalDistance` = Σ over matched rides,
  `longestRideDistance` = max single matched ride, `maxSpeed` = max over matched
  rides, plus `rideCount` = number of matched (wake-thieving) rides. A session
  with no matched rides reports the `.noWaves` outcome and stores nothing.
- **Constant:** `FOIL_SPEED_THRESHOLD = 3.0 m/s` (~11 km/h), adjustable.

## 3. Storage (Supabase — one table)

```sql
create table public.verified_sessions (
  user_id        uuid not null references auth.users(id) on delete cascade,
  session_key    text not null,          -- dedup hash (creator|startEpoch|pointCount)
  source         text not null default 'foilmotion',
  start_at       timestamptz not null,
  end_at         timestamptz not null,
  total_distance double precision not null,  -- meters
  duration       int not null,               -- seconds
  moving_time    int not null,               -- seconds
  max_speed      double precision not null,  -- m/s
  longest_ride   double precision not null,  -- meters
  recorded_at    timestamptz not null default now(),
  primary key (user_id, session_key)         -- re-import is idempotent
);
```
- **RLS:** owner-only `select`; owner `insert`. Client upserts (`on conflict do nothing`).
- Separate from `wave_history` (check-in based); existing badges untouched.

## 4. Verified metrics + badges

- **RPC `user_verified_stats()`** (`SECURITY DEFINER`, `auth.uid()`):
  - `session_count int` — `count(verified_sessions)`
  - `total_distance_m double precision` — `sum(total_distance)`
  - `longest_ride_m double precision` — `max(longest_ride)`
  - `max_speed_ms double precision` — `max(max_speed)`
- **`VerifiedStats`** Swift model + **`VerifiedRidesAPI.verifiedStats()`**.
- **`VerifiedBadgeCatalog`** (own `VerifiedBadge` type, rendered by `BadgeMedalView`
  with a **verified shield**):

  | Category | Badges (thresholds) |
  |---|---|
  | Longest ride (continuous, m) | 50 · 100 · 250 · 500 · 1000 · 5000 · 10000 |
  | Top speed (km/h; stored m/s) | 15 · 20 · 25 · 30 · 35 |
  | Total distance (m) | 5000 · 25000 · 100000 · 250000 · 500000 |
  | Sessions | 1 · 10 · 25 · 50 · 100 |

  Top speed compares `max_speed_ms * 3.6` against the km/h thresholds. All adjustable.

## 5. UI

- **Import summary sheet** after opening a GPX: wake-thieving ride count, distance
  behind ships, longest ride, top speed. Re-importing the same file → "Already
  imported". A session with no matched rides → **"No ferry waves"** (`.noWaves`).
  Non-Foilmotion file → "Only Foilmotion GPX files are supported."
- **"My Badges"**: verified badges are mixed into the shared **Earned/Locked**
  grids (no separate section), distinguished only by a green verified shield. A
  Foilmotion attribution block (logo + how-to + link) shows the verified figures
  when present.

## 6. Components & boundaries

| Unit | Responsibility |
|---|---|
| `GPXParser` | `.gpx` XML → `GPXSession`. |
| `GeoMath` | haversine distance (m). |
| `SessionMetrics` | pure points → metrics. Unit-tested. |
| `WaveMatcher` / `BoatEvent` | schedule events → wake windows; track → behind-boat (wake-thieving) rides. Unit-tested. |
| `GPXImportCoordinator` | import → parse → Foilmotion check → collect boat events → match rides → aggregate metrics → upload → summary. |
| `VerifiedRidesAPI` | upsert session + read `user_verified_stats` + `sessionExists`. |
| `VerifiedBadgeCatalog` / evaluator | verified badge definitions + evaluation. |
| `GPXImportSummaryView` | post-import summary. |
| Info.plist + `onOpenURL` | receive the `.gpx` file. |

## 7. Data flow

GPX (Share) → `onOpenURL` (file) → copy to temp → `GPXParser` → Foilmotion check →
boat events (`TransportAPI.getStationboard` departures+arrivals at nearby docks) →
`WaveMatcher.matchedRides` (time windows) → aggregate `SessionMetrics` over matched rides →
`VerifiedRidesAPI.upload` (`verified_sessions`) → summary sheet (incl. ride count) →
verified badges recompute from `user_verified_stats()`.

## 8. Error handling

- Invalid/empty GPX → friendly error, nothing stored.
- Not a Foilmotion file → rejected with a clear message.
- Upload failure → show a retry hint (parsing works offline; upload needs network).
- Re-import (same `session_key`) → idempotent; summary says "already imported".

## 9. Testing

- **`GPXParser`**: inline sample (with/without `<extensions>`) → points + metadata.
- **`SessionMetrics`**: synthetic points → `totalDistance`, `maxSpeed`,
  `longestRideDistance` incl. threshold boundaries and a slow point splitting two ride segments.
- **`WaveMatcher`**: moving track inside a departure/arrival window → matched ride;
  no match before the chase lead, outside the window, with no events, or while
  stationary. Speed derived from coordinates.
- **`VerifiedBadge`**: threshold boundaries for longest ride / top speed (km/h conversion) / total distance / sessions.
- **SQL**: RLS owner-only; `user_verified_stats` aggregation; upsert idempotency.

## 10. Open implementation decisions (for the plan)

- `FOIL_SPEED_THRESHOLD` value — confirm against real Foilmotion data.
- Verified badge artwork (`badge_distance`, `badge_speed`, `badge_total`, `badge_session`)
  — category-color placeholder until art is added.
- Whether the import summary also fires the existing local badge notification.
