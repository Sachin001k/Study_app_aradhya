-- Table permissions for signed-in players.
-- Needed because this project doesn't auto-grant access to new tables.
-- Row Level Security still limits every player to their own rows.
-- Logged-out visitors (anon) get no access at all.
-- Safe to re-run.

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
