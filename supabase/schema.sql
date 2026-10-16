-- =====================================================================
-- Ekagna database schema
-- Run in Supabase → SQL Editor → New query → paste everything → Run.
-- Safe to re-run: every statement is idempotent.
--
--  PLAYER INPUT      profiles, user_subjects
--  STATS             player_stats, daily_activity, rating_history
--  LEARNING          concept_progress, misconception_events, explanations
--  MISSIONS          missions, mission_tasks
--  GAMES             game_sessions, attempts, personal_bests
--  REWARDS           xp_events, badges (catalog), user_badges
--  BEHAVIOUR         focus_events
-- =====================================================================

-- ------------------------------------------------------------ player input
create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  display_name  text not null default 'Player',
  username      text,
  goal          text,                       -- e.g. 'JEE', 'Class 11–12'
  daily_minutes int  not null default 38,   -- daily mission length
  onboarded     boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table if not exists public.user_subjects (
  user_id  uuid not null references auth.users (id) on delete cascade,
  subject  text not null,
  added_at timestamptz not null default now(),
  primary key (user_id, subject)
);

-- ------------------------------------------------------------------- stats
create table if not exists public.player_stats (
  user_id                 uuid primary key references auth.users (id) on delete cascade,
  xp                      int  not null default 0,
  level                   int  not null default 1,
  weekly_xp               int  not null default 0,
  week_start              date not null default date_trunc('week', now())::date,
  rating                  int  not null default 1000,
  peak_rating             int  not null default 1000,
  streak                  int  not null default 0,
  longest_streak          int  not null default 0,
  last_active_day         date,
  questions_answered      int  not null default 0,
  questions_correct       int  not null default 0,
  best_combo              int  not null default 0,
  games_played            int  not null default 0,
  missions_completed      int  not null default 0,
  misconceptions_repaired int  not null default 0,
  comfort_sessions        int  not null default 0,
  postpone_counts         jsonb not null default '{}',  -- concept_id → times postponed
  updated_at              timestamptz not null default now()
);

create table if not exists public.daily_activity (
  user_id        uuid not null references auth.users (id) on delete cascade,
  day            date not null,
  xp             int  not null default 0,
  questions      int  not null default 0,
  correct        int  not null default 0,
  sessions       int  not null default 0,
  seconds_played int  not null default 0,
  updated_at     timestamptz not null default now(),
  primary key (user_id, day)
);

create table if not exists public.rating_history (
  id            bigint generated always as identity primary key,
  user_id       uuid not null references auth.users (id) on delete cascade,
  session_id    uuid,
  mode          text not null,
  rating_before int  not null,
  rating_after  int  not null,
  delta         int  not null,
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------- learning
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

create table if not exists public.misconception_events (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  session_id  uuid,
  kind        text not null check (kind in ('detected', 'repaired')),
  question_id text,
  concept_id  text not null,          -- concept of the question
  root_cause  text,                   -- concept actually blamed
  explanation text,
  created_at  timestamptz not null default now()
);

create table if not exists public.explanations (
  id             bigint generated always as identity primary key,
  user_id        uuid not null references auth.users (id) on delete cascade,
  session_id     uuid,
  concept_id     text not null,
  seconds        int  not null default 0,
  points_covered int  not null default 0,
  points_total   int  not null default 0,
  created_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------- missions
create table if not exists public.missions (
  user_id       uuid not null references auth.users (id) on delete cascade,
  day           date not null,
  total_minutes int  not null default 0,
  bonus_claimed boolean not null default false,
  completed_at  timestamptz,
  updated_at    timestamptz not null default now(),
  primary key (user_id, day)
);

create table if not exists public.mission_tasks (
  user_id     uuid not null,
  day         date not null,
  position    int  not null,
  type        text not null,          -- placement, repair, review, learn, exam, explain, boss
  title       text not null,
  subtitle    text not null default '',
  concept_ids text[] not null default '{}',
  minutes     int  not null default 0,
  done        boolean not null default false,
  updated_at  timestamptz not null default now(),
  primary key (user_id, day, position),
  foreign key (user_id, day) references public.missions (user_id, day) on delete cascade
);

-- ------------------------------------------------------------------- games
create table if not exists public.game_sessions (
  id            uuid primary key,
  user_id       uuid not null references auth.users (id) on delete cascade,
  mode          text not null,        -- blitz, rush, survival, truefalse, crunch, memory, duel
  title         text not null,
  score         int,
  correct       int  not null default 0,
  total         int  not null default 0,
  best_combo    int  not null default 0,
  xp_earned     int  not null default 0,
  rating_before int  not null,
  rating_after  int  not null,
  outcome       text,                 -- win / loss / draw (duels)
  opponent      text,
  mission_task  text,                 -- task type if part of the daily mission
  started_at    timestamptz not null,
  ended_at      timestamptz not null default now(),
  duration_ms   int  not null default 0
);
create index if not exists game_sessions_user_time on public.game_sessions (user_id, ended_at desc);

create table if not exists public.attempts (
  id             bigint generated always as identity primary key,
  user_id        uuid not null references auth.users (id) on delete cascade,
  session_id     uuid,
  mode           text not null,
  question_id    text not null,
  concept_id     text not null,       -- 'arithmetic' for Number Crunch
  prompt         text not null,
  options        jsonb,               -- the 4 generated options (null for typed answers)
  answer_index   int,
  chosen         int,                 -- -1 = timed out
  correct_answer text,
  given_answer   text,
  correct        boolean not null,
  time_ms        int  not null,
  difficulty     int,
  rating_delta   int  not null default 0,
  created_at     timestamptz not null default now()
);
create index if not exists attempts_user_time on public.attempts (user_id, created_at desc);

create table if not exists public.personal_bests (
  user_id     uuid not null references auth.users (id) on delete cascade,
  mode        text not null,
  best_score  int  not null,
  session_id  uuid,
  achieved_at timestamptz not null default now(),
  primary key (user_id, mode)
);

-- ----------------------------------------------------------------- rewards
create table if not exists public.xp_events (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  session_id uuid,
  amount     int  not null,
  source     text not null,           -- answer mode, mission_bonus, explain, memory, crunch, duel_result
  created_at timestamptz not null default now()
);
create index if not exists xp_events_user_time on public.xp_events (user_id, created_at desc);

create table if not exists public.badges (
  id          text primary key,
  name        text not null,
  description text not null,
  emoji       text not null
);

create table if not exists public.user_badges (
  user_id    uuid not null references auth.users (id) on delete cascade,
  badge_id   text not null references public.badges (id),
  session_id uuid,
  earned_at  timestamptz not null default now(),
  primary key (user_id, badge_id)
);

-- --------------------------------------------------------------- behaviour
create table if not exists public.focus_events (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  kind       text not null,           -- postpone, boss_unlocked, boss_defeated, comfort_nudge
  concept_id text,
  data       jsonb not null default '{}',
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------ badge catalog
insert into public.badges (id, name, description, emoji) values
  ('first_blitz',     'First Blood',          'Finish your first blitz',             '⚔️'),
  ('combo5',          'On Fire',              'Hit a 5× combo',                      '🔥'),
  ('slayer',          'Misconception Slayer', 'Repair a misconception',              '🗡️'),
  ('mission',         'Mission Accomplished', 'Complete a daily mission',            '🎯'),
  ('comfort',         'Comfort-Zone Breaker', 'Tackle a weak topic after a nudge',   '🧗'),
  ('boss',            'Boss Slayer',          'Beat a postponed-topic boss fight',   '👹'),
  ('perfect',         'Flawless',             'Score 100% in a blitz of 3+',         '💎'),
  ('level5',          'Rising Star',          'Reach level 5',                       '⭐'),
  ('speed_demon',     'Speed Demon',          'Solve 15+ in a Speed Rush',           '⚡'),
  ('survivor',        'Survivor',             'Reach 15 in Survival',                '🛡️'),
  ('number_cruncher', 'Number Cruncher',      'Score 20+ in Number Crunch',          '🧮'),
  ('sharp_memory',    'Elephant Memory',      'Clear Memory Match in ≤ 10 moves',    '🐘'),
  ('duelist',         'Duelist',              'Win a duel',                          '🤺'),
  ('lie_detector',    'Lie Detector',         'Score 15+ in True or False',          '🕵️'),
  ('arcade_master',   'Arcade Master',        'Play every arcade game',              '🕹️')
on conflict (id) do update
  set name = excluded.name, description = excluded.description, emoji = excluded.emoji;

-- ------------------------------------------------------- row level security
-- State tables: a player can read and write only their own rows.
do $$
declare t text;
begin
  foreach t in array array[
    'user_subjects', 'player_stats', 'daily_activity', 'concept_progress',
    'missions', 'mission_tasks', 'personal_bests', 'user_badges'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "own rows" on public.%I', t);
    execute format(
      'create policy "own rows" on public.%I for all to authenticated
         using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t);
  end loop;

  -- Event logs: append-only (read + insert, no edits or deletes).
  foreach t in array array[
    'rating_history', 'misconception_events', 'explanations', 'game_sessions',
    'attempts', 'xp_events', 'focus_events'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "own rows read" on public.%I', t);
    execute format('drop policy if exists "own rows insert" on public.%I', t);
    execute format(
      'create policy "own rows read" on public.%I for select to authenticated
         using ((select auth.uid()) = user_id)', t);
    execute format(
      'create policy "own rows insert" on public.%I for insert to authenticated
         with check ((select auth.uid()) = user_id)', t);
  end loop;
end $$;

alter table public.profiles enable row level security;
drop policy if exists "own profile" on public.profiles;
create policy "own profile" on public.profiles
  for all to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

alter table public.badges enable row level security;
drop policy if exists "badge catalog is public" on public.badges;
create policy "badge catalog is public" on public.badges
  for select to authenticated using (true);

-- ------------------------------------- create profile + stats for new users
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

  insert into public.player_stats (user_id) values (new.id)
  on conflict (user_id) do nothing;
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
         case when s.week_start = date_trunc('week', now())::date
              then s.weekly_xp else 0 end as weekly_xp
  from public.profiles p
  join public.player_stats s on s.user_id = p.id
  order by 3 desc, p.created_at
  limit 30;
$$;

revoke execute on function public.weekly_league() from public, anon;
grant execute on function public.weekly_league() to authenticated;

-- ------------------------------------------------------- table permissions
grant usage on schema public to authenticated;

-- State tables: read + write own rows.
grant select, insert, update, delete on
  public.profiles,
  public.user_subjects,
  public.player_stats,
  public.daily_activity,
  public.concept_progress,
  public.missions,
  public.mission_tasks,
  public.personal_bests,
  public.user_badges
to authenticated;

-- Event logs: append-only.
grant select, insert on
  public.rating_history,
  public.misconception_events,
  public.explanations,
  public.game_sessions,
  public.attempts,
  public.xp_events,
  public.focus_events
to authenticated;

-- Badge catalog: read-only.
grant select on public.badges to authenticated;

grant usage, select on all sequences in schema public to authenticated;
