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

  static Map<String, dynamic> profileRow(GameState g, DateTime now) => {
    'id': g.userId,
    'display_name': g.displayName,
    'goal': g.goal,
    'subjects': g.subjects.toList(),
    'daily_minutes': g.dailyMinutes,
    'onboarded': g.onboarded,
    'xp': g.xp,
    'weekly_xp': g.weeklyXp,
    'week_start': day(weekStart(now)),
    'streak': g.streak,
    'last_active_day': g.lastActiveDay == null ? null : day(g.lastActiveDay!),
    'rating': g.rating,
    'answered': g.answered,
    'correct_answers': g.correctAnswers,
    'best_combo': g.bestCombo,
    'badges': g.badges.toList(),
    'postpone_counts': g.postponeCounts,
    'comfort_sessions': g.comfortSessions,
    'updated_at': now.toUtc().toIso8601String(),
  };

  static void applyProfile(
    GameState g,
    Map<String, dynamic> row,
    DateTime now,
  ) {
    final today = dateOnly(now);
    final lastActive = row['last_active_day'] == null
        ? null
        : DateTime.parse(row['last_active_day'] as String);
    // A gap of more than one day breaks the streak.
    final streakAlive =
        lastActive != null &&
        today.difference(dateOnly(lastActive)).inDays <= 1;
    final sameWeek = row['week_start'] == day(weekStart(now));

    g
      ..displayName = row['display_name'] as String? ?? g.displayName
      ..goal = row['goal'] as String?
      ..subjects = {...(row['subjects'] as List? ?? const []).cast<String>()}
      ..dailyMinutes = row['daily_minutes'] as int? ?? 38
      ..onboarded = row['onboarded'] as bool? ?? false
      ..xp = row['xp'] as int? ?? 0
      ..weeklyXp = sameWeek ? row['weekly_xp'] as int? ?? 0 : 0
      ..streak = streakAlive ? row['streak'] as int? ?? 0 : 0
      ..lastActiveDay = lastActive
      ..rating = row['rating'] as int? ?? 1000
      ..answered = row['answered'] as int? ?? 0
      ..correctAnswers = row['correct_answers'] as int? ?? 0
      ..bestCombo = row['best_combo'] as int? ?? 0
      ..comfortSessions = row['comfort_sessions'] as int? ?? 0;
    if (g.subjects.isEmpty) g.subjects = {'Maths'};
    g.badges
      ..clear()
      ..addAll((row['badges'] as List? ?? const []).cast<String>());
    g.postponeCounts
      ..clear()
      ..addAll(
        (row['postpone_counts'] as Map? ?? const {}).map(
          (k, v) => MapEntry(k as String, (v as num).toInt()),
        ),
      );
  }

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
    'last_review': p.lastReview?.toUtc().toIso8601String(),
    'misconception': p.misconception,
    'attempts': p.attempts,
    'repair_streak': p.repairStreak,
    'updated_at': now.toUtc().toIso8601String(),
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

  static List<Map<String, dynamic>> tasksToJson(List<MissionTask> tasks) => [
    for (final t in tasks)
      {
        'type': t.type.name,
        'title': t.title,
        'subtitle': t.subtitle,
        'concept_ids': t.conceptIds,
        'minutes': t.minutes,
        'done': t.done,
      },
  ];

  static List<MissionTask> tasksFromJson(List<dynamic> json) => [
    for (final j in json.cast<Map<String, dynamic>>())
      MissionTask(
        type: TaskType.values.byName(j['type'] as String),
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        conceptIds: (j['concept_ids'] as List).cast<String>(),
        minutes: j['minutes'] as int,
      )..done = j['done'] == true,
  ];
}
