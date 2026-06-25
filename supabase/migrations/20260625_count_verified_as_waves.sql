-- Count verified FoilMotion sessions as waves, alongside app check-ins.
--
-- A "wave" now means: one app check-in OR one verified session. This applies
-- both to the leaderboard ranking and to the user's own total_waves stat
-- (which also drives the milestone badges).
--
-- A verified session is attributed to its "primary" dock (the matched-ride
-- station closest to where the rides happened); the app fills station_id/lake_id
-- on import. So verified rides count both globally AND on the per-station
-- leaderboard for their primary station, in the "My Stations" breakdown, and in
-- the station/lake badges (distinct_stations, max_waves_one_station,
-- distinct_lakes). Sessions without an attributed station (older imports, or
-- tracks with no nearby dock) count only globally.
-- The per-user TIME-bucket / peer / streak stats stay check-in based: a verified
-- session has only one primary station, not the rich per-wave context.

-- 0. Station/lake attribution for verified sessions (filled by the app on import).
alter table public.verified_sessions add column if not exists station_id text;
alter table public.verified_sessions add column if not exists lake_id text;

-- 1. Leaderboard ranking: check-ins + verified sessions per user.
create or replace function public.wave_leaderboard(p_station_id text default null, p_limit int default 50)
returns table (rank int, display_name text, total_waves int, is_me boolean)
language sql
stable
security definer
set search_path = public
as $$
  with checkin_totals as (
    select h.user_id, count(*)::int as total
    from public.wave_history h
    where p_station_id is null or h.station_id = p_station_id
    group by h.user_id
  ),
  verified_totals as (
    -- global: every verified session; per-station: those attributed to it.
    select v.user_id, count(*)::int as total
    from public.verified_sessions v
    where p_station_id is null or v.station_id = p_station_id
    group by v.user_id
  ),
  totals as (
    select user_id, sum(total)::int as total
    from (
      select user_id, total from checkin_totals
      union all
      select user_id, total from verified_totals
    ) u
    group by user_id
  ),
  ranked as (
    select t.user_id, t.total,
           rank() over (order by t.total desc)::int as rnk,
           p.display_name
    from totals t
    left join public.user_profiles p on p.user_id = t.user_id
  )
  -- Show everyone; users without a display name appear as "Anonymous" so the
  -- ranks stay consistent with the rows shown (no phantom gaps).
  (select rnk, coalesce(display_name, 'Anonymous'), total, false
   from ranked
   where user_id <> auth.uid()
   order by rnk asc, total desc
   limit p_limit)
  union all
  (select rnk, coalesce(display_name, 'You'), total, true
   from ranked
   where user_id = auth.uid());
$$;

grant execute on function public.wave_leaderboard(text, int) to authenticated;

-- 2. Per-user stats: total_waves = check-ins + verified sessions. All other
--    metrics stay check-in based (verified sessions carry no station/time data).
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
  -- Station "waves" for station/lake metrics: check-ins + verified (by primary
  -- station). Verified sessions with no attributed station are excluded here but
  -- still counted in total_waves below.
  sv as (
    select station_id, lake_id from public.wave_history where user_id = auth.uid()
    union all
    select station_id, lake_id from public.verified_sessions
      where user_id = auth.uid() and station_id is not null
  ),
  wk  as (select distinct date_trunc('week', local_dt)::date as w from h),
  wko as (select w, row_number() over (order by w) as rn from wk),
  wkg as (select w, (w - (rn * 7)::int)::date as g from wko),
  runs as (select g, count(*)::int as len, max(w) as last_w from wkg group by g)
  select
    ((select count(*) from h)
      + (select count(*) from public.verified_sessions where user_id = auth.uid()))::int,
    (select count(distinct station_id) from sv)::int,
    (select count(distinct lake_id) from sv)::int,
    (select coalesce(max(c),0) from (select count(*) c from sv group by station_id) s)::int,
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
              order by last_w desc limit 1), 0)::int,
    coalesce((select max(len) from runs), 0)::int;
$$;

grant execute on function public.user_wave_stats() to authenticated;

-- 3. "My Stations" breakdown: check-ins + verified sessions per station.
create or replace function public.user_station_counts()
returns table (station_id text, waves int)
language sql
stable
security definer
set search_path = public
as $$
  select station_id, count(*)::int as waves
  from (
    select station_id from public.wave_history where user_id = auth.uid()
    union all
    select station_id from public.verified_sessions
      where user_id = auth.uid() and station_id is not null
  ) s
  group by station_id
  order by waves desc, station_id;
$$;

grant execute on function public.user_station_counts() to authenticated;

-- 4. Verified stats gain a distinct-stations dimension (for verified station
--    badges). Only sessions with an attributed primary station are counted.
-- Return signature changes (extra column), so the old function must be dropped.
drop function if exists public.user_verified_stats();
create or replace function public.user_verified_stats()
returns table (
  session_count int, total_distance_m double precision,
  longest_ride_m double precision, max_speed_ms double precision,
  distinct_stations int
)
language sql stable security definer set search_path = public
as $$
  select
    (select count(*) from public.verified_sessions where user_id = auth.uid())::int,
    coalesce((select sum(total_distance) from public.verified_sessions where user_id = auth.uid()), 0),
    coalesce((select max(longest_ride)   from public.verified_sessions where user_id = auth.uid()), 0),
    coalesce((select max(max_speed)      from public.verified_sessions where user_id = auth.uid()), 0),
    (select count(distinct station_id) from public.verified_sessions
       where user_id = auth.uid() and station_id is not null)::int;
$$;

grant execute on function public.user_verified_stats() to authenticated;
