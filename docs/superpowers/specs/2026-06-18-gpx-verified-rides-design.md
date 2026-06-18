# GPX Verified Foil Sessions & Badges

**Date:** 2026-06-18
**Status:** Design — awaiting implementation plan (revised: session-based, no ferry matching)
**Builds on:** Wave Check-in + Gamification (badges, stats, leaderboards)

## Summary

Let users import a **Foilmotion** GPX session via the iOS Share sheet / "Open in
Next Wave". The app verifies the file is a genuine Foilmotion recording, parses
the track, computes session metrics (longest continuous ride, top speed, total
distance), stores the verified session in Supabase, and awards a set of
**verified badges** shown alongside the existing unverified badges.

The recordings are always **pump-foil sessions** (self-propelled, no ferry wave),
so there is **no ferry-wave matching** — verification simply means "a real
Foilmotion session happened."

## Goals

- Import a `.gpx` into the app via iOS Share (no extra extension target).
- Accept only genuine **Foilmotion** files (creator check).
- Parse GPX robustly (with or without `<extensions>` speed/distance).
- Compute session metrics: longest continuous ride distance, max speed, total distance, duration.
- Persist verified sessions in Supabase (cross-device, idempotent re-import).
- Award verified badges (longest ride, top speed, total distance, session count),
  visually distinct (verified shield) from unverified badges.

## Non-Goals (YAGNI)

- Ferry-wave detection / schedule matching (data is always pump-foil — nothing to match).
- A dedicated Share Extension target (use document-type "Open in").
- Per-wave verified rides (no waves involved).
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
- **`SessionMetrics`** (pure, unit-testable) from `points`:
  `totalDistance` (m), `start/end`, `duration`, `movingTime`, `maxSpeed` (m/s),
  `longestRideDistance` (m, longest continuous run with `speed >= FOIL_SPEED_THRESHOLD`).
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

- **Import summary sheet** after opening a GPX: "Session imported — N km, longest
  ride L m, top speed S km/h", plus any newly unlocked verified badges. Re-importing
  the same file → "Already imported". Non-Foilmotion file → "Only Foilmotion GPX
  files are supported."
- **"My Badges"**: a new **Verified** section (in addition to Earned/Locked) showing
  the verified figures (sessions, total distance, longest ride, top speed) + verified badges.

## 6. Components & boundaries

| Unit | Responsibility |
|---|---|
| `GPXParser` | `.gpx` XML → `GPXSession`. |
| `GeoMath` | haversine distance (m). |
| `SessionMetrics` | pure points → metrics. Unit-tested. |
| `GPXImportCoordinator` | import → parse → Foilmotion check → metrics → upload → summary. |
| `VerifiedRidesAPI` | upsert session + read `user_verified_stats` + `sessionExists`. |
| `VerifiedBadgeCatalog` / evaluator | verified badge definitions + evaluation. |
| `GPXImportSummaryView` | post-import summary. |
| Info.plist + `onOpenURL` | receive the `.gpx` file. |

## 7. Data flow

GPX (Share) → `onOpenURL` (file) → copy to temp → `GPXParser` → Foilmotion check →
`SessionMetrics` → `VerifiedRidesAPI.upload` (`verified_sessions`) → summary sheet →
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
- **`VerifiedBadge`**: threshold boundaries for longest ride / top speed (km/h conversion) / total distance / sessions.
- **SQL**: RLS owner-only; `user_verified_stats` aggregation; upsert idempotency.

## 10. Open implementation decisions (for the plan)

- `FOIL_SPEED_THRESHOLD` value — confirm against real Foilmotion data.
- Verified badge artwork (`badge_distance`, `badge_speed`, `badge_total`, `badge_session`)
  — category-color placeholder until art is added.
- Whether the import summary also fires the existing local badge notification.
