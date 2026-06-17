# Wave Gamification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add badges, a personal stats screen, and global + per-station leaderboards on top of the existing Wave Check-in feature.

**Architecture:** Expired check-ins are archived into a permanent `wave_history` table by the daily cleanup job. Two Postgres `SECURITY DEFINER` functions expose per-user metrics and leaderboards; badge definitions live in Swift and are evaluated client-side from the metrics. New UI is reached from a header icon (global stats + leaderboard) and a station-detail icon (per-station leaderboard).

**Tech Stack:** SwiftUI (iOS), Supabase (Postgres + RLS + pg_cron), `supabase-swift`, swift-testing (`import Testing`).

## Global Constraints

- Local timezone for all date/time bucketing: `Europe/Zurich` (copied verbatim from spec).
- Time-of-day boundaries (local): early bird `< 08:00`; lunch `[11:30, 13:30)`; night owl `>= 19:00`.
- Seasons (meteorological): spring = Mar–May, summer = Jun–Aug, autumn = Sep–Nov, winter = Dec–Feb.
- Social thresholds: Crowd Surfer `peer_count >= 5`; Trendsetter `was_first_checkin AND peer_count >= 3`.
- `wave_history` is readable only by its owner (RLS); leaderboards expose only `(display_name, total_waves)` aggregates via `SECURITY DEFINER`.
- Anonymous users never appear in another user's leaderboard list but always receive their own row (`is_me = true`).
- Migration file naming follows the existing convention `supabase/migrations/YYYYMMDD_<name>.sql`.
- Swift tests use `import Testing` / `@Test` / `#expect` and live in `Next WaveTests/`.

---

## File Structure

**Create:**
- `supabase/migrations/20260617_wave_gamification.sql` — schema, RLS, archive job, RPCs.
- `Next Wave/Models/WaveStats.swift` — `WaveStats` Decodable + `LeaderboardEntry` Decodable.
- `Next Wave/Models/Badge.swift` — `Badge`, `BadgeCategory`, `BadgeCatalog`, `EvaluatedBadge`, `BadgeEvaluator`.
- `Next Wave/API/StatsAPI.swift` — actor calling the two RPCs.
- `Next Wave/ViewModels/StatsStore.swift` — observable store for stats + leaderboard + newly-earned diff.
- `Next Wave/Views/StatsView.swift` — personal stats + badge gallery + own rank.
- `Next Wave/Views/LeaderboardView.swift` — global / per-station ranking list.
- `Next WaveTests/WaveDayContextTests.swift` — first/last-of-day helper tests.
- `Next WaveTests/BadgeEvaluatorTests.swift` — badge evaluation tests.

**Modify:**
- `Next Wave/Models/WaveCheckin.swift` — add first/last-of-day helpers.
- `Next Wave/API/CheckinAPI.swift` — send the new check-in columns.
- `Next Wave/ViewModels/CheckinStore.swift` — thread a `CheckinContext` through `toggle`.
- `Next Wave/Views/DepartureRowView.swift` — build `CheckinContext` at the call sites.
- `Next Wave/ViewModels/AppSettings.swift` — persist `seenBadgeIds`.
- `Next Wave/ContentView.swift:159-177` — header stats icon.
- `Next Wave/Views/DeparturesListView.swift:155-192` — station leaderboard icon.

---

## Task 1: Schema migration (tables, columns, RLS, indexes)

**Files:**
- Create: `supabase/migrations/20260617_wave_gamification.sql`

**Interfaces:**
- Produces: tables `public.wave_history`, `public.user_profiles`; new columns on `public.wave_checkins` (`station_id text`, `lake_id text`, `is_first_of_day boolean`, `is_last_of_day boolean`).

- [ ] **Step 1: Write the schema migration**

Create `supabase/migrations/20260617_wave_gamification.sql`:

```sql
-- Wave gamification: permanent history + stable profile names.

-- 1. New columns on wave_checkins (client-supplied; nullable for legacy rows).
alter table public.wave_checkins add column if not exists station_id text;
alter table public.wave_checkins add column if not exists lake_id text;
alter table public.wave_checkins add column if not exists is_first_of_day boolean not null default false;
alter table public.wave_checkins add column if not exists is_last_of_day  boolean not null default false;

-- 2. Permanent ridden-wave history (one row per user per wave).
create table if not exists public.wave_history (
  user_id           uuid not null references auth.users (id) on delete cascade,
  wave_id           text not null,
  station_id        text not null,
  lake_id           text not null,
  departure_at      timestamptz not null,
  is_first_of_day   boolean not null default false,
  is_last_of_day    boolean not null default false,
  peer_count        int not null default 1,
  was_first_checkin boolean not null default false,
  recorded_at       timestamptz not null default now(),
  primary key (user_id, wave_id)
);

create index if not exists wave_history_user_idx on public.wave_history (user_id);
create index if not exists wave_history_station_idx on public.wave_history (station_id);

alter table public.wave_history enable row level security;

-- Owner-only read; no client writes (only the archive job, which is SECURITY DEFINER).
drop policy if exists "wave_history_select_own" on public.wave_history;
create policy "wave_history_select_own"
  on public.wave_history for select
  using (auth.uid() = user_id);

-- 3. Stable last-known non-anonymous display name per user.
create table if not exists public.user_profiles (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  updated_at   timestamptz not null default now()
);

alter table public.user_profiles enable row level security;

drop policy if exists "user_profiles_select_own" on public.user_profiles;
create policy "user_profiles_select_own"
  on public.user_profiles for select
  using (auth.uid() = user_id);

drop policy if exists "user_profiles_upsert_own" on public.user_profiles;
create policy "user_profiles_upsert_own"
  on public.user_profiles for insert
  with check (auth.uid() = user_id);

drop policy if exists "user_profiles_update_own" on public.user_profiles;
create policy "user_profiles_update_own"
  on public.user_profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
```

- [ ] **Step 2: Apply the migration to your Supabase instance**

Run (whichever you use for this project):
```bash
# Local CLI:
supabase db push
# or paste the file contents into the Supabase SQL editor and run.
```
Expected: no errors; the statements are idempotent (`if not exists` / `drop policy if exists`).

- [ ] **Step 3: Verify schema with a SQL assertion**

Run in the SQL editor / psql:
```sql
do $$
begin
  assert (select count(*) from information_schema.columns
          where table_name='wave_checkins'
            and column_name in ('station_id','lake_id','is_first_of_day','is_last_of_day')) = 4,
         'wave_checkins missing new columns';
  assert to_regclass('public.wave_history') is not null, 'wave_history missing';
  assert to_regclass('public.user_profiles') is not null, 'user_profiles missing';
end $$;
```
Expected: `DO` succeeds with no assertion error.

- [ ] **Step 4: Commit**

```bash
git add "supabase/migrations/20260617_wave_gamification.sql"
git commit -m "feat(db): add wave_history + user_profiles tables and check-in columns"
```

---

## Task 2: Archive-and-cleanup job

**Files:**
- Modify: `supabase/migrations/20260617_wave_gamification.sql`

**Interfaces:**
- Consumes: tables from Task 1.
- Produces: function `public.wave_checkins_archive_and_cleanup()`; replaces the existing `wave_checkins_cleanup` cron job.

- [ ] **Step 1: Append the archive function + reschedule the cron job**

Append to `supabase/migrations/20260617_wave_gamification.sql`:

```sql
-- 4. Archive expired check-ins into wave_history, then delete them.
create or replace function public.wave_checkins_archive_and_cleanup()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  with expired as (
    select c.*,
           count(*)        over (partition by c.wave_id)                as peer_count,
           (c.created_at = min(c.created_at) over (partition by c.wave_id)) as was_first_checkin
    from public.wave_checkins c
    where c.departure_at < now()
      and c.station_id is not null   -- skip legacy rows lacking gamification fields
      and c.lake_id is not null
  )
  insert into public.wave_history
    (user_id, wave_id, station_id, lake_id, departure_at,
     is_first_of_day, is_last_of_day, peer_count, was_first_checkin)
    select user_id, wave_id, station_id, lake_id, departure_at,
           is_first_of_day, is_last_of_day, peer_count, was_first_checkin
    from expired
  on conflict (user_id, wave_id) do nothing;

  delete from public.wave_checkins where departure_at < now();
end;
$$;

-- Replace the old delete-only cron job with the archive job.
do $$
begin
  perform cron.unschedule('wave_checkins_cleanup');
exception when others then
  -- job did not exist yet; ignore
  null;
end $$;

select cron.schedule(
  'wave_checkins_cleanup',
  '0 3 * * *',
  $$select public.wave_checkins_archive_and_cleanup()$$
);
```

- [ ] **Step 2: Apply the migration**

Run: `supabase db push` (or SQL editor).
Expected: no errors.

- [ ] **Step 3: Verify archival + idempotency with a rollback transaction**

Run in psql / SQL editor (uses a real auth user id if present, else a literal uuid):
```sql
begin;
-- two riders on a past wave, one future row that must NOT archive
insert into public.wave_checkins (wave_id, user_id, display_name, departure_at, created_at, station_id, lake_id, is_first_of_day, is_last_of_day)
values
 ('w1','00000000-0000-0000-0000-000000000001','A', now() - interval '1 day', now() - interval '2 day','S1','Zürichsee',true,false),
 ('w1','00000000-0000-0000-0000-000000000002','B', now() - interval '1 day', now() - interval '1 day','S1','Zürichsee',false,false),
 ('w2','00000000-0000-0000-0000-000000000001','A', now() + interval '1 day', now(),'S1','Zürichsee',false,false);

select public.wave_checkins_archive_and_cleanup();
select public.wave_checkins_archive_and_cleanup(); -- run twice: must stay idempotent

-- rider A on w1: peer_count=2, earliest created_at => was_first_checkin=true
select count(*) as hist_rows,
       (select peer_count from public.wave_history where wave_id='w1' and user_id='00000000-0000-0000-0000-000000000001') as a_peer,
       (select was_first_checkin from public.wave_history where wave_id='w1' and user_id='00000000-0000-0000-0000-000000000001') as a_first
from public.wave_history where wave_id in ('w1','w2');
rollback;
```
Expected: `hist_rows = 2` (only the two w1 rows; w2 is future), `a_peer = 2`, `a_first = t`. Running the function twice did not duplicate.

- [ ] **Step 4: Commit**

```bash
git add "supabase/migrations/20260617_wave_gamification.sql"
git commit -m "feat(db): archive expired check-ins into wave_history via cleanup job"
```

---

## Task 3: Stats + leaderboard RPC functions

**Files:**
- Modify: `supabase/migrations/20260617_wave_gamification.sql`

**Interfaces:**
- Produces:
  - `public.user_wave_stats()` → single row with the metric columns below.
  - `public.wave_leaderboard(p_station_id text default null, p_limit int default 50)` → rows `(rank int, display_name text, total_waves int, is_me boolean)`.

- [ ] **Step 1: Append the RPC functions**

Append to `supabase/migrations/20260617_wave_gamification.sql`:

```sql
-- 5. Per-user raw metrics (caller = auth.uid()).
create or replace function public.user_wave_stats()
returns table (
  total_waves int, distinct_stations int, distinct_lakes int, max_waves_one_station int,
  first_of_day_count int, last_of_day_count int,
  early_bird_count int, lunch_count int, night_owl_count int,
  weekend_count int, max_waves_one_day int, has_anniversary boolean,
  solo_count int, max_peer_count int, trendsetter_count int,
  seasons_ridden text[], current_streak_weeks int, longest_streak_weeks int
)
language sql
stable
security definer
set search_path = public
as $$
  with h as (
    select station_id, lake_id, is_first_of_day, is_last_of_day, peer_count, was_first_checkin,
           (departure_at at time zone 'Europe/Zurich') as local_dt
    from public.wave_history
    where user_id = auth.uid()
  ),
  wk  as (select distinct date_trunc('week', local_dt)::date as w from h),
  wko as (select w, row_number() over (order by w) as rn from wk),
  wkg as (select w, (w - (rn * 7))::date as g from wko),
  runs as (select g, count(*)::int as len, max(w) as last_w from wkg group by g)
  select
    (select count(*) from h)::int,
    (select count(distinct station_id) from h)::int,
    (select count(distinct lake_id) from h)::int,
    (select coalesce(max(c),0) from (select count(*) c from h group by station_id) s)::int,
    (select count(*) from h where is_first_of_day)::int,
    (select count(*) from h where is_last_of_day)::int,
    (select count(*) from h where local_dt::time <  time '08:00')::int,
    (select count(*) from h where local_dt::time >= time '11:30' and local_dt::time < time '13:30')::int,
    (select count(*) from h where local_dt::time >= time '19:00')::int,
    (select count(*) from h where extract(isodow from local_dt) in (6,7))::int,
    (select coalesce(max(c),0) from (select count(*) c from h group by local_dt::date) d)::int,
    (select coalesce(exists(
        select 1 from h where local_dt::date >= (select min(local_dt::date) from h) + 365), false))::boolean,
    (select count(*) from h where peer_count = 1)::int,
    (select coalesce(max(peer_count),0) from h)::int,
    (select count(*) from h where was_first_checkin and peer_count >= 3)::int,
    (select coalesce(array_agg(distinct season), array[]::text[]) from (
        select case
                 when extract(month from local_dt) in (3,4,5)   then 'spring'
                 when extract(month from local_dt) in (6,7,8)   then 'summer'
                 when extract(month from local_dt) in (9,10,11) then 'autumn'
                 else 'winter'
               end as season
        from h) ss),
    coalesce((select len from runs
              where last_w >= (date_trunc('week', (now() at time zone 'Europe/Zurich'))::date - 7)
              order by len desc limit 1), 0)::int,
    coalesce((select max(len) from runs), 0)::int;
$$;

grant execute on function public.user_wave_stats() to authenticated;

-- 6. Leaderboard: top named users (excluding caller) + caller's own row.
create or replace function public.wave_leaderboard(p_station_id text default null, p_limit int default 50)
returns table (rank int, display_name text, total_waves int, is_me boolean)
language sql
stable
security definer
set search_path = public
as $$
  with totals as (
    select h.user_id, count(*)::int as total
    from public.wave_history h
    where p_station_id is null or h.station_id = p_station_id
    group by h.user_id
  ),
  ranked as (
    select t.user_id, t.total,
           rank() over (order by t.total desc)::int as rnk,
           p.display_name
    from totals t
    left join public.user_profiles p on p.user_id = t.user_id
  )
  (select rnk, display_name, total, false
   from ranked
   where display_name is not null
     and user_id <> auth.uid()
   order by rnk asc, total desc
   limit p_limit)
  union all
  (select rnk, coalesce(display_name, 'You'), total, true
   from ranked
   where user_id = auth.uid());
$$;

grant execute on function public.wave_leaderboard(text, int) to authenticated;
```

- [ ] **Step 2: Apply the migration**

Run: `supabase db push` (or SQL editor).
Expected: no errors.

- [ ] **Step 3: Verify metrics + leaderboard with a rollback transaction**

Run in psql / SQL editor (sets the caller via a request claim so `auth.uid()` resolves):
```sql
begin;
-- Pretend to be this user for SECURITY DEFINER auth.uid().
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001"}', true);

insert into public.wave_history (user_id, wave_id, station_id, lake_id, departure_at, is_first_of_day, peer_count, was_first_checkin)
values
 ('00000000-0000-0000-0000-000000000001','h1','S1','Zürichsee', timestamptz '2026-01-05 07:30+01', true,  1, true),  -- winter, early bird, solo, first-of-day
 ('00000000-0000-0000-0000-000000000001','h2','S2','Walensee',  timestamptz '2026-06-06 12:00+02', false, 5, false), -- summer, lunch, weekend(Sat), crowd
 ('00000000-0000-0000-0000-000000000001','h3','S1','Zürichsee', timestamptz '2026-06-06 20:00+02', false, 1, false); -- summer, night owl, weekend(Sat), same-day as h2

insert into public.user_profiles (user_id, display_name) values
 ('00000000-0000-0000-0000-000000000001','Pat');

select total_waves, distinct_stations, distinct_lakes, early_bird_count, lunch_count,
       night_owl_count, weekend_count, max_waves_one_day, solo_count, max_peer_count,
       seasons_ridden, first_of_day_count
from public.user_wave_stats();

select * from public.wave_leaderboard(null, 50) order by rank;
select * from public.wave_leaderboard('S1', 50) order by rank;
rollback;
```
Expected (stats row): `total_waves=3`, `distinct_stations=2`, `distinct_lakes=2`, `early_bird_count=1`, `lunch_count=1`, `night_owl_count=1`, `weekend_count=2`, `max_waves_one_day=2`, `solo_count=2`, `max_peer_count=5`, `seasons_ridden={summer,winter}`, `first_of_day_count=1`.
Expected (global leaderboard): one row, `display_name='Pat'`, `total_waves=3`, `is_me=t`. Per-station `S1`: `total_waves=2`, `is_me=t`.

- [ ] **Step 4: Commit**

```bash
git add "supabase/migrations/20260617_wave_gamification.sql"
git commit -m "feat(db): add user_wave_stats and wave_leaderboard RPC functions"
```

---

## Task 4: First/last-of-day helper (Swift, TDD)

**Files:**
- Modify: `Next Wave/Models/WaveCheckin.swift`
- Test: `Next WaveTests/WaveDayContextTests.swift`

**Interfaces:**
- Produces:
  - `WaveCheckin.isFirstOfDay(_ time: Date, amongDepartures times: [Date]) -> Bool`
  - `WaveCheckin.isLastOfDay(_ time: Date, amongDepartures times: [Date]) -> Bool`
  - "first/last of the day" is evaluated in `Europe/Zurich`; among departures on the same local calendar day, the earliest is first and the latest is last.

- [ ] **Step 1: Write the failing tests**

Create `Next WaveTests/WaveDayContextTests.swift`:

```swift
import Testing
import Foundation
@testable import Next_Wave

struct WaveDayContextTests {

    /// Builds a date at a Europe/Zurich wall-clock time.
    private func zurich(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        c.timeZone = TimeZone(identifier: "Europe/Zurich")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    @Test func earliestDepartureIsFirstOfDay() {
        let day = [zurich(2026,6,18,7,0), zurich(2026,6,18,12,0), zurich(2026,6,18,20,0)]
        #expect(WaveCheckin.isFirstOfDay(day[0], amongDepartures: day) == true)
        #expect(WaveCheckin.isFirstOfDay(day[1], amongDepartures: day) == false)
    }

    @Test func latestDepartureIsLastOfDay() {
        let day = [zurich(2026,6,18,7,0), zurich(2026,6,18,12,0), zurich(2026,6,18,20,0)]
        #expect(WaveCheckin.isLastOfDay(day[2], amongDepartures: day) == true)
        #expect(WaveCheckin.isLastOfDay(day[1], amongDepartures: day) == false)
    }

    @Test func onlyConsidersSameLocalDay() {
        // A late wave today + an early wave tomorrow must not make today's late wave "last" vs tomorrow.
        let today = zurich(2026,6,18,20,0)
        let tomorrow = zurich(2026,6,19,7,0)
        #expect(WaveCheckin.isLastOfDay(today, amongDepartures: [today, tomorrow]) == true)
        #expect(WaveCheckin.isFirstOfDay(tomorrow, amongDepartures: [today, tomorrow]) == true)
    }

    @Test func singleDepartureIsBothFirstAndLast() {
        let only = [zurich(2026,6,18,9,0)]
        #expect(WaveCheckin.isFirstOfDay(only[0], amongDepartures: only) == true)
        #expect(WaveCheckin.isLastOfDay(only[0], amongDepartures: only) == true)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -scheme "Next Wave" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:"Next WaveTests/WaveDayContextTests"`
Expected: FAIL — `isFirstOfDay` / `isLastOfDay` are not members of `WaveCheckin`.

- [ ] **Step 3: Implement the helpers**

Append to `Next Wave/Models/WaveCheckin.swift` (before the closing brace of `struct WaveCheckin`, after `makeWaveId`):

```swift
    /// Calendar fixed to Europe/Zurich so "the day" matches the lake's local day.
    private static let zurichCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()

    private static func sameDayDepartures(as time: Date, in times: [Date]) -> [Date] {
        times.filter { zurichCalendar.isDate($0, inSameDayAs: time) }
    }

    /// True if `time` is the earliest departure on its local calendar day among `times`.
    static func isFirstOfDay(_ time: Date, amongDepartures times: [Date]) -> Bool {
        guard let earliest = sameDayDepartures(as: time, in: times).min() else { return false }
        return time == earliest
    }

    /// True if `time` is the latest departure on its local calendar day among `times`.
    static func isLastOfDay(_ time: Date, amongDepartures times: [Date]) -> Bool {
        guard let latest = sameDayDepartures(as: time, in: times).max() else { return false }
        return time == latest
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -scheme "Next Wave" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:"Next WaveTests/WaveDayContextTests"`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add "Next Wave/Models/WaveCheckin.swift" "Next WaveTests/WaveDayContextTests.swift"
git commit -m "feat: add first/last-of-day helpers for wave check-ins"
```

---

## Task 5: Send the new check-in columns

**Files:**
- Modify: `Next Wave/API/CheckinAPI.swift`
- Modify: `Next Wave/ViewModels/CheckinStore.swift`
- Modify: `Next Wave/Views/DepartureRowView.swift`

**Interfaces:**
- Consumes: `WaveCheckin.isFirstOfDay/isLastOfDay` (Task 4); `Lake.Station.id`, `Lake.name`, `scheduleViewModel.nextWaves` ([`WaveEvent`] with `.time`).
- Produces:
  - `struct CheckinContext { let stationId: String; let lakeId: String; let isFirstOfDay: Bool; let isLastOfDay: Bool }` (defined in `CheckinStore.swift`).
  - `CheckinAPI.checkIn(waveId:displayName:departureAt:context:)`.
  - `CheckinStore.toggle(waveId:departureAt:identity:context:)`.

- [ ] **Step 1: Extend `CheckinAPI` to send the new columns + upsert the profile name**

In `Next Wave/API/CheckinAPI.swift`, replace the `CheckinRow` struct (lines 20-25) and the `checkIn` method (lines 38-52) with:

```swift
    private struct CheckinRow: Encodable {
        let wave_id: String
        let user_id: String
        let display_name: String?
        let departure_at: String
        let station_id: String
        let lake_id: String
        let is_first_of_day: Bool
        let is_last_of_day: Bool
    }

    private struct ProfileRow: Encodable {
        let user_id: String
        let display_name: String
    }

    /// Check in (upsert so re-tapping with a new name updates the row).
    func checkIn(waveId: String,
                 displayName: String?,
                 departureAt: Date,
                 context: CheckinContext) async throws {
        let userId = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        let uid = userId.uuidString.lowercased()
        let row = CheckinRow(
            wave_id: waveId,
            user_id: uid,
            display_name: displayName,
            departure_at: Self.iso.string(from: departureAt),
            station_id: context.stationId,
            lake_id: context.lakeId,
            is_first_of_day: context.isFirstOfDay,
            is_last_of_day: context.isLastOfDay
        )
        try await client
            .from("wave_checkins")
            .upsert(row, onConflict: "wave_id,user_id")
            .execute()

        // Persist the latest non-anonymous name for the leaderboard.
        if let name = displayName {
            try? await client
                .from("user_profiles")
                .upsert(ProfileRow(user_id: uid, display_name: name), onConflict: "user_id")
                .execute()
        }
    }
```

- [ ] **Step 2: Add `CheckinContext` and thread it through `CheckinStore.toggle`**

In `Next Wave/ViewModels/CheckinStore.swift`, add the struct above the `CheckinStore` class declaration (after the imports, before `@MainActor`):

```swift
/// Extra gamification fields captured at check-in time.
struct CheckinContext {
    let stationId: String
    let lakeId: String
    let isFirstOfDay: Bool
    let isLastOfDay: Bool
}
```

Then replace the `toggle` method (lines 77-93) with:

```swift
    func toggle(waveId: String, departureAt: Date, identity: CheckinIdentity, context: CheckinContext) async {
        do {
            if mine.contains(waveId) {
                try await CheckinAPI.shared.checkOut(waveId: waveId)
                mine.remove(waveId)
            } else {
                try await CheckinAPI.shared.checkIn(
                    waveId: waveId,
                    displayName: identity.displayName,
                    departureAt: departureAt,
                    context: context)
                mine.insert(waveId)
            }
            await reloadCounts()
        } catch {
            print("⚠️ Checkin toggle failed: \(error)")
        }
    }
```

- [ ] **Step 3: Build the `CheckinContext` at the call sites in `DepartureRowView`**

In `Next Wave/Views/DepartureRowView.swift`, add this computed property right after the `waveId` computed property (after line 26):

```swift
    /// Gamification fields for the current wave, derived from the selected station + the day's schedule.
    private var checkinContext: CheckinContext? {
        guard let station = scheduleViewModel.selectedStation else { return nil }
        let lakeName = lakeStationsViewModel.lakes.first(where: { lake in
            lake.stations.contains(where: { $0.name == station.name })
        })?.name ?? station.name
        let dayTimes = scheduleViewModel.nextWaves.map { $0.time }
        return CheckinContext(
            stationId: station.id,
            lakeId: lakeName,
            isFirstOfDay: WaveCheckin.isFirstOfDay(wave.time, amongDepartures: dayTimes),
            isLastOfDay: WaveCheckin.isLastOfDay(wave.time, amongDepartures: dayTimes)
        )
    }
```

Then replace the `handleCheckinTap` body (lines 28-38) so the context flows through:

```swift
    private func handleCheckinTap(waveId: String) {
        if appSettings.hasCheckinIdentity {
            guard let context = checkinContext else { return }
            Task {
                await checkinStore.toggle(waveId: waveId,
                                          departureAt: wave.time,
                                          identity: appSettings.checkinIdentity,
                                          context: context)
            }
        } else {
            showCheckinIdentitySheet = true
        }
    }
```

And update the identity-sheet `onSave` toggle call (lines 326-337) to pass the context:

```swift
        .sheet(isPresented: $showCheckinIdentitySheet) {
            CheckinIdentitySheet(onSave: {
                if let waveId = waveId, let context = checkinContext {
                    Task {
                        await checkinStore.toggle(waveId: waveId,
                                                  departureAt: wave.time,
                                                  identity: appSettings.checkinIdentity,
                                                  context: context)
                    }
                }
            })
            .environmentObject(appSettings)
        }
```

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild build -scheme "Next Wave" -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: BUILD SUCCEEDED (no other call sites reference the old `toggle`/`checkIn` signatures — confirm with `grep -rn "\.toggle(waveId" "Next Wave"` showing only the two updated call sites).

- [ ] **Step 5: Commit**

```bash
git add "Next Wave/API/CheckinAPI.swift" "Next Wave/ViewModels/CheckinStore.swift" "Next Wave/Views/DepartureRowView.swift"
git commit -m "feat: capture station, lake and first/last-of-day on check-in"
```

---

## Task 6: Stats + leaderboard models and API client

**Files:**
- Create: `Next Wave/Models/WaveStats.swift`
- Create: `Next Wave/API/StatsAPI.swift`

**Interfaces:**
- Consumes: RPCs `user_wave_stats`, `wave_leaderboard` (Task 3); `SupabaseManager.shared` pattern (see `CheckinAPI`).
- Produces:
  - `struct WaveStats: Decodable, Equatable` with all metric properties (camelCase, `CodingKeys` mapping to snake_case).
  - `struct LeaderboardEntry: Decodable, Identifiable, Equatable` (`rank`, `displayName`, `totalWaves`, `isMe`).
  - `actor StatsAPI { func stats() async throws -> WaveStats; func leaderboard(stationId: String?, limit: Int) async throws -> [LeaderboardEntry] }`.

- [ ] **Step 1: Create the models**

Create `Next Wave/Models/WaveStats.swift`:

```swift
import Foundation

struct WaveStats: Decodable, Equatable {
    let totalWaves: Int
    let distinctStations: Int
    let distinctLakes: Int
    let maxWavesOneStation: Int
    let firstOfDayCount: Int
    let lastOfDayCount: Int
    let earlyBirdCount: Int
    let lunchCount: Int
    let nightOwlCount: Int
    let weekendCount: Int
    let maxWavesOneDay: Int
    let hasAnniversary: Bool
    let soloCount: Int
    let maxPeerCount: Int
    let trendsetterCount: Int
    let seasonsRidden: [String]
    let currentStreakWeeks: Int
    let longestStreakWeeks: Int

    enum CodingKeys: String, CodingKey {
        case totalWaves = "total_waves"
        case distinctStations = "distinct_stations"
        case distinctLakes = "distinct_lakes"
        case maxWavesOneStation = "max_waves_one_station"
        case firstOfDayCount = "first_of_day_count"
        case lastOfDayCount = "last_of_day_count"
        case earlyBirdCount = "early_bird_count"
        case lunchCount = "lunch_count"
        case nightOwlCount = "night_owl_count"
        case weekendCount = "weekend_count"
        case maxWavesOneDay = "max_waves_one_day"
        case hasAnniversary = "has_anniversary"
        case soloCount = "solo_count"
        case maxPeerCount = "max_peer_count"
        case trendsetterCount = "trendsetter_count"
        case seasonsRidden = "seasons_ridden"
        case currentStreakWeeks = "current_streak_weeks"
        case longestStreakWeeks = "longest_streak_weeks"
    }

    static let empty = WaveStats(
        totalWaves: 0, distinctStations: 0, distinctLakes: 0, maxWavesOneStation: 0,
        firstOfDayCount: 0, lastOfDayCount: 0, earlyBirdCount: 0, lunchCount: 0,
        nightOwlCount: 0, weekendCount: 0, maxWavesOneDay: 0, hasAnniversary: false,
        soloCount: 0, maxPeerCount: 0, trendsetterCount: 0, seasonsRidden: [],
        currentStreakWeeks: 0, longestStreakWeeks: 0)
}

struct LeaderboardEntry: Decodable, Identifiable, Equatable {
    let rank: Int
    let displayName: String
    let totalWaves: Int
    let isMe: Bool

    var id: String { "\(rank)-\(displayName)-\(isMe)" }

    enum CodingKeys: String, CodingKey {
        case rank
        case displayName = "display_name"
        case totalWaves = "total_waves"
        case isMe = "is_me"
    }
}
```

- [ ] **Step 2: Create the API client**

Create `Next Wave/API/StatsAPI.swift`:

```swift
import Foundation
import Supabase

actor StatsAPI {
    static let shared = StatsAPI()
    private init() {}

    private struct LeaderboardParams: Encodable {
        let p_station_id: String?
        let p_limit: Int
    }

    /// The caller's raw gamification metrics. `user_wave_stats()` returns a single row.
    func stats() async throws -> WaveStats {
        _ = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        let rows: [WaveStats] = try await client
            .rpc("user_wave_stats")
            .execute()
            .value
        return rows.first ?? .empty
    }

    /// Global (stationId == nil) or per-station leaderboard, top `limit` named users + own row.
    func leaderboard(stationId: String?, limit: Int = 50) async throws -> [LeaderboardEntry] {
        _ = try await SupabaseManager.shared.ensureSession()
        let client = SupabaseManager.shared.client
        let rows: [LeaderboardEntry] = try await client
            .rpc("wave_leaderboard", params: LeaderboardParams(p_station_id: stationId, p_limit: limit))
            .execute()
            .value
        return rows
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild build -scheme "Next Wave" -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Next Wave/Models/WaveStats.swift" "Next Wave/API/StatsAPI.swift"
git commit -m "feat: add WaveStats/LeaderboardEntry models and StatsAPI client"
```

---

## Task 7: Badge catalog + evaluator (TDD)

**Files:**
- Create: `Next Wave/Models/Badge.swift`
- Test: `Next WaveTests/BadgeEvaluatorTests.swift`

**Interfaces:**
- Consumes: `WaveStats` (Task 6).
- Produces:
  - `enum BadgeCategory: String { case milestone, stations, lakes, loyalty, firstShip, lastShip, timeOfDay, weekend, seasons, sameDay, anniversary, social, streak }`
  - `struct Badge: Identifiable { let id, title, detail, systemImage: String; let category: BadgeCategory; let target: Int; let metric: (WaveStats) -> Int }`
  - `enum BadgeCatalog { static let totalLakeCount: Int; static let all: [Badge] }`
  - `struct EvaluatedBadge: Identifiable { let badge: Badge; let current: Int; var isEarned: Bool; var progressText: String }`
  - `enum BadgeEvaluator { static func evaluate(_:) -> [EvaluatedBadge]; static func newlyEarned(_ stats:, seenIds:) -> [Badge] }`

- [ ] **Step 1: Write the failing tests**

Create `Next WaveTests/BadgeEvaluatorTests.swift`:

```swift
import Testing
import Foundation
@testable import Next_Wave

struct BadgeEvaluatorTests {

    private func stats(total: Int = 0, lakes: Int = 0, early: Int = 0,
                       seasons: [String] = [], anniversary: Bool = false,
                       sameDay: Int = 0, solo: Int = 0, peer: Int = 0) -> WaveStats {
        WaveStats(
            totalWaves: total, distinctStations: 0, distinctLakes: lakes, maxWavesOneStation: 0,
            firstOfDayCount: 0, lastOfDayCount: 0, earlyBirdCount: early, lunchCount: 0,
            nightOwlCount: 0, weekendCount: 0, maxWavesOneDay: sameDay, hasAnniversary: anniversary,
            soloCount: solo, maxPeerCount: peer, trendsetterCount: 0, seasonsRidden: seasons,
            currentStreakWeeks: 0, longestStreakWeeks: 0)
    }

    @Test func firstWaveBadgeUnlocksAtOne() {
        let none = BadgeEvaluator.evaluate(stats(total: 0)).first { $0.badge.id == "first_wave" }!
        let one  = BadgeEvaluator.evaluate(stats(total: 1)).first { $0.badge.id == "first_wave" }!
        #expect(none.isEarned == false)
        #expect(one.isEarned == true)
    }

    @Test func milestoneProgressTextShowsCurrentOverTarget() {
        let e = BadgeEvaluator.evaluate(stats(total: 7)).first { $0.badge.id == "milestone_10" }!
        #expect(e.isEarned == false)
        #expect(e.current == 7)
        #expect(e.progressText == "7/10")
    }

    @Test func fourSeasonsNeedsAllFour() {
        let three = BadgeEvaluator.evaluate(stats(seasons: ["spring","summer","autumn"]))
            .first { $0.badge.id == "four_seasons" }!
        let four  = BadgeEvaluator.evaluate(stats(seasons: ["spring","summer","autumn","winter"]))
            .first { $0.badge.id == "four_seasons" }!
        #expect(three.isEarned == false)
        #expect(four.isEarned == true)
    }

    @Test func crowdSurferNeedsFivePeers() {
        let four = BadgeEvaluator.evaluate(stats(peer: 4)).first { $0.badge.id == "crowd_surfer" }!
        let five = BadgeEvaluator.evaluate(stats(peer: 5)).first { $0.badge.id == "crowd_surfer" }!
        #expect(four.isEarned == false)
        #expect(five.isEarned == true)
    }

    @Test func anniversaryIsBoolean() {
        let no  = BadgeEvaluator.evaluate(stats(anniversary: false)).first { $0.badge.id == "one_year" }!
        let yes = BadgeEvaluator.evaluate(stats(anniversary: true)).first { $0.badge.id == "one_year" }!
        #expect(no.isEarned == false)
        #expect(yes.isEarned == true)
    }

    @Test func newlyEarnedExcludesAlreadySeen() {
        let s = stats(total: 1, early: 1)
        let earnedIds = Set(BadgeEvaluator.evaluate(s).filter { $0.isEarned }.map { $0.badge.id })
        // Already saw everything except "early_bird": only that one is "new".
        let seen = earnedIds.subtracting(["early_bird"])
        let fresh = BadgeEvaluator.newlyEarned(s, seenIds: seen)
        #expect(fresh.map { $0.id } == ["early_bird"])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -scheme "Next Wave" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:"Next WaveTests/BadgeEvaluatorTests"`
Expected: FAIL — `BadgeEvaluator` / `BadgeCatalog` undefined.

- [ ] **Step 3: Implement the catalog + evaluator**

Create `Next Wave/Models/Badge.swift`:

```swift
import Foundation

enum BadgeCategory: String {
    case milestone, stations, lakes, loyalty, firstShip, lastShip
    case timeOfDay, weekend, seasons, sameDay, anniversary, social, streak
}

struct Badge: Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let category: BadgeCategory
    let target: Int
    /// Current progress value for this badge from the user's stats.
    let metric: (WaveStats) -> Int

    func current(_ stats: WaveStats) -> Int { metric(stats) }
    func isEarned(_ stats: WaveStats) -> Bool { metric(stats) >= target }
}

struct EvaluatedBadge: Identifiable {
    let badge: Badge
    let current: Int
    var id: String { badge.id }
    var isEarned: Bool { current >= badge.target }
    var progressText: String { isEarned ? "Done" : "\(current)/\(badge.target)" }
}

enum BadgeCatalog {
    /// Total number of Swiss lakes in the app's data — target for the "all lakes" Swiss Explorer badge.
    /// NOTE: keep in sync with the lakes shipped in the app data (see `LakeStationsViewModel.lakes`).
    static let totalLakeCount = 15

    static let all: [Badge] = {
        func milestone(_ n: Int) -> Badge {
            Badge(id: n == 1 ? "first_wave" : "milestone_\(n)",
                  title: n == 1 ? "First Wave" : "\(n) Waves",
                  detail: n == 1 ? "Caught your first wave." : "Rode \(n) waves in total.",
                  systemImage: "water.waves", category: .milestone, target: n) { $0.totalWaves }
        }
        func seasonBadge(_ key: String, _ title: String, _ icon: String) -> Badge {
            Badge(id: "season_\(key)", title: title, detail: "Rode a wave in \(title.lowercased()).",
                  systemImage: icon, category: .seasons, target: 1) { $0.seasonsRidden.contains(key) ? 1 : 0 }
        }
        return [
            // Milestones
            milestone(1), milestone(10), milestone(25), milestone(50), milestone(100),
            // Distinct stations
            Badge(id: "stations_3", title: "Explorer", detail: "Rode at 3 different stations.",
                  systemImage: "mappin.and.ellipse", category: .stations, target: 3) { $0.distinctStations },
            Badge(id: "stations_5", title: "Wanderer", detail: "Rode at 5 different stations.",
                  systemImage: "mappin.and.ellipse", category: .stations, target: 5) { $0.distinctStations },
            Badge(id: "stations_10", title: "Nomad", detail: "Rode at 10 different stations.",
                  systemImage: "mappin.and.ellipse", category: .stations, target: 10) { $0.distinctStations },
            // Swiss Explorer (distinct lakes)
            Badge(id: "lakes_2", title: "Two Lakes", detail: "Rode on 2 different lakes.",
                  systemImage: "map", category: .lakes, target: 2) { $0.distinctLakes },
            Badge(id: "lakes_3", title: "Swiss Explorer", detail: "Rode on 3 different lakes.",
                  systemImage: "map", category: .lakes, target: 3) { $0.distinctLakes },
            Badge(id: "lakes_all", title: "Swiss Champion", detail: "Rode on every lake in the app.",
                  systemImage: "map.fill", category: .lakes, target: totalLakeCount) { $0.distinctLakes },
            // Loyalty (max waves at one station)
            Badge(id: "regular_10", title: "Regular", detail: "10 waves at a single station.",
                  systemImage: "house", category: .loyalty, target: 10) { $0.maxWavesOneStation },
            Badge(id: "regular_25", title: "Local Legend", detail: "25 waves at a single station.",
                  systemImage: "house.fill", category: .loyalty, target: 25) { $0.maxWavesOneStation },
            // First / last ship of the day
            Badge(id: "first_ship_1", title: "First Ship", detail: "Caught the first ship of the day.",
                  systemImage: "sunrise", category: .firstShip, target: 1) { $0.firstOfDayCount },
            Badge(id: "first_ship_10", title: "Dawn Patrol", detail: "First ship of the day 10 times.",
                  systemImage: "sunrise.fill", category: .firstShip, target: 10) { $0.firstOfDayCount },
            Badge(id: "last_ship_1", title: "Last Ship", detail: "Caught the last ship of the day.",
                  systemImage: "sunset", category: .lastShip, target: 1) { $0.lastOfDayCount },
            Badge(id: "last_ship_10", title: "Closing Time", detail: "Last ship of the day 10 times.",
                  systemImage: "sunset.fill", category: .lastShip, target: 10) { $0.lastOfDayCount },
            // Time of day
            Badge(id: "early_bird", title: "Early Bird", detail: "Rode a wave before 08:00.",
                  systemImage: "alarm", category: .timeOfDay, target: 1) { $0.earlyBirdCount },
            Badge(id: "lunch_ship", title: "Lunch Ship", detail: "Rode a wave between 11:30 and 13:30.",
                  systemImage: "fork.knife", category: .timeOfDay, target: 1) { $0.lunchCount },
            Badge(id: "night_owl", title: "Night Owl", detail: "Rode a wave at or after 19:00.",
                  systemImage: "moon.stars", category: .timeOfDay, target: 1) { $0.nightOwlCount },
            // Weekend
            Badge(id: "weekend_warrior", title: "Weekend Warrior", detail: "10 waves on weekends.",
                  systemImage: "calendar", category: .weekend, target: 10) { $0.weekendCount },
            // Seasons
            seasonBadge("spring", "Spring", "leaf"),
            seasonBadge("summer", "Summer", "sun.max"),
            seasonBadge("autumn", "Autumn", "wind"),
            seasonBadge("winter", "Winter", "snowflake"),
            Badge(id: "four_seasons", title: "Four Seasons", detail: "Rode in all four seasons.",
                  systemImage: "circle.hexagongrid.fill", category: .seasons, target: 4) { $0.seasonsRidden.count },
            // Same day
            Badge(id: "double", title: "Double", detail: "Rode 2 waves in one day.",
                  systemImage: "2.circle", category: .sameDay, target: 2) { $0.maxWavesOneDay },
            Badge(id: "triple", title: "Triple", detail: "Rode 3 waves in one day.",
                  systemImage: "3.circle", category: .sameDay, target: 3) { $0.maxWavesOneDay },
            // Anniversary
            Badge(id: "one_year", title: "One Year", detail: "Rode a wave a year after your first.",
                  systemImage: "birthday.cake", category: .anniversary, target: 1) { $0.hasAnniversary ? 1 : 0 },
            // Social
            Badge(id: "lone_wolf", title: "Lone Wolf", detail: "Rode a wave solo.",
                  systemImage: "person", category: .social, target: 1) { $0.soloCount },
            Badge(id: "crowd_surfer", title: "Crowd Surfer", detail: "Rode a wave with 5+ riders.",
                  systemImage: "person.3.fill", category: .social, target: 5) { $0.maxPeerCount },
            Badge(id: "trendsetter", title: "Trendsetter", detail: "First check-in on a wave 3+ joined.",
                  systemImage: "flame", category: .social, target: 1) { $0.trendsetterCount },
            // Streak
            Badge(id: "streak_3", title: "On a Roll", detail: "3 weeks in a row with a wave.",
                  systemImage: "flame", category: .streak, target: 3) { $0.longestStreakWeeks },
            Badge(id: "streak_6", title: "Unstoppable", detail: "6 weeks in a row with a wave.",
                  systemImage: "flame.fill", category: .streak, target: 6) { $0.longestStreakWeeks },
        ]
    }()
}

enum BadgeEvaluator {
    static func evaluate(_ stats: WaveStats) -> [EvaluatedBadge] {
        BadgeCatalog.all.map { EvaluatedBadge(badge: $0, current: $0.current(stats)) }
    }

    /// Badges earned now whose ids are not in `seenIds`, in catalog order.
    static func newlyEarned(_ stats: WaveStats, seenIds: Set<String>) -> [Badge] {
        BadgeCatalog.all.filter { $0.isEarned(stats) && !seenIds.contains($0.id) }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -scheme "Next Wave" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:"Next WaveTests/BadgeEvaluatorTests"`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add "Next Wave/Models/Badge.swift" "Next WaveTests/BadgeEvaluatorTests.swift"
git commit -m "feat: add badge catalog and evaluator"
```

---

## Task 8: StatsStore + seen-badges persistence

**Files:**
- Modify: `Next Wave/ViewModels/AppSettings.swift`
- Create: `Next Wave/ViewModels/StatsStore.swift`

**Interfaces:**
- Consumes: `StatsAPI` (Task 6), `BadgeEvaluator` (Task 7), `AppSettings.seenBadgeIds`.
- Produces:
  - `AppSettings.seenBadgeIds: Set<String>` (persisted, with setter).
  - `@MainActor final class StatsStore: ObservableObject` with `@Published stats: WaveStats?`, `@Published leaderboard: [LeaderboardEntry]`, `@Published newlyEarned: [Badge]`, and `func refresh(seenIds:onSeen:) async`, `func loadLeaderboard(stationId:) async`.

- [ ] **Step 1: Add `seenBadgeIds` to `AppSettings`**

In `Next Wave/ViewModels/AppSettings.swift`, add this published property next to the other check-in properties (after `checkinAnonymous`, around line 100):

```swift
    @Published var seenBadgeIds: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(seenBadgeIds), forKey: "seenBadgeIds")
        }
    }
```

And initialize it in `init()` next to the other check-in loads (after `checkinAnonymous`, around line 183):

```swift
        let savedBadgeIds = UserDefaults.standard.array(forKey: "seenBadgeIds") as? [String] ?? []
        self.seenBadgeIds = Set(savedBadgeIds)
```

- [ ] **Step 2: Create `StatsStore`**

Create `Next Wave/ViewModels/StatsStore.swift`:

```swift
import Foundation
import SwiftUI

@MainActor
final class StatsStore: ObservableObject {
    @Published private(set) var stats: WaveStats?
    @Published private(set) var leaderboard: [LeaderboardEntry] = []
    @Published private(set) var newlyEarned: [Badge] = []
    @Published private(set) var loadFailed = false

    /// Load global stats + global leaderboard. `seenIds` drives the newly-earned diff;
    /// `onSeen` is called with the full earned set so the caller can persist it.
    func refresh(seenIds: Set<String>, onSeen: (Set<String>) -> Void) async {
        loadFailed = false
        do {
            let fetched = try await StatsAPI.shared.stats()
            stats = fetched
            newlyEarned = BadgeEvaluator.newlyEarned(fetched, seenIds: seenIds)
            let earnedNow = Set(BadgeEvaluator.evaluate(fetched).filter { $0.isEarned }.map { $0.badge.id })
            onSeen(seenIds.union(earnedNow))
            leaderboard = try await StatsAPI.shared.leaderboard(stationId: nil)
        } catch {
            print("⚠️ Stats refresh failed: \(error)")
            loadFailed = true
        }
    }

    /// Load a leaderboard scoped to one station (used by the station-detail view).
    func loadLeaderboard(stationId: String?) async {
        loadFailed = false
        do {
            leaderboard = try await StatsAPI.shared.leaderboard(stationId: stationId)
        } catch {
            print("⚠️ Leaderboard load failed: \(error)")
            loadFailed = true
        }
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild build -scheme "Next Wave" -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "Next Wave/ViewModels/AppSettings.swift" "Next Wave/ViewModels/StatsStore.swift"
git commit -m "feat: add StatsStore and persist seen badge ids"
```

---

## Task 9: Leaderboard view

**Files:**
- Create: `Next Wave/Views/LeaderboardView.swift`

**Interfaces:**
- Consumes: `StatsStore.loadLeaderboard(stationId:)`, `LeaderboardEntry`.
- Produces: `struct LeaderboardView: View` with `init(stationId: String?, title: String)`.

- [ ] **Step 1: Create the view**

Create `Next Wave/Views/LeaderboardView.swift`:

```swift
import SwiftUI

struct LeaderboardView: View {
    let stationId: String?      // nil == global
    let title: String

    @StateObject private var store = StatsStore()

    var body: some View {
        List {
            if store.leaderboard.isEmpty && !store.loadFailed {
                Text("No rides recorded yet — be the first! 🌊")
                    .foregroundColor(.secondary)
            } else if store.loadFailed {
                Text("Couldn't load the leaderboard. Pull to retry.")
                    .foregroundColor(.red)
            }
            ForEach(store.leaderboard.sorted { $0.rank < $1.rank }) { entry in
                HStack {
                    Text("#\(entry.rank)")
                        .font(.headline.monospacedDigit())
                        .frame(width: 48, alignment: .leading)
                        .foregroundColor(.secondary)
                    Text(entry.displayName)
                        .fontWeight(entry.isMe ? .bold : .regular)
                    Spacer()
                    Label("\(entry.totalWaves)", systemImage: "water.waves")
                        .labelStyle(.titleAndIcon)
                }
                .listRowBackground(entry.isMe ? Color.accentColor.opacity(0.12) : nil)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.loadLeaderboard(stationId: stationId) }
        .task { await store.loadLeaderboard(stationId: stationId) }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme "Next Wave" -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Next Wave/Views/LeaderboardView.swift"
git commit -m "feat: add LeaderboardView (global + per-station)"
```

---

## Task 10: Stats view (personal)

**Files:**
- Create: `Next Wave/Views/StatsView.swift`

**Interfaces:**
- Consumes: `StatsStore.refresh(seenIds:onSeen:)`, `AppSettings.seenBadgeIds`, `BadgeEvaluator.evaluate`, `LeaderboardView`.
- Produces: `struct StatsView: View` (no init args; reads `AppSettings` from environment).

- [ ] **Step 1: Create the view**

Create `Next Wave/Views/StatsView.swift`:

```swift
import SwiftUI

struct StatsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @StateObject private var store = StatsStore()

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero: total waves
                VStack(spacing: 4) {
                    Text("\(store.stats?.totalWaves ?? 0)")
                        .font(.system(size: 56, weight: .bold))
                    Text("waves ridden")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)

                // Newly earned celebration
                if !store.newlyEarned.isEmpty {
                    VStack(spacing: 6) {
                        Text("🎉 New badge\(store.newlyEarned.count > 1 ? "s" : "")!")
                            .font(.headline)
                        Text(store.newlyEarned.map { $0.title }.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Own rank + link to full leaderboard
                NavigationLink(destination: LeaderboardView(stationId: nil, title: "Leaderboard")) {
                    HStack {
                        Label("Leaderboard", systemImage: "trophy")
                        Spacer()
                        if let me = store.leaderboard.first(where: { $0.isMe }) {
                            Text("You — #\(me.rank)").foregroundColor(.secondary)
                        }
                        Image(systemName: "chevron.right").foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                .buttonStyle(.plain)

                // Badge gallery
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(badges) { item in
                        VStack(spacing: 6) {
                            Image(systemName: item.badge.systemImage)
                                .font(.system(size: 30))
                                .foregroundColor(item.isEarned ? .accentColor : .gray.opacity(0.4))
                            Text(item.badge.title)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(item.isEarned ? .primary : .secondary)
                            Text(item.progressText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .opacity(item.isEarned ? 1 : 0.6)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("My Waves")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.refresh(seenIds: appSettings.seenBadgeIds) { updated in
                appSettings.seenBadgeIds = updated
            }
        }
    }

    private var badges: [EvaluatedBadge] {
        BadgeEvaluator.evaluate(store.stats ?? .empty)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme "Next Wave" -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add "Next Wave/Views/StatsView.swift"
git commit -m "feat: add personal StatsView with badge gallery"
```

---

## Task 11: Wire the two entry-point icons

**Files:**
- Modify: `Next Wave/ContentView.swift:159-177`
- Modify: `Next Wave/Views/DeparturesListView.swift:155-192`

**Interfaces:**
- Consumes: `StatsView`, `LeaderboardView`, `appSettings` (already in ContentView's environment).

- [ ] **Step 1: Add the global header stats icon (between Rules and Settings)**

In `Next Wave/ContentView.swift`, in the trailing toolbar `HStack(spacing: 16)` (lines 160-175), insert the stats `NavigationLink` between the Rules `Button` (closes line 167) and the Settings `NavigationLink` (opens line 169):

```swift
                            Button(action: {
                                showingNavigationRules = true
                            }) {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .foregroundColor(.orange)
                                    .padding(.leading, 8)
                            }

                            NavigationLink(destination: StatsView()
                                .environmentObject(appSettings)
                            ) {
                                Image(systemName: "trophy")
                                    .foregroundColor(.accentColor)
                            }

                            NavigationLink(destination: SettingsView()
                                .environmentObject(viewModel)
                            ) {
                                Image(systemName: "gearshape")
                                    .foregroundColor(.accentColor)
                            }
```

> If `appSettings` is not already accessible in `ContentView`, it is provided as an `@EnvironmentObject` higher up (the app injects it). Confirm with `grep -n "appSettings" "Next Wave/ContentView.swift"`; if absent, add `@EnvironmentObject var appSettings: AppSettings` to `ContentView`.

- [ ] **Step 2: Add the station-detail leaderboard icon (left of the favorite heart)**

In `Next Wave/Views/DeparturesListView.swift`, add a state property near the other `@State` declarations (after line 14):

```swift
    @State private var showingStationLeaderboard = false
```

Then, inside the toolbar `HStack(spacing: 12)` (line 157), insert the leaderboard button as the first child of the `if let station = selectedStation` block — immediately before the favorite `Button` (line 159):

```swift
                    if let station = selectedStation {
                        Button(action: { showingStationLeaderboard = true }) {
                            Image(systemName: "trophy")
                                .foregroundColor(.accentColor)
                                .padding(.leading, 8)
                        }

                        Button(action: {
                            if favoritesManager.isFavorite(station) {
                                favoritesManager.removeFavorite(station)
                            } else if favoritesManager.favorites.count >= FavoriteStation.maxFavorites {
                                showingMaxFavoritesAlert = true
                            } else {
                                favoritesManager.addFavorite(station)
                            }
                        }) {
                            Image(systemName: favoritesManager.isFavorite(station) ? "heart.fill" : "heart")
                                .foregroundColor(.accentColor)
                        }
                    }
```

(Note: the `.padding(.leading, 8)` moves from the heart to the new leftmost button.)

Then add the presenting sheet next to the existing `.alert` (after line 192's toolbar block closes, before/with the `.alert` at line 193):

```swift
        .sheet(isPresented: $showingStationLeaderboard) {
            NavigationView {
                LeaderboardView(stationId: selectedStation?.id,
                                title: selectedStation?.name ?? "Leaderboard")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingStationLeaderboard = false }
                        }
                    }
            }
        }
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild build -scheme "Next Wave" -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manually verify the flow in the simulator**

Run the app. Confirm:
1. A trophy icon appears in the home header between the shield (Rules) and gear (Settings); tapping it opens "My Waves" with the badge gallery and a Leaderboard link.
2. Opening a station shows a trophy icon to the left of the heart; tapping it presents that station's leaderboard.

- [ ] **Step 5: Commit**

```bash
git add "Next Wave/ContentView.swift" "Next Wave/Views/DeparturesListView.swift"
git commit -m "feat: add stats + leaderboard entry points to header and station view"
```

---

## Self-Review Notes (already reconciled)

- **Spec coverage:** wave_history + cleanup (Tasks 1–2); user_profiles + stable name (Tasks 1, 5); user_wave_stats + wave_leaderboard with own-row-for-anonymous (Task 3); client-supplied flags incl. lake_id (Tasks 4–5); badge catalog across all categories incl. Swiss Explorer, loyalty, weekend, seasons, same-day, anniversary, social (Task 7); stats screen with badge gallery + own rank + celebration (Tasks 8, 10); global + per-station leaderboard (Task 9); header + station entry icons (Task 11); RLS owner-only on wave_history (Task 1); SQL + Swift tests (Tasks 1–4, 7).
- **Type consistency:** `WaveStats` snake_case `CodingKeys` match the `user_wave_stats()` output columns exactly; `LeaderboardEntry` matches `wave_leaderboard` columns; `CheckinContext` produced in Task 5 is consumed by the same task's call sites; `toggle(...:context:)` and `checkIn(...:context:)` signatures updated together.
- **Open items carried from the spec:** `BadgeCatalog.totalLakeCount` (15) and `lake_id` source must be confirmed against the real lake data (`LakeStationsViewModel.lakes`); social thresholds may be tuned after observing real volumes; exact SF Symbols (`trophy`) can be swapped.
- **Simulator name** in the `xcodebuild` commands (`iPhone 16`) may need adjusting to an installed simulator (`xcrun simctl list devices`).
