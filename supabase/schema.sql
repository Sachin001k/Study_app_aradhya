-- Aradhya database schema.
-- Run once in Supabase → SQL Editor → New query → paste → Run.
-- Safe to re-run: every statement is idempotent.

-- ---------------------------------------------------------------- profiles
create table if not exists public.profiles (
  id               uuid primary key references auth.users (id) on delete cascade,
  display_name     text not null default 'Player',
  username         text,
  goal             text,
  subjects         text[] not null default '{}',
  daily_minutes    int  not null default 38,
  onboarded        boolean not null default false,
  xp               int  not null default 0,
  weekly_xp        int  not null default 0,
  week_start       date not null default date_trunc('week', now())::date,
  streak           int  not null default 0,
  last_active_day  date,
  rating           int  not null default 1000,
  answered         int  not null default 0,
  correct_answers  int  not null default 0,
  best_combo       int  not null default 0,
  badges           text[] not null default '{}',
  postpone_counts  jsonb not null default '{}',
  comfort_sessions int  not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ------------------------------------------------------ knowledge-map state
create table if not exists public.concept_progress (
  user_id        uuid not null references auth.users (id) on delete cascade,
  concept_id     text not null,
  mastery        real not null default 0,
  stability_days real not null default 3,
  last_review    timestamptz,
  misconception  text,
  attempts       int  not null default 0,
  repair_streak  int  not null default 0,
  updated_at     timestamptz not null default now(),
  primary key (user_id, concept_id)
);

-- ------------------------------------------------------------ daily missions
create table if not exists public.missions (
  user_id       uuid not null references auth.users (id) on delete cascade,
  day           date not null,
  tasks         jsonb not null default '[]',
  bonus_claimed boolean not null default false,
  updated_at    timestamptz not null default now(),
  primary key (user_id, day)
);

-- ------------------------------------- answer log (feeds focus detectors / AI)
create table if not exists public.attempts (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  question_id text not null,
  concept_id  text not null,
  chosen      int  not null,
  correct     boolean not null,
  time_ms     int  not null,
  created_at  timestamptz not null default now()
);
create index if not exists attempts_user_time on public.attempts (user_id, created_at desc);

-- ------------------------------------------------------- row level security
alter table public.profiles         enable row level security;
alter table public.concept_progress enable row level security;
alter table public.missions         enable row level security;
alter table public.attempts         enable row level security;

drop policy if exists "own profile" on public.profiles;
create policy "own profile" on public.profiles
  for all to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

drop policy if exists "own progress" on public.concept_progress;
create policy "own progress" on public.concept_progress
  for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "own missions" on public.missions;
create policy "own missions" on public.missions
  for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "own attempts" on public.attempts;
create policy "own attempts" on public.attempts
  for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- ------------------------------------- create a profile for every new user
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, username)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'name',
      new.raw_user_meta_data ->> 'full_name',
      split_part(new.email, '@', 1),
      'Player'
    ),
    new.raw_user_meta_data ->> 'username'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- --------------------------------------------- weekly league (public view)
-- Exposes only name + this week's XP of the top 30 players.
create or replace function public.weekly_league()
returns table (id uuid, display_name text, weekly_xp int)
language sql
stable
security definer set search_path = ''
as $$
  select p.id,
         p.display_name,
         case when p.week_start = date_trunc('week', now())::date
              then p.weekly_xp else 0 end as weekly_xp
  from public.profiles p
  order by 3 desc, p.created_at
  limit 30;
$$;

revoke execute on function public.weekly_league() from public, anon;
grant execute on function public.weekly_league() to authenticated;
