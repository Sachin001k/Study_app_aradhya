import 'content.dart';
import 'game_state.dart';

/// Converts [GameState] to and from database rows (see supabase/schema.sql).
class ProgressCodec {
  ProgressCodec._();

  static String day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Monday of the week containing [d] (matches Postgres `date_trunc('week')`).
  static DateTime weekStart(DateTime d) =>
      dateOnly(d).subtract(Duration(days: d.weekday - 1));

  static String _ts(DateTime d) => d.toUtc().toIso8601String();

  // ---------------------------------------------------------------- profile

  static Map<String, dynamic> profileRow(GameState g, DateTime now) => {
    'id': g.userId,
    'display_name': g.displayName,
    'goal': g.goal,
    'daily_minutes': g.dailyMinutes,
    'onboarded': g.onboarded,
    'updated_at': _ts(now),
  };

  static void applyProfile(GameState g, Map<String, dynamic> row) {
    g
      ..displayName = row['display_name'] as String? ?? g.displayName
      ..goal = row['goal'] as String?
      ..dailyMinutes = row['daily_minutes'] as int? ?? 38
      ..onboarded = row['onboarded'] as bool? ?? false;
  }

  // ------------------------------------------------------------------ stats

  static Map<String, dynamic> statsRow(GameState g, DateTime now) => {
    'user_id': g.userId,
    'xp': g.xp,
    'level': g.level,
    'weekly_xp': g.weeklyXp,
    'week_start': day(weekStart(now)),
    'rating': g.rating,
    'peak_rating': g.peakRating,
    'streak': g.streak,
    'longest_streak': g.longestStreak,
    'last_active_day': g.lastActiveDay == null ? null : day(g.lastActiveDay!),
    'questions_answered': g.answered,
    'questions_correct': g.correctAnswers,
    'best_combo': g.bestCombo,
    'games_played': g.gamesPlayed,
    'missions_completed': g.missionsCompleted,
    'misconceptions_repaired': g.misconceptionsRepaired,
    'comfort_sessions': g.comfortSessions,
    'postpone_counts': g.postponeCounts,
    'updated_at': _ts(now),
  };

  static void applyStats(GameState g, Map<String, dynamic> row, DateTime now) {
    final today = dateOnly(now);
    final lastActive = row['last_active_day'] == null
        ? null
        : DateTime.parse(row['last_active_day'] as String);
    // A gap of more than one day breaks the streak.
    final streakAlive =
        lastActive != null &&
        today.difference(dateOnly(lastActive)).inDays <= 1;
    final sameWeek = row['week_start'] == day(weekStart(now));
    int i(String k, [int fallback = 0]) => row[k] as int? ?? fallback;

    g
      ..xp = i('xp')
      ..weeklyXp = sameWeek ? i('weekly_xp') : 0
      ..rating = i('rating', 1000)
      ..peakRating = i('peak_rating', 1000)
      ..streak = streakAlive ? i('streak') : 0
      ..longestStreak = i('longest_streak')
      ..lastActiveDay = lastActive
      ..answered = i('questions_answered')
      ..correctAnswers = i('questions_correct')
      ..bestCombo = i('best_combo')
      ..gamesPlayed = i('games_played')
      ..missionsCompleted = i('missions_completed')
      ..misconceptionsRepaired = i('misconceptions_repaired')
      ..comfortSessions = i('comfort_sessions');
    g.postponeCounts
      ..clear()
      ..addAll(
        (row['postpone_counts'] as Map? ?? const {}).map(
          (k, v) => MapEntry(k as String, (v as num).toInt()),
        ),
      );
  }

  // ---------------------------------------------------------- daily activity

  static Map<String, dynamic> dailyRow(GameState g, DateTime now) => {
    'user_id': g.userId,
    'day': day(g.activityDay),
    'xp': g.todayXp,
    'questions': g.todayQuestions,
    'correct': g.todayCorrect,
    'sessions': g.todaySessions,
    'seconds_played': g.todaySeconds,
    'updated_at': _ts(now),
  };

  static void applyDaily(GameState g, Map<String, dynamic> row) {
    g
      ..activityDay = DateTime.parse(row['day'] as String)
      ..todayXp = row['xp'] as int? ?? 0
      ..todayQuestions = row['questions'] as int? ?? 0
      ..todayCorrect = row['correct'] as int? ?? 0
      ..todaySessions = row['sessions'] as int? ?? 0
      ..todaySeconds = row['seconds_played'] as int? ?? 0;
  }

  // -------------------------------------------------------- concept progress

  static Map<String, dynamic> progressRow(
    String userId,
    String conceptId,
    ConceptProgress p,
    DateTime now,
  ) => {
    'user_id': userId,
    'concept_id': conceptId,
    'mastery': p.mastery,
    'stability_days': p.stabilityDays,
    'last_review': p.lastReview == null ? null : _ts(p.lastReview!),
    'misconception': p.misconception,
    'attempts': p.attempts,
    'repair_streak': p.repairStreak,
    'updated_at': _ts(now),
  };

  static ConceptProgress progressFromRow(Map<String, dynamic> r) =>
      ConceptProgress(
        mastery: (r['mastery'] as num).toDouble(),
        stabilityDays: (r['stability_days'] as num).toDouble(),
        lastReview: r['last_review'] == null
            ? null
            : DateTime.parse(r['last_review'] as String).toLocal(),
        misconception: r['misconception'] as String?,
        attempts: r['attempts'] as int,
      )..repairStreak = r['repair_streak'] as int? ?? 0;

  // ---------------------------------------------------------------- missions

  static Map<String, dynamic> missionRow(
    GameState g,
    DateTime missionDay,
    DateTime now,
  ) => {
    'user_id': g.userId,
    'day': day(missionDay),
    'total_minutes': g.missionMinutes,
    'bonus_claimed': g.missionBonusClaimed,
    'completed_at': g.missionDone ? _ts(now) : null,
    'updated_at': _ts(now),
  };

  static List<Map<String, dynamic>> taskRows(
    String userId,
    DateTime missionDay,
    List<MissionTask> tasks,
    DateTime now,
  ) => [
    for (var i = 0; i < tasks.length; i++)
      {
        'user_id': userId,
        'day': day(missionDay),
        'position': i,
        'type': tasks[i].type.name,
        'title': tasks[i].title,
        'subtitle': tasks[i].subtitle,
        'concept_ids': tasks[i].conceptIds,
        'minutes': tasks[i].minutes,
        'done': tasks[i].done,
        'updated_at': _ts(now),
      },
  ];

  static List<MissionTask> tasksFromRows(List<Map<String, dynamic>> rows) {
    final sorted = [...rows]
      ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    return [
      for (final r in sorted)
        // Skip rows that would crash launchTask: unknown type, or no/removed
        // concept ids (content.dart may change between releases).
        if (TaskType.values.any((t) => t.name == r['type']) &&
            (r['concept_ids'] as List? ?? const []).isNotEmpty &&
            (r['concept_ids'] as List).every(conceptById.containsKey))
          MissionTask(
            type: TaskType.values.byName(r['type'] as String),
            title: r['title'] as String,
            subtitle: r['subtitle'] as String? ?? '',
            conceptIds: (r['concept_ids'] as List).cast<String>(),
            minutes: r['minutes'] as int,
          )..done = r['done'] == true,
    ];
  }

  // ------------------------------------------------------------------ events

  static Map<String, dynamic> attemptRow(
    String userId,
    SessionSummary s,
    Question q,
    int chosen,
    bool correct,
    Duration taken,
    int ratingDelta,
  ) => {
    'user_id': userId,
    'session_id': s.id,
    'mode': s.mode,
    'question_id': q.id,
    'concept_id': q.conceptId,
    'prompt': q.prompt,
    'options': q.options,
    'answer_index': q.answer,
    'chosen': chosen,
    'correct_answer': q.options[q.answer],
    'given_answer': chosen >= 0 && chosen < q.options.length
        ? q.options[chosen]
        : null,
    'correct': correct,
    'time_ms': taken.inMilliseconds,
    'difficulty': q.difficulty,
    'rating_delta': ratingDelta,
  };

  static Map<String, dynamic> sessionRow(
    String userId,
    SessionSummary s,
    MissionTask? task,
    DateTime now,
  ) => {
    'id': s.id,
    'user_id': userId,
    'mode': s.mode,
    'title': s.title,
    'score': s.score,
    'correct': s.correct,
    'total': s.total,
    'best_combo': s.bestCombo,
    'xp_earned': s.xp,
    'rating_before': s.ratingBefore,
    'rating_after': s.ratingAfter ?? s.ratingBefore,
    'outcome': s.outcome,
    'opponent': s.opponent,
    'mission_task': task?.type.name,
    'started_at': _ts(s.startedAt),
    'ended_at': _ts(now),
    'duration_ms': now.difference(s.startedAt).inMilliseconds,
  };
}
