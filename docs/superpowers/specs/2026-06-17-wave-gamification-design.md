# Wave Gamification — Badges, Stats & Leaderboard

**Date:** 2026-06-17
**Status:** Design — awaiting implementation plan
**Builds on:** Wave Check-in feature (`docs/superpowers/specs/2026-06-16-wave-checkins-design.md`)

## Summary

Add a lightweight gamification layer on top of the existing Wave Check-in feature. Each
user accumulates a permanent record of the waves they have actually ridden, earns
collectible achievement badges, and can compare themselves against others via a global and
per-station leaderboard.

A wave counts as "ridden" only once its departure has passed (`departure_at < now()`) while
the user was still checked in — i.e. confirmed-by-time, not mere intent. Records are
captured at the moment the existing daily cleanup job would otherwise delete them.

## Goals

- Permanently track which waves each user (device) has ridden.
- Show collectible achievement badges across four categories: milestones, distinct
  stations, first/last ship of the day (per station), and weekly streaks.
- Show a personal stats screen (total count, badge gallery with progress, own rank).
- Show a global leaderboard and a per-station leaderboard.
- Reuse the existing anonymous-auth identity and Supabase infrastructure.

## Non-Goals (YAGNI for first release)

- Real-time "badge unlocked!" notifications immediately after a ride (badges surface on the
  next app launch after the daily job runs).
- Badge displayed next to a user's name in the check-in badge/row.
- Cross-device merging of history (identity stays one-per-device, as today).
- Daily streaks (we use weekly streaks).

---

## 1. Data Architecture

### Problem

`wave_checkins` rows are deleted ~1 day after departure by a daily `pg_cron` job. The table
cannot serve as a long-term counter.

### Solution — permanent `wave_history` table, fed by the cleanup job

Instead of simply deleting expired check-ins, the daily job first copies them into a new
permanent table, then deletes them from `wave_checkins` as before.

```sql
create table wave_history (
  user_id        uuid not null,
  wave_id        text not null,
  station_id     text not null,        -- for "distinct stations" + per-station leaderboard
  departure_at   timestamptz not null, -- for streak
  is_first_of_day boolean not null default false, -- first departure of the day at this station
  is_last_of_day  boolean not null default false, -- last departure of the day at this station
  recorded_at    timestamptz default now(),
  primary key (user_id, wave_id)       -- idempotent; a wave is recorded at most once
);

create index wave_history_user_idx on wave_history (user_id);
create index wave_history_station_idx on wave_history (station_id);
```

The `is_first_of_day` / `is_last_of_day` flags **cannot** be derived server-side — Supabase
does not know the ferry schedule. The app (which has the station schedule from the transport
API) computes them at check-in time and stores them on the `wave_checkins` row; the cleanup
job carries them into `wave_history`. "First/last of the day" is scoped **per station** — the
earliest / latest departure at that station on that calendar day.

Updated cleanup job (runs daily, replaces the current delete-only job):

```sql
insert into wave_history (user_id, wave_id, station_id, departure_at, is_first_of_day, is_last_of_day)
  select user_id, wave_id, station_id, departure_at, is_first_of_day, is_last_of_day
  from wave_checkins
  where departure_at < now()
on conflict (user_id, wave_id) do nothing;

delete from wave_checkins where departure_at < now();
```

This guarantees only **actually-elapsed** waves (where the user was still checked in at
cleanup time) enter the history. A user who checks out before departure never appears.

> **Note:** `wave_checkins` does not currently store `station_id` as a dedicated column — it
> is encoded inside `wave_id` (`{stationId}_{departureISO}_{routeNumber}`). The implementation
> plan must either (a) add a `station_id` column to `wave_checkins` populated on check-in, or
> (b) parse it from `wave_id` in the cleanup SQL. Option (a) is preferred for robustness. The
> `is_first_of_day` / `is_last_of_day` columns must also be added to `wave_checkins` and set
> by the client on check-in.

### Rejected alternative — local-only tracking

Counting in `UserDefaults` was rejected: the leaderboard requires server-side aggregation,
and a local counter is lost on reinstall / new device and is trivially manipulable.

### Rejected alternative — counter columns only

A `user_stats` table of plain integer counters cannot retroactively compute streaks,
distinct stations, or first/last-ship badges. The slim raw-row history is required.

### Privacy & RLS

- `wave_history`: RLS `SELECT` restricted to **own rows only** (`auth.uid() = user_id`). No
  client can read another user's movement history.
- `INSERT`/`UPDATE`/`DELETE` on `wave_history`: none for clients — only the cleanup job
  (running with elevated privileges) writes.
- Leaderboards expose only aggregates `(display_name, total_waves)` via a `SECURITY DEFINER`
  function — never raw history rows.

---

## 2. Stats, Badges & Leaderboard (server functions)

### `user_wave_stats()` — caller's raw metrics

`SECURITY DEFINER`, uses `auth.uid()`. Returns a single row:

| field                  | meaning                                             |
|------------------------|-----------------------------------------------------|
| `total_waves`          | count of `wave_history` rows                        |
| `distinct_stations`    | count of distinct `station_id`                      |
| `first_of_day_count`   | rows with `is_first_of_day = true`                  |
| `last_of_day_count`    | rows with `is_last_of_day = true`                   |
| `current_streak_weeks` | consecutive ISO weeks (up to current) with ≥1 wave  |
| `longest_streak_weeks` | longest run of consecutive ISO weeks with ≥1 wave   |

> Streak weeks are computed from `date_trunc('week', departure_at at time zone 'Europe/Zurich')`.

### `wave_leaderboard(p_station_id text default null, p_limit int default 50)`

`SECURITY DEFINER`. Returns the top N users by `total_waves`, descending, **plus** the
caller's own entry/rank so it can always be shown ("Du – #14") even when the caller is
anonymous and excluded from the public list.

- When `p_station_id` is null → global ranking over all `wave_history`.
- When `p_station_id` is set → ranking restricted to that station.
- Public rows: only users with a non-anonymous display name appear. Anonymous users (no name
  ever set) are **not shown to others** but the caller always receives their own row flagged
  `is_me = true` with the true rank computed over all users.

Returned shape (per row): `rank int`, `display_name text`, `total_waves int`, `is_me bool`.

### Stable display name — `user_profiles`

To show a name in the leaderboard we persist the user's most recent **non-anonymous**
display name.

```sql
create table user_profiles (
  user_id      uuid primary key,
  display_name text,              -- last non-anonymous name; null = anonymous-only
  updated_at   timestamptz default now()
);
```

Updated whenever the user checks in with a non-anonymous name (upsert from `CheckinAPI`, or
inside the cleanup job from the latest check-in's `display_name`). RLS: `SELECT` own row;
leaderboard reads it via the `SECURITY DEFINER` function.

### Badge definitions — in the app (Swift)

Badge thresholds, names, icons, and localized copy live in Swift (an enum/struct catalog),
**not** in the DB. This lets us iterate on copy/icons without a migration. The app maps the
numeric metrics from `user_wave_stats()` to earned/unearned badges and per-badge progress.

First-release badge catalog:

| Category    | Badges (thresholds)                                              |
|-------------|------------------------------------------------------------------|
| Milestones  | First Wave · 10 · 25 · 50 · 100 waves                            |
| Stations    | 3 · 5 · 10 distinct stations                                     |
| First ship  | ≥1 first-ship-of-the-day · 10× first-ship-of-the-day            |
| Last ship   | ≥1 last-ship-of-the-day · 10× last-ship-of-the-day              |
| Streak      | 3 · 6 consecutive weeks with ≥1 wave                            |

Each badge defines: id, category, threshold, title (localized), description (localized), SF
Symbol icon, and the metric it reads. Progress for unearned badges shown as `current/target`.

---

## 3. UI

### 3.1 Entry points

**Global header** — `ContentView.swift` toolbar (`navigationBarTrailing`,
[ContentView.swift:159-177](../../../Next%20Wave/ContentView.swift#L159-L177)). Insert a new
trophy/badge button **between** the Rules button (`exclamationmark.shield.fill`, `.orange`)
and the Settings `NavigationLink` (`gearshape`). Proposed icon: `rosette` or `trophy`,
`.accentColor`, matching the existing `HStack(spacing: 16)` style. Opens the **Stats screen**
(personal stats + global leaderboard).

**Station detail** — `DeparturesListView.swift` toolbar
([DeparturesListView.swift:155-192](../../../Next%20Wave/Views/DeparturesListView.swift#L155-L192)).
Insert a new button to the **left of** the favorite heart button (inside the `if let station`
block, before the heart `Button`), matching `HStack(spacing: 12)` / `.accentColor`. Opens the
**per-station leaderboard** for `selectedStation` (passes its `station_id`).

### 3.2 Stats screen (personal)

Opened from the global header. Sections:

1. **Hero:** large total number of waves ridden.
2. **Badge gallery:** earned badges in color; unearned badges greyed out with progress
   (e.g. "7/10 stations"). Tapping a badge shows its title + description.
3. **Own rank:** the caller's global leaderboard position, with a link to the full
   leaderboard view.

### 3.3 Leaderboard view

Reused for both global and per-station (parameterized by optional `station_id`). Shows the
top-N named users; the caller's own entry is always rendered and visually highlighted, even
when not in the public top-N.

### 3.4 Badge-earned feedback

Because `wave_history` is only populated by the daily cleanup job, newly earned badges become
visible on the **next app launch after the job runs** (not instantly after a ride). On opening
the Stats screen, the app compares the currently-earned badge set against a locally-stored
"last seen" set (`UserDefaults`); for newly earned badges it shows a small celebration
animation/highlight, then updates the stored set.

---

## 4. Components & Boundaries

| Unit                          | Responsibility                                                       |
|-------------------------------|----------------------------------------------------------------------|
| `wave_history` (+ migration)  | Permanent ridden-wave records; fed by cleanup job.                   |
| Updated cleanup job           | Copy expired check-ins → history (idempotent), then delete.          |
| `user_profiles` (+ migration) | Stable last-known non-anonymous display name per user.               |
| `user_wave_stats()` RPC       | Caller's raw numeric metrics.                                        |
| `wave_leaderboard()` RPC      | Global / per-station ranking + caller's own row.                     |
| `BadgeCatalog` (Swift)        | Badge definitions, thresholds, icons, localized copy.                |
| `BadgeEvaluator` (Swift)      | Maps metrics → earned/unearned badges + progress.                    |
| `StatsStore` (Swift, Observable) | Fetches stats + leaderboard, exposes to views, tracks "last seen".|
| `StatsView` (SwiftUI)         | Personal stats + badge gallery + own rank.                           |
| `LeaderboardView` (SwiftUI)   | Global / per-station ranking list.                                   |
| Toolbar buttons               | Two new entry-point icons (global header, station detail).           |

## 5. Data Flow

1. User checks in (existing flow). The app computes `is_first_of_day` / `is_last_of_day` from
   the station's schedule and stores them plus `station_id` on the check-in; `user_profiles`
   upserted with the non-anonymous name.
2. Daily cleanup job copies expired check-ins into `wave_history`, then deletes them.
3. User opens Stats screen → `StatsStore` calls `user_wave_stats()` and `wave_leaderboard()`.
4. `BadgeEvaluator` maps metrics to earned badges + progress; `StatsView` renders gallery.
5. Newly earned badges (vs. local "last seen") get a celebration highlight.
6. Station detail → leaderboard icon → `LeaderboardView` with the station's `station_id`.

## 6. Error Handling

- All RPCs are read-only; on network failure the Stats/Leaderboard views show a retry state,
  not a crash. Personal total falls back to "—" until reachable.
- The cleanup job's insert is idempotent (`on conflict do nothing`); a re-run never
  double-counts.
- If `station_id` cannot be derived for a legacy check-in, that row is skipped in the history
  insert (logged), so it simply doesn't count rather than corrupting data.

## 7. Testing

- **SQL:** unit-test the cleanup job idempotency (re-run → same `wave_history`, flags
  preserved), `first_of_day_count` / `last_of_day_count` aggregation, streak computation
  (consecutive vs. gap weeks), and per-station vs. global leaderboard counts. RLS: a user
  cannot read another's `wave_history`.
- **Swift:** test the client-side first/last-of-day determination from a station schedule
  (single departure counts as both; earliest/latest boundaries; day rollover in local time).
- **Swift:** `BadgeEvaluator` tests for each badge threshold (just-below / exactly-at /
  above), progress fractions, and the "newly earned vs. last seen" diff. Mirror the existing
  `CheckinIdentityTests` / `WaveCheckinIdTests` style.
- **Leaderboard:** anonymous caller still receives their own ranked row (`is_me`), and is
  absent from another user's public list.

## 8. Open Implementation Decisions (for the plan)

- `station_id` on `wave_checkins`: add a dedicated column (preferred) vs. parse from
  `wave_id` in SQL.
- Stats entry: confirmed as the **global header** icon (not a new tab) per discussion.
- Exact SF Symbols for the two new toolbar icons (`rosette` vs `trophy` vs `medal`).
