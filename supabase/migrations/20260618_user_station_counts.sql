-- Per-user breakdown: how many waves the caller rode at each station.
create or replace function public.user_station_counts()
returns table (station_id text, waves int)
language sql
stable
security definer
set search_path = public
as $$
  select station_id, count(*)::int as waves
  from public.wave_history
  where user_id = auth.uid()
  group by station_id
  order by waves desc, station_id;
$$;

grant execute on function public.user_station_counts() to authenticated;