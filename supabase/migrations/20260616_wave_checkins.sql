-- Wave check-ins: one row per (wave, device-identity)
create table if not exists public.wave_checkins (
  id           uuid primary key default gen_random_uuid(),
  wave_id      text not null,
  user_id      uuid not null references auth.users (id) on delete cascade,
  display_name text,
  departure_at timestamptz not null,
  created_at   timestamptz not null default now(),
  unique (wave_id, user_id)
);

create index if not exists wave_checkins_wave_id_idx on public.wave_checkins (wave_id);
create index if not exists wave_checkins_departure_at_idx on public.wave_checkins (departure_at);

alter table public.wave_checkins enable row level security;

-- Public read (count + names are public)
drop policy if exists "wave_checkins_select_public" on public.wave_checkins;
create policy "wave_checkins_select_public"
  on public.wave_checkins for select
  using (true);

-- Insert only your own rows
drop policy if exists "wave_checkins_insert_own" on public.wave_checkins;
create policy "wave_checkins_insert_own"
  on public.wave_checkins for insert
  with check (auth.uid() = user_id);

-- Update only your own rows
drop policy if exists "wave_checkins_update_own" on public.wave_checkins;
create policy "wave_checkins_update_own"
  on public.wave_checkins for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Delete only your own rows
drop policy if exists "wave_checkins_delete_own" on public.wave_checkins;
create policy "wave_checkins_delete_own"
  on public.wave_checkins for delete
  using (auth.uid() = user_id);

-- Batched counter read: count + non-anonymous names per wave
create or replace function public.wave_checkin_counts(wave_ids text[])
returns table (wave_id text, count bigint, names text[])
language sql
stable
security definer
set search_path = public
as $$
  select
    c.wave_id,
    count(*)::bigint as count,
    array_remove(array_agg(c.display_name) filter (where c.display_name is not null), null) as names
  from public.wave_checkins c
  where c.wave_id = any(wave_ids)
    and c.departure_at >= now()
  group by c.wave_id;
$$;

grant execute on function public.wave_checkin_counts(text[]) to anon, authenticated;

-- Daily cleanup of past check-ins
create extension if not exists pg_cron;
select cron.schedule(
  'wave_checkins_cleanup',
  '0 3 * * *',
  $$delete from public.wave_checkins where departure_at < now()$$
);
