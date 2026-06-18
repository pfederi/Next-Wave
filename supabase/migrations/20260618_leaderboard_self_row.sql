-- Always return the caller's own leaderboard row, even with zero history,
-- so the app can show "You — …" reliably.
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
  -- Top named users excluding the caller.
  (select rnk, display_name, total, false
   from ranked
   where display_name is not null
     and user_id <> auth.uid()
   order by rnk asc, total desc
   limit p_limit)
  union all
  -- Caller's own row when they already have history.
  (select rnk, coalesce(display_name, 'You'), total, true
   from ranked
   where user_id = auth.uid())
  union all
  -- Synthetic own row when the caller has no history yet (rank = last + 1, 0 waves).
  (select (select count(*) from totals) + 1, 'You', 0, true
   where not exists (select 1 from totals where user_id = auth.uid()));
$$;

grant execute on function public.wave_leaderboard(text, int) to authenticated;
