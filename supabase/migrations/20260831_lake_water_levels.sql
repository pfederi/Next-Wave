create table if not exists public.lake_water_levels (
  id          bigint generated always as identity primary key,
  lake_name   text not null,
  date        date not null,
  level_m     numeric(7,3) not null,
  recorded_at timestamptz not null default now(),
  unique (lake_name, date)
);

alter table public.lake_water_levels enable row level security;

-- Public read (same as the existing current-level badge elsewhere in the app)
drop policy if exists "lake_water_levels_select_public" on public.lake_water_levels;
create policy "lake_water_levels_select_public"
  on public.lake_water_levels for select
  using (true);

-- Any signed-in client (incl. anonymous) may write — no per-user ownership,
-- same trust level the app already uses for verified_sessions.
drop policy if exists "lake_water_levels_insert_authenticated" on public.lake_water_levels;
create policy "lake_water_levels_insert_authenticated"
  on public.lake_water_levels for insert
  to authenticated
  with check (true);

drop policy if exists "lake_water_levels_update_authenticated" on public.lake_water_levels;
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
