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
