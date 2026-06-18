create table if not exists public.verified_sessions (
  user_id        uuid not null references auth.users(id) on delete cascade,
  session_key    text not null,
  source         text not null default 'foilmotion',
  start_at       timestamptz not null,
  end_at         timestamptz not null,
  total_distance double precision not null,
  duration       int not null,
  moving_time    int not null,
  max_speed      double precision not null,
  longest_ride   double precision not null,
  recorded_at    timestamptz not null default now(),
  primary key (user_id, session_key)
);

alter table public.verified_sessions enable row level security;

drop policy if exists "verified_sessions_select_own" on public.verified_sessions;
create policy "verified_sessions_select_own" on public.verified_sessions
  for select using (auth.uid() = user_id);
drop policy if exists "verified_sessions_insert_own" on public.verified_sessions;
create policy "verified_sessions_insert_own" on public.verified_sessions
  for insert with check (auth.uid() = user_id);

create or replace function public.user_verified_stats()
returns table (
  session_count int, total_distance_m double precision,
  longest_ride_m double precision, max_speed_ms double precision
)
language sql stable security definer set search_path = public
as $$
  select
    (select count(*) from public.verified_sessions where user_id = auth.uid())::int,
    coalesce((select sum(total_distance) from public.verified_sessions where user_id = auth.uid()), 0),
    coalesce((select max(longest_ride)   from public.verified_sessions where user_id = auth.uid()), 0),
    coalesce((select max(max_speed)      from public.verified_sessions where user_id = auth.uid()), 0);
$$;

grant execute on function public.user_verified_stats() to authenticated;
