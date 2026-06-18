-- Server-side badge detection + APNs push wiring.

create extension if not exists pg_net;

-- 1. Parameterized stats (same shape as user_wave_stats(), but for a given user).
create or replace function public.user_wave_stats_for(uid uuid)
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
    where user_id = uid
  ),
  wk  as (select distinct date_trunc('week', local_dt)::date as w from h),
  wko as (select w, row_number() over (order by w) as rn from wk),
  wkg as (select w, (w - (rn * 7)::int)::date as g from wko),
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

-- 2. Persisted earned badges per user.
create table if not exists public.user_badges (
  user_id   uuid not null references auth.users (id) on delete cascade,
  badge_id  text not null,
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);
alter table public.user_badges enable row level security;
drop policy if exists "user_badges_select_own" on public.user_badges;
create policy "user_badges_select_own"
  on public.user_badges for select using (auth.uid() = user_id);

-- 3. Earned badge ids + titles for a user (mirrors the Swift BadgeCatalog thresholds).
create or replace function public.earned_badges_for(uid uuid)
returns table (badge_id text, title text)
language plpgsql
stable
security definer
set search_path = public
as $$
declare s record;
begin
  select * into s from public.user_wave_stats_for(uid);

  if s.total_waves >= 1   then badge_id:='first_wave';    title:='First Wave';      return next; end if;
  if s.total_waves >= 10  then badge_id:='milestone_10';  title:='10 Waves';        return next; end if;
  if s.total_waves >= 25  then badge_id:='milestone_25';  title:='25 Waves';        return next; end if;
  if s.total_waves >= 50  then badge_id:='milestone_50';  title:='50 Waves';        return next; end if;
  if s.total_waves >= 100 then badge_id:='milestone_100'; title:='100 Waves';       return next; end if;

  if s.distinct_stations >= 3  then badge_id:='stations_3';  title:='Explorer'; return next; end if;
  if s.distinct_stations >= 5  then badge_id:='stations_5';  title:='Wanderer'; return next; end if;
  if s.distinct_stations >= 10 then badge_id:='stations_10'; title:='Nomad';    return next; end if;

  if s.distinct_lakes >= 2  then badge_id:='lakes_2';   title:='Two Lakes';      return next; end if;
  if s.distinct_lakes >= 3  then badge_id:='lakes_3';   title:='Swiss Explorer'; return next; end if;
  if s.distinct_lakes >= 15 then badge_id:='lakes_all'; title:='Swiss Champion'; return next; end if;

  if s.max_waves_one_station >= 10 then badge_id:='regular_10'; title:='Regular';      return next; end if;
  if s.max_waves_one_station >= 25 then badge_id:='regular_25'; title:='Local Legend'; return next; end if;

  if s.first_of_day_count >= 1  then badge_id:='first_ship_1';  title:='First Ship';  return next; end if;
  if s.first_of_day_count >= 10 then badge_id:='first_ship_10'; title:='Dawn Patrol'; return next; end if;
  if s.last_of_day_count  >= 1  then badge_id:='last_ship_1';   title:='Last Ship';    return next; end if;
  if s.last_of_day_count  >= 10 then badge_id:='last_ship_10';  title:='Closing Time'; return next; end if;

  if s.early_bird_count >= 1 then badge_id:='early_bird'; title:='Early Bird'; return next; end if;
  if s.lunch_count      >= 1 then badge_id:='lunch_ship'; title:='Lunch Ship'; return next; end if;
  if s.night_owl_count  >= 1 then badge_id:='night_owl';  title:='Night Owl';  return next; end if;

  if s.weekend_count >= 10 then badge_id:='weekend_warrior'; title:='Weekend Warrior'; return next; end if;

  if 'spring' = any(s.seasons_ridden) then badge_id:='season_spring'; title:='Spring'; return next; end if;
  if 'summer' = any(s.seasons_ridden) then badge_id:='season_summer'; title:='Summer'; return next; end if;
  if 'autumn' = any(s.seasons_ridden) then badge_id:='season_autumn'; title:='Autumn'; return next; end if;
  if 'winter' = any(s.seasons_ridden) then badge_id:='season_winter'; title:='Winter'; return next; end if;
  if coalesce(array_length(s.seasons_ridden,1),0) >= 4 then badge_id:='four_seasons'; title:='Four Seasons'; return next; end if;

  if s.max_waves_one_day >= 2 then badge_id:='double'; title:='Double'; return next; end if;
  if s.max_waves_one_day >= 3 then badge_id:='triple'; title:='Triple'; return next; end if;

  if s.has_anniversary then badge_id:='one_year'; title:='One Year'; return next; end if;

  if s.solo_count       >= 1 then badge_id:='lone_wolf';    title:='Lone Wolf';    return next; end if;
  if s.max_peer_count   >= 5 then badge_id:='crowd_surfer'; title:='Crowd Surfer'; return next; end if;
  if s.trendsetter_count>= 1 then badge_id:='trendsetter';  title:='Trendsetter';  return next; end if;

  if s.longest_streak_weeks >= 3 then badge_id:='streak_3'; title:='On a Roll';     return next; end if;
  if s.longest_streak_weeks >= 6 then badge_id:='streak_6'; title:='Unstoppable';   return next; end if;
end $$;

-- 4. Config for the push call (edge function URL + service key). Single row, server-only.
create table if not exists public.push_config (
  edge_url    text,
  service_key text
);
alter table public.push_config enable row level security;  -- no policies: only SECURITY DEFINER funcs read it

-- 5. For each given user: store newly-earned badges and push a notification for them.
create or replace function public.process_new_badges(uids uuid[])
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  u uuid;
  titles text[];
  cfg record;
  title_text text;
  body_text text;
begin
  select edge_url, service_key into cfg from public.push_config limit 1;

  foreach u in array uids loop
    with earned as (select badge_id, title from public.earned_badges_for(u)),
    ins as (
      insert into public.user_badges (user_id, badge_id)
        select u, e.badge_id from earned e
      on conflict (user_id, badge_id) do nothing
      returning badge_id
    )
    select array_agg(e.title order by e.title)
      into titles
      from ins join earned e on e.badge_id = ins.badge_id;

    if titles is null or array_length(titles,1) = 0 then continue; end if;
    if cfg.edge_url is null then continue; end if;  -- not configured yet: badges stored, no push

    if array_length(titles,1) = 1 then
      title_text := 'New badge unlocked! 🏅';
      body_text  := 'You earned the “' || titles[1] || '” badge — tap to see it.';
    else
      title_text := 'New badges unlocked! 🏅';
      body_text  := 'You earned ' || array_length(titles,1) || ' new badges: '
                    || array_to_string(titles[1:3], ', ');
    end if;

    perform net.http_post(
      url     := cfg.edge_url,
      headers := jsonb_build_object('Content-Type','application/json',
                                    'Authorization','Bearer ' || cfg.service_key),
      body    := jsonb_build_object('user_id', u, 'title', title_text, 'body', body_text)
    );
  end loop;
end $$;

-- 6. Rewire the archive job to detect + push new badges for affected users.
create or replace function public.wave_checkins_archive_and_cleanup()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare uids uuid[];
begin
  with expired as (
    select c.*,
           count(*)        over (partition by c.wave_id)                as peer_count,
           (c.created_at = min(c.created_at) over (partition by c.wave_id)) as was_first_checkin
    from public.wave_checkins c
    where c.departure_at < now()
      and c.station_id is not null
      and c.lake_id is not null
  ),
  ins as (
    insert into public.wave_history
      (user_id, wave_id, station_id, lake_id, departure_at,
       is_first_of_day, is_last_of_day, peer_count, was_first_checkin)
      select user_id, wave_id, station_id, lake_id, departure_at,
             is_first_of_day, is_last_of_day, peer_count, was_first_checkin
      from expired
    on conflict (user_id, wave_id) do nothing
    returning user_id
  )
  select array_agg(distinct user_id) into uids from ins;

  delete from public.wave_checkins where departure_at < now();

  if uids is not null then
    perform public.process_new_badges(uids);
  end if;
end $$;

-- 7. Baseline: store currently-earned badges for existing users WITHOUT pushing,
--    so the first real run only notifies about genuinely new badges.
do $$
declare u uuid;
begin
  for u in select distinct user_id from public.wave_history loop
    insert into public.user_badges (user_id, badge_id)
      select u, badge_id from public.earned_badges_for(u)
    on conflict (user_id, badge_id) do nothing;
  end loop;
end $$;
