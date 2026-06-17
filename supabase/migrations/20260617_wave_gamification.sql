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
              order by last_w desc limit 1), 0)::int,
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
