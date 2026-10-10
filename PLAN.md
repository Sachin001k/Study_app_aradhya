# Aradhya — Product & Build Plan

A gamified study app: short bursts of learning, instant
questions, XP, ratings, streaks and leagues powered by a personal knowledge
graph that knows *why* you get things wrong.

---

## 1. Core loop (the "game")

```
 ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
 │ 5-min LEARN  │ → │ 5–8 QUESTION │ → │ XP + RATING  │ → │ GRAPH UPDATE │
 │ card / video │   │ BLITZ (timed)│   │ combo, streak│   │ next mission │
 └──────────────┘   └──────────────┘   └──────────────┘   └──────────────┘
```

1. **Learn (≤5 min)** — a bite-sized concept card (text, worked example, optional short video).
2. **Blitz** — 5–8 questions on that concept, with a timer per question. Speed + accuracy matter.
3. **Reward** — XP, combo multiplier, rating change (+/-), streak flame, loot (badges/titles).
4. **Graph update** — mastery of that node (and its prerequisites) is recalculated; tomorrow's mission is rebuilt.

### Game systems

| System | How it works |
|---|---|
| **XP** | Base 10/question correct, ×combo (1.0 → 2.0 over 5-streak), +bonus for speed, +50 for completing the daily mission. XP drives **levels** (cosmetic + unlocks). |
| **Rating (Elo/Glicko-2)** | Per subject *and* overall. Every question has its own difficulty rating; answering correctly vs. a harder question gains more. Shown as a number + tier (Bronze → Silver → Gold → Platinum → Diamond → Grandmaster). |
| **Streaks** | Daily streak (complete ≥1 mission), streak freeze earned via XP. |
| **Leagues** | Weekly XP leagues of 30 players; top 7 promote, bottom 5 demote. |
| **Duels** | 1v1 real-time quiz on the same topic, rating-matched (phase 3). |
| **Badges** | "Misconception Slayer", "Forgetting Curve Beater", "Comfort-Zone Breaker" — tied to the unique features below. |

---

## 2. Signature features

### 2.1 Personal Knowledge Graph
- Each subject is a DAG of concepts: `Calculus → Derivatives → Chain Rule → Composite Functions`, with prerequisite edges.
- Node states: **Green** mastered · **Yellow** weak · **Red** misconception · **Grey** not studied · **Fading** (opacity falls with predicted recall).
- Recall prediction: spaced-repetition model (FSRS) per node → `retrievability` drives fading.
- **Error diagnosis**: every question is tagged with the concepts it exercises plus *distractor tags* (each wrong option maps to a known misconception). When a chain-rule question is wrong, the AI combines the chosen distractor + the student's history on prerequisite nodes (algebra, function composition, differentiation) to decide where the real gap is, and marks *that* node red.
- UI: zoomable graph (Flutter `CustomPainter` / `graphview`), tap a node → "Repair", "Review", "Learn".

### 2.2 Adaptive Daily Mission
One focused mission instead of a schedule, e.g. **"Today's 38-minute mission"**:
- Repair 1 misconception (red node)
- Review 3 fading concepts
- 2 exam-style questions
- Explain 1 concept aloud (speech-to-text → AI grades the explanation)

Built by a planner that scores candidate tasks by `urgency × impact ÷ time`, fits them into the student's daily minutes, and **rebuilds tomorrow's mission after every session**. Completing it = big XP + streak.

### 2.3 Focus Intervention System
Behaviour detectors run over the session event log:

| Pattern | Signal | Intervention |
|---|---|---|
| Postponing a topic | Same node skipped/snoozed ≥3 times | "Boss fight": 3-question micro-challenge with bonus XP |
| Comfort-zone studying | >70% of time on green nodes this week | Mission forces one yellow/red node; "Comfort-Zone Breaker" badge |
| Over-note-taking | Notes time > 2× practice time | Nudge: "Test yourself first" → quick recall quiz |
| Chatbot without attempting | AI tutor opened before any attempt on the question | Tutor asks for an attempt / first step before hinting |
| Passive review | Reading review cards without recall checks | Converts review into active-recall flashcards |

---

## 3. Tech stack

| Layer | Choice |
|---|---|
| App | Flutter (Android, iOS, web), Dart 3 |
| State | Riverpod |
| Routing | go_router |
| Local cache | Drift (SQLite) or Hive — offline questions + event queue |
| Backend | **Supabase** (see §4) |
| AI | Supabase Edge Functions calling an LLM (diagnosis, explanation grading, mission planning) |
| Push | Firebase Cloud Messaging (FCM is free and works fine alongside Supabase) |
| Analytics | PostHog or Firebase Analytics |

### Folder structure (feature-first)
```
lib/
  core/        theme, widgets, routing, utils
  features/
    auth/      data/ (repository)  presentation/ (screens, widgets)
    home/      mission card, streak, league
    learn/     5-min lesson player
    blitz/     question engine, timer, scoring
    graph/     knowledge graph view
    profile/   rating, badges, stats
    focus/     intervention detectors + UI
```

---

## 4. Supabase vs Firebase — recommendation: **Supabase**

| Need in this app | Supabase | Firebase |
|---|---|---|
| Knowledge graph (concepts + prerequisite edges, recursive queries) | ✅ Postgres + recursive CTEs, joins | ❌ Firestore has no joins; graph traversal is painful & costly |
| Ratings, leagues, leaderboards | ✅ SQL `ORDER BY`, window functions, materialized views | ⚠️ Needs denormalised counters + Cloud Functions |
| Analytics on behaviour (focus detectors) | ✅ SQL over event table | ⚠️ Export to BigQuery |
| AI / semantic search on content | ✅ `pgvector` built in | ⚠️ Separate vector DB |
| Security | ✅ Row Level Security policies | ✅ Security Rules |
| Real-time duels | ✅ Realtime channels | ✅ Realtime DB |
| Offline sync | ⚠️ Do it yourself (local DB + queue) | ✅ Built in |
| Pricing | Predictable (per project tier) | Per read/write — gamified apps read a lot, costs spike |
| Lock-in | Open source, plain Postgres | Proprietary |

The data here is highly **relational** (students ↔ concepts ↔ questions ↔ attempts ↔ misconceptions), which is Postgres's home turf. Use FCM only for push notifications.

### Initial schema (Supabase / Postgres)
```
profiles(id → auth.users, username, display_name, avatar, grade, exam_goal,
         daily_minutes, xp, level, streak, last_active_date)
subjects(id, name)
concepts(id, subject_id, name, description)
concept_edges(parent_id, child_id)                -- prerequisite DAG
misconceptions(id, concept_id, description)
questions(id, concept_id, body, options jsonb, answer, difficulty_rating,
          distractor_map jsonb)                    -- option → misconception_id
attempts(id, user_id, question_id, chosen, correct, time_ms, created_at)
user_concept_state(user_id, concept_id, mastery, stability, difficulty,
                   last_review, status)            -- FSRS + colour
user_ratings(user_id, subject_id, rating, rd, volatility)
missions(id, user_id, date, tasks jsonb, completed_at)
study_events(id, user_id, type, payload jsonb, created_at)  -- focus detectors
leagues / league_members, badges / user_badges
```

---

## 5. Login system (phase 1 — in progress)

**Screens**
1. **Welcome** — animated hero, "Level up your brain", Get started / I have an account.
2. **Log in** — email + password, Google, Apple (iOS), "Forgot password?".
3. **Sign up** — name, username, email, password with strength meter.
4. **Forgot password** — email → magic reset link.
5. **Onboarding** — pick class/exam goal, subjects, daily minutes (feeds mission planner), then a "starter rating" placement blitz (later).

**Auth methods (Supabase Auth)**: email/password, Google OAuth, Apple Sign-In, email OTP. Session persisted by `supabase_flutter`; `profiles` row created via a DB trigger on `auth.users` insert.

**Status**: UI built with a mock `AuthRepository`; swapping in `SupabaseAuthRepository` is a single class.

---

## 6. Roadmap

| Phase | Scope |
|---|---|
| **1. Foundation** | Theme/design system, login + onboarding UI, Supabase auth wiring, profiles |
| **2. Core game loop** | Lesson player, question blitz, XP/combo/levels, streaks, Elo rating per subject |
| **3. Knowledge graph** | Concept DAG content for 1 subject, mastery colours, FSRS fading, graph UI |
| **4. Daily mission** | Planner (rules first, LLM later), mission card, nightly rebuild |
| **5. AI diagnosis** | Distractor tagging, prerequisite back-tracing, AI tutor that requires an attempt first |
| **6. Focus interventions** | Event logging, 5 detectors, nudges/boss fights |
| **7. Social** | Weekly leagues, friends, real-time duels |
| **8. Polish** | Explain-aloud (speech), offline mode, notifications, analytics |
