import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../auth/data/auth_repository.dart';
import 'content.dart';
import 'generator.dart';

/// Shared question generator: fresh numbers every time.
final questionGen = QuestionGenerator();

/// Random v4 UUID, used to tie answers and rewards to a game session.
String newId() {
  final r = math.Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

enum ConceptStatus { notStudied, weak, misconception, mastered }

class ConceptProgress {
  ConceptProgress({
    this.mastery = 0,
    this.stabilityDays = 3,
    this.lastReview,
    this.misconception,
    this.attempts = 0,
  });

  /// 0–1 estimate of how well the concept is understood.
  double mastery;

  /// Days until recall drops to ~37% (spaced-repetition stability).
  double stabilityDays;
  DateTime? lastReview;

  /// Active misconception explanation; non-null makes the node red.
  String? misconception;
  int attempts;

  /// Consecutive correct answers while a misconception is active.
  int repairStreak = 0;

  ConceptStatus get status {
    if (misconception != null) return ConceptStatus.misconception;
    if (attempts == 0) return ConceptStatus.notStudied;
    return mastery >= 0.75 ? ConceptStatus.mastered : ConceptStatus.weak;
  }

  /// Predicted probability of recalling the concept right now.
  double recall(DateTime now) {
    final last = lastReview;
    if (last == null) return 0;
    final days = now.difference(last).inMinutes / (60 * 24);
    return math.exp(-days / stabilityDays);
  }

  bool isFading(DateTime now) => attempts > 0 && recall(now) < 0.6;
}

enum TaskType { placement, repair, review, learn, exam, explain, boss }

class MissionTask {
  MissionTask({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.conceptIds,
    required this.minutes,
  });

  final TaskType type;
  final String title;
  final String subtitle;
  final List<String> conceptIds;
  final int minutes;
  bool done = false;
}

class Diagnosis {
  const Diagnosis({
    required this.question,
    required this.rootCause,
    required this.explanation,
  });

  final Question question;
  final Concept rootCause;
  final String explanation;
}

class AnswerResult {
  const AnswerResult({
    required this.correct,
    required this.xp,
    required this.ratingDelta,
    this.diagnosis,
    this.repaired,
  });

  final bool correct;
  final int xp;
  final int ratingDelta;
  final Diagnosis? diagnosis;

  /// Set when this answer cleared a misconception.
  final Concept? repaired;
}

class SessionSummary {
  SessionSummary({
    required this.title,
    required this.total,
    required this.ratingBefore,
    required this.levelBefore,
    this.mode = 'blitz',
  }) : id = newId(),
       startedAt = DateTime.now();

  final String id;
  final String title;

  /// Game mode id, e.g. 'blitz', 'rush', 'duel' (see arcade/game_modes.dart).
  final String mode;
  final DateTime startedAt;
  int total;
  final int ratingBefore;
  final int levelBefore;
  int? ratingAfter;

  /// Mode-specific score (questions solved, survival depth, …), if any.
  int? score;
  int? previousBest;
  bool isNewBest = false;

  /// 'win' / 'loss' / 'draw' for duels.
  String? outcome;
  String? opponent;
  int correct = 0;
  int xp = 0;
  int bestCombo = 0;
  final List<Diagnosis> diagnoses = [];
  final List<Concept> repaired = [];
  final Set<String> conceptIds = {};
  bool missionCompleted = false;
  final List<GameBadge> newBadges = [];
}

class GameBadge {
  const GameBadge(this.id, this.name, this.description, this.emoji);

  final String id;
  final String name;
  final String description;
  final String emoji;
}

const allBadges = [
  GameBadge('first_blitz', 'First Blood', 'Finish your first blitz', '⚔️'),
  GameBadge('combo5', 'On Fire', 'Hit a 5× combo', '🔥'),
  GameBadge('slayer', 'Misconception Slayer', 'Repair a misconception', '🗡️'),
  GameBadge(
    'mission',
    'Mission Accomplished',
    'Complete a daily mission',
    '🎯',
  ),
  GameBadge(
    'comfort',
    'Comfort-Zone Breaker',
    'Tackle a weak topic after a nudge',
    '🧗',
  ),
  GameBadge('boss', 'Boss Slayer', 'Beat a postponed-topic boss fight', '👹'),
  GameBadge('perfect', 'Flawless', 'Score 100% in a blitz of 3+', '💎'),
  GameBadge('level5', 'Rising Star', 'Reach level 5', '⭐'),
  GameBadge('speed_demon', 'Speed Demon', 'Solve 15+ in a Speed Rush', '⚡'),
  GameBadge('survivor', 'Survivor', 'Reach 15 in Survival', '🛡️'),
  GameBadge(
    'number_cruncher',
    'Number Cruncher',
    'Score 20+ in Number Crunch',
    '🧮',
  ),
  GameBadge(
    'sharp_memory',
    'Elephant Memory',
    'Clear Memory Match in ≤ 10 moves',
    '🐘',
  ),
  GameBadge('duelist', 'Duelist', 'Win a duel', '🤺'),
  GameBadge(
    'lie_detector',
    'Lie Detector',
    'Score 15+ in True or False',
    '🕵️',
  ),
  GameBadge('arcade_master', 'Arcade Master', 'Play every arcade game', '🕹️'),
];

/// Receives everything worth recording (answers, XP, badges, sessions…).
/// Implemented by the Supabase store; null when offline.
abstract class GameEventSink {
  void onAttempt(
    SessionSummary session,
    Question question,
    int chosen,
    bool correct,
    Duration taken,
    int ratingDelta,
  );
  void onArithmetic(
    SessionSummary session,
    String prompt,
    int answer,
    int? given,
    bool correct,
    Duration taken,
  );
  void onXp(SessionSummary? session, int amount, String source);
  void onMisconception(SessionSummary session, Diagnosis diagnosis);
  void onRepaired(SessionSummary session, Concept concept);
  void onBadge(SessionSummary? session, GameBadge badge);
  void onSessionFinished(SessionSummary session, MissionTask? task);
  void onFocus(String kind, {String? conceptId, Map<String, Object?> data});
  void onExplanation(
    SessionSummary session,
    String conceptId,
    int seconds,
    int covered,
    int total,
  );
}

/// Rating tiers, Matiks/chess style.
({String name, int color}) tierFor(int rating) => switch (rating) {
  < 1000 => (name: 'Bronze', color: 0xFFCD7F32),
  < 1200 => (name: 'Silver', color: 0xFFC0C7D6),
  < 1400 => (name: 'Gold', color: 0xFFFFC53D),
  < 1600 => (name: 'Platinum', color: 0xFF5EEAD4),
  < 1800 => (name: 'Diamond', color: 0xFF60A5FA),
  _ => (name: 'Grandmaster', color: 0xFFF472B6),
};

/// Total XP needed to reach [level]: 0, 100, 300, 600, 1000, …
int xpForLevel(int level) => 50 * (level - 1) * level;

/// All game state, kept in memory until the backend is connected.
class GameState extends ChangeNotifier {
  String? userId;
  String displayName = 'Player';
  bool onboarded = true;
  String? goal;
  Set<String> subjects = {'Maths'};
  int dailyMinutes = 38;

  int xp = 0;
  int weeklyXp = 0;
  int streak = 0;
  int rating = 1000;
  int answered = 0;
  int correctAnswers = 0;
  int bestCombo = 0;
  int peakRating = 1000;
  int longestStreak = 0;
  int gamesPlayed = 0;
  int missionsCompleted = 0;
  int misconceptionsRepaired = 0;
  DateTime? lastActiveDay;

  /// Best score per arcade mode.
  final Map<String, int> personalBests = {};

  // Today's activity (daily_activity table).
  DateTime activityDay = _today();
  int todayXp = 0;
  int todayQuestions = 0;
  int todayCorrect = 0;
  int todaySessions = 0;
  int todaySeconds = 0;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _rollDay() {
    final t = _today();
    if (t == activityDay) return;
    // Weekly XP (league) resets on Monday even if the app stayed open.
    DateTime monday(DateTime d) => d.subtract(Duration(days: d.weekday - 1));
    if (monday(t) != monday(activityDay)) weeklyXp = 0;
    activityDay = t;
    todayXp = todayQuestions = todayCorrect = todaySessions = todaySeconds = 0;
  }

  final Map<String, ConceptProgress> progress = {};
  List<MissionTask> mission = [];
  bool missionBonusClaimed = false;
  final Set<String> badges = {};

  // Focus-intervention signals.
  final Map<String, int> postponeCounts = {};
  int comfortSessions = 0;
  bool comfortNudgeShown = false;

  /// Where events are recorded (null = nowhere, offline mode).
  GameEventSink? events;

  ConceptProgress progressOf(String conceptId) =>
      progress.putIfAbsent(conceptId, ConceptProgress.new);

  int get level {
    var l = 1;
    while (xp >= xpForLevel(l + 1)) {
      l++;
    }
    return l;
  }

  double get levelProgress {
    final lo = xpForLevel(level), hi = xpForLevel(level + 1);
    return (xp - lo) / (hi - lo);
  }

  double get accuracy => answered == 0 ? 0 : correctAnswers / answered;

  int get missionMinutes => mission.fold(0, (s, t) => s + t.minutes);
  bool get missionDone => mission.isNotEmpty && mission.every((t) => t.done);

  // ---------------------------------------------------------------- session

  /// Resets state for [user]. [seedDemo] fills the knowledge map with sample
  /// progress for the offline mock; real accounts load theirs from the backend.
  void signIn(AppUser user, {bool seedDemo = true}) {
    userId = user.id;
    displayName = user.displayName;
    onboarded = !user.isNew;
    xp = user.xp;
    weeklyXp = (user.xp * 0.2).round();
    streak = user.streak;
    rating = user.rating;
    lastActiveDay = null;
    goal = null;
    peakRating = rating;
    longestStreak = streak;
    gamesPlayed = missionsCompleted = misconceptionsRepaired = 0;
    personalBests.clear();
    activityDay = _today();
    todayXp = todayQuestions = todayCorrect = todaySessions = todaySeconds = 0;
    progress.clear();
    badges.clear();
    postponeCounts.clear();
    comfortSessions = 0;
    comfortNudgeShown = false;
    missionBonusClaimed = false;
    answered = correctAnswers = bestCombo = 0;
    if (seedDemo && !user.isNew) _seedDemoProgress();
    mission = buildMission();
    notifyListeners();
  }

  void completeOnboarding({
    required String goal,
    required Set<String> subjects,
    required int minutes,
  }) {
    this.goal = goal;
    this.subjects = subjects;
    dailyMinutes = minutes;
    onboarded = true;
    mission = buildMission();
    notifyListeners();
  }

  /// Applies externally loaded state (e.g. from the backend) in one update.
  void restore(void Function() apply) {
    apply();
    notifyListeners();
  }

  void setDailyMinutes(int minutes) {
    dailyMinutes = minutes;
    if (!mission.any((t) => t.done)) mission = buildMission();
    notifyListeners();
  }

  /// A returning player with a realistic, colourful knowledge graph.
  void _seedDemoProgress() {
    final now = DateTime.now();
    DateTime ago(int days) => now.subtract(Duration(days: days));
    progress.addAll({
      'algebra': ConceptProgress(
        mastery: 0.9,
        stabilityDays: 6,
        lastReview: ago(9),
        attempts: 12,
      ),
      'exponents': ConceptProgress(
        mastery: 0.85,
        stabilityDays: 12,
        lastReview: ago(2),
        attempts: 9,
      ),
      'functions': ConceptProgress(
        mastery: 0.82,
        stabilityDays: 5,
        lastReview: ago(7),
        attempts: 8,
      ),
      'composition': ConceptProgress(
        mastery: 0.45,
        lastReview: ago(1),
        attempts: 5,
        misconception: 'You tend to apply the outer function first.',
      ),
      'limits': ConceptProgress(
        mastery: 0.55,
        stabilityDays: 4,
        lastReview: ago(3),
        attempts: 6,
      ),
      'derivatives': ConceptProgress(
        mastery: 0.8,
        stabilityDays: 8,
        lastReview: ago(1),
        attempts: 7,
      ),
      'power_rule': ConceptProgress(
        mastery: 0.6,
        stabilityDays: 3,
        lastReview: ago(4),
        attempts: 5,
      ),
      'chain_rule': ConceptProgress(
        mastery: 0.4,
        stabilityDays: 2,
        lastReview: ago(2),
        attempts: 4,
      ),
    });
    answered = 64;
    correctAnswers = 47;
    bestCombo = 4;
    badges.addAll(['first_blitz']);
  }

  // ---------------------------------------------------------------- mission

  /// Builds a focused mission from the current knowledge graph:
  /// repair → review fading → learn next → exam practice → explain.
  List<MissionTask> buildMission() {
    final now = DateTime.now();
    final studied = concepts
        .where((c) => progressOf(c.id).attempts > 0)
        .toList();

    if (studied.isEmpty) {
      return [
        MissionTask(
          type: TaskType.placement,
          title: 'Placement blitz',
          subtitle: 'Find your starting rating',
          conceptIds: concepts.take(6).map((c) => c.id).toList(),
          minutes: 5,
        ),
        MissionTask(
          type: TaskType.learn,
          title: 'Learn: ${concepts.first.name}',
          subtitle: '5-min lesson + blitz',
          conceptIds: [concepts.first.id],
          minutes: 8,
        ),
      ];
    }

    final tasks = <MissionTask>[];

    final boss = bossConcept;
    if (boss != null) {
      tasks.add(
        MissionTask(
          type: TaskType.boss,
          title: 'Boss fight: ${boss.name}',
          subtitle: 'You keep postponing this · 2× XP',
          conceptIds: [boss.id],
          minutes: 5,
        ),
      );
    }

    final red = concepts
        .where((c) => progressOf(c.id).status == ConceptStatus.misconception)
        .toList();
    if (red.isNotEmpty && red.first != boss) {
      tasks.add(
        MissionTask(
          type: TaskType.repair,
          title: 'Repair: ${red.first.name}',
          subtitle: 'Fix 1 misconception',
          conceptIds: [red.first.id],
          minutes: 8,
        ),
      );
    }

    final fading = studied.where((c) => progressOf(c.id).isFading(now)).toList()
      ..sort(
        (a, b) => progressOf(
          a.id,
        ).recall(now).compareTo(progressOf(b.id).recall(now)),
      );
    if (fading.isNotEmpty) {
      final pick = fading.take(3).toList();
      tasks.add(
        MissionTask(
          type: TaskType.review,
          title:
              'Review ${pick.length} fading concept${pick.length > 1 ? 's' : ''}',
          subtitle: pick.map((c) => c.name).join(' · '),
          conceptIds: pick.map((c) => c.id).toList(),
          minutes: 2 * pick.length,
        ),
      );
    }

    final next = frontier;
    if (next != null) {
      tasks.add(
        MissionTask(
          type: TaskType.learn,
          title: 'Learn: ${next.name}',
          subtitle: '5-min lesson + blitz',
          conceptIds: [next.id],
          minutes: 10,
        ),
      );
    }

    final weak =
        studied
            .where((c) => progressOf(c.id).status == ConceptStatus.weak)
            .toList()
          ..sort(
            (a, b) =>
                progressOf(a.id).mastery.compareTo(progressOf(b.id).mastery),
          );
    if (weak.isNotEmpty) {
      tasks.add(
        MissionTask(
          type: TaskType.exam,
          title: 'Complete 2 exam questions',
          subtitle: weak.take(2).map((c) => c.name).join(' · '),
          conceptIds: weak.take(2).map((c) => c.id).toList(),
          minutes: 6,
        ),
      );
    }

    final mastered = studied
        .where((c) => progressOf(c.id).status == ConceptStatus.mastered)
        .toList();
    if (mastered.isNotEmpty) {
      final c = mastered[math.Random().nextInt(mastered.length)];
      tasks.add(
        MissionTask(
          type: TaskType.explain,
          title: 'Explain 1 concept aloud',
          subtitle: c.name,
          conceptIds: [c.id],
          minutes: 5,
        ),
      );
    }

    // Fit the student's daily budget, but always keep at least two tasks.
    final fitted = <MissionTask>[];
    var total = 0;
    for (final t in tasks) {
      if (fitted.length >= 2 && total + t.minutes > dailyMinutes) continue;
      fitted.add(t);
      total += t.minutes;
    }
    return fitted;
  }

  /// First unstudied concept whose prerequisites have all been studied.
  Concept? get frontier {
    for (final c in concepts) {
      if (progressOf(c.id).attempts > 0) continue;
      if (c.prereqs.every((p) => progressOf(p).attempts > 0)) return c;
    }
    return null;
  }

  /// Generator difficulty 1–3 from how well the concept is known.
  int levelFor(String conceptId) {
    final m = progressOf(conceptId).mastery;
    return m < 0.4 ? 1 : (m < 0.75 ? 2 : 3);
  }

  /// Freshly generated questions for a mission task.
  List<Question> questionsForTask(MissionTask task) {
    final ids = task.conceptIds;
    switch (task.type) {
      case TaskType.placement:
      case TaskType.review:
        return [
          for (final id in ids) questionGen.forConcept(id, level: levelFor(id)),
        ];
      case TaskType.exam:
        return questionGen.batch(ids, 2, level: 3);
      case TaskType.repair:
      case TaskType.boss:
        return questionGen.batch(ids, 5, level: levelFor(ids.first));
      case TaskType.learn:
      case TaskType.explain:
        return questionGen.batch(ids, 4, level: 1);
    }
  }

  /// [count] fresh questions for free practice on one concept.
  List<Question> practiceQuestions(String conceptId, [int count = 5]) =>
      questionGen.batch([conceptId], count, level: levelFor(conceptId));

  /// Concepts the player has met (or the first few, for a brand-new player).
  List<String> get unlockedConceptIds {
    final seen = [
      for (final c in concepts)
        if (progressOf(c.id).attempts > 0) c.id,
    ];
    if (seen.length >= 2) return seen;
    return concepts.take(3).map((c) => c.id).toList();
  }

  /// A random fresh question from the player's unlocked concepts.
  Question randomQuestion({int? level}) {
    final ids = unlockedConceptIds;
    final id = ids[math.Random().nextInt(ids.length)];
    return questionGen.forConcept(id, level: level ?? levelFor(id));
  }

  void postpone(MissionTask task) {
    for (final id in task.conceptIds) {
      final n = postponeCounts[id] = (postponeCounts[id] ?? 0) + 1;
      events?.onFocus(
        'postpone',
        conceptId: id,
        data: {'count': n, 'task': task.type.name},
      );
      if (n == 3) events?.onFocus('boss_unlocked', conceptId: id);
    }
    // Move it to the end of the list.
    mission
      ..remove(task)
      ..add(task);
    notifyListeners();
  }

  // ------------------------------------------------------ focus interventions

  /// A concept postponed 3+ times becomes a boss fight.
  Concept? get bossConcept {
    for (final e in postponeCounts.entries) {
      if (e.value >= 3) return conceptById[e.key];
    }
    return null;
  }

  /// Two sessions in a row on only mastered concepts.
  bool get inComfortZone => comfortSessions >= 2;

  Concept? get weakestConcept {
    final candidates =
        concepts
            .where((c) => progressOf(c.id).attempts > 0)
            .where((c) => progressOf(c.id).status != ConceptStatus.mastered)
            .toList()
          ..sort(
            (a, b) =>
                progressOf(a.id).mastery.compareTo(progressOf(b.id).mastery),
          );
    return candidates.isEmpty ? null : candidates.first;
  }

  // ---------------------------------------------------------------- answers

  SessionSummary startSession(
    String title,
    int total, {
    String mode = 'blitz',
  }) => SessionSummary(
    title: title,
    total: total,
    ratingBefore: rating,
    levelBefore: level,
    mode: mode,
  );

  /// Adds XP from any source and records where it came from.
  void awardXp(SessionSummary? session, int amount, String source) {
    if (amount <= 0) return;
    _rollDay();
    xp += amount;
    weeklyXp += amount;
    todayXp += amount;
    session?.xp += amount;
    events?.onXp(session, amount, source);
    notifyListeners();
  }

  /// Scores one answer. [chosen] is -1 when the timer ran out.
  AnswerResult answer({
    required Question question,
    required int chosen,
    required Duration taken,
    required Duration limit,
    required int combo,
    required SessionSummary session,
    int xpMultiplier = 1,

    /// Duels rate the whole match instead of each answer.
    bool rated = true,
  }) {
    _rollDay();
    final p = progressOf(question.conceptId);
    final correct = chosen == question.answer;
    final now = DateTime.now();

    // Elo update against the question's own difficulty.
    final expected =
        1 / (1 + math.pow(10, (question.difficulty - rating) / 400));
    final delta = rated ? (32 * ((correct ? 1 : 0) - expected)).round() : 0;
    rating = math.max(100, rating + delta);
    peakRating = math.max(peakRating, rating);

    var gained = 0;
    Diagnosis? diagnosis;
    Concept? repaired;

    p.attempts++;
    if (correct) {
      final comboMult = 1 + 0.2 * math.min(combo, 5);
      final fast = taken.inMilliseconds < limit.inMilliseconds / 2;
      gained = ((10 * comboMult + (fast ? 5 : 0)) * xpMultiplier).round();
      // Successful recall boosts mastery and makes the memory more stable.
      p.mastery += (1 - p.mastery) * 0.25;
      p.stabilityDays = math.min(60, p.stabilityDays * 1.6);
      if (p.misconception != null && ++p.repairStreak >= 2) {
        p.misconception = null;
        p.repairStreak = 0;
        p.mastery = math.max(p.mastery, 0.6);
        repaired = conceptById[question.conceptId];
        session.repaired.add(repaired!);
        misconceptionsRepaired++;
        events?.onRepaired(session, repaired);
      }
    } else {
      p.mastery *= 0.75;
      p.stabilityDays = math.max(1, p.stabilityDays * 0.6);
      p.repairStreak = 0;
      final trap = question.traps[chosen];
      if (trap != null) {
        // Blame the root-cause concept, which may be a prerequisite.
        final root = progressOf(trap.rootCause);
        root.misconception = trap.explanation;
        root.attempts = math.max(root.attempts, 1);
        root.repairStreak = 0;
        diagnosis = Diagnosis(
          question: question,
          rootCause: conceptById[trap.rootCause]!,
          explanation: trap.explanation,
        );
        session.diagnoses.add(diagnosis);
        events?.onMisconception(session, diagnosis);
      }
    }
    p.lastReview = now;
    events?.onAttempt(session, question, chosen, correct, taken, delta);

    answered++;
    todayQuestions++;
    if (correct) {
      correctAnswers++;
      todayCorrect++;
    }
    session
      ..correct += correct ? 1 : 0
      ..conceptIds.add(question.conceptId);
    if (gained > 0) {
      awardXp(session, gained, session.mode);
    } else {
      notifyListeners();
    }

    return AnswerResult(
      correct: correct,
      xp: gained,
      ratingDelta: delta,
      diagnosis: diagnosis,
      repaired: repaired,
    );
  }

  /// A mental-maths answer (Number Crunch): XP and stats, no concept.
  void recordArithmetic({
    required SessionSummary session,
    required String prompt,
    required int answer,
    required int? given,
    required Duration taken,
    required int combo,
  }) {
    _rollDay();
    final correct = given == answer;
    answered++;
    todayQuestions++;
    if (correct) {
      correctAnswers++;
      todayCorrect++;
      session.correct++;
    }
    events?.onArithmetic(session, prompt, answer, given, correct, taken);
    if (correct) {
      awardXp(session, 3 + math.min(combo, 5), 'crunch');
    } else {
      notifyListeners();
    }
  }

  /// Elo update for a whole match against an opponent rated [opponent].
  /// [score] is 1 for a win, 0.5 for a draw, 0 for a loss.
  int applyMatchResult(int opponent, double score) {
    final expected = 1 / (1 + math.pow(10, (opponent - rating) / 400));
    final delta = (40 * (score - expected)).round();
    rating = math.max(100, rating + delta);
    peakRating = math.max(peakRating, rating);
    notifyListeners();
    return delta;
  }

  /// Explaining a concept aloud refreshes memory; XP per key point covered.
  void recordExplanation(
    SessionSummary session,
    String conceptId,
    int covered, {
    int seconds = 0,
    int total = 0,
  }) {
    final p = progressOf(conceptId)
      ..lastReview = DateTime.now()
      ..attempts += 1;
    p.stabilityDays = math.min(60, p.stabilityDays * (1 + 0.2 * covered));
    session
      ..correct = covered
      ..conceptIds.add(conceptId);
    events?.onExplanation(session, conceptId, seconds, covered, total);
    awardXp(session, covered * 10, 'explain');
  }

  /// Called once a blitz (or explain task) ends.
  void finishSession(SessionSummary session, {MissionTask? task}) {
    _rollDay();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = lastActiveDay;
    if (last != today) {
      // Only consecutive days extend the streak; a gap starts a new one.
      // (Rounded hours, not inDays, so a DST change can't skew it.)
      final gap = last == null
          ? null
          : (today.difference(last).inHours / 24).round();
      // No last day (new player / offline demo) just continues the count.
      streak = gap == null || gap == 1 ? streak + 1 : 1;
      lastActiveDay = today;
    }
    longestStreak = math.max(longestStreak, streak);
    bestCombo = math.max(bestCombo, session.bestCombo);
    gamesPlayed++;
    todaySessions++;
    todaySeconds += now.difference(session.startedAt).inSeconds;

    // Personal bests for scored arcade modes.
    final score = session.score;
    if (score != null) {
      final prev = personalBests[session.mode];
      session.previousBest = prev;
      if (prev == null || score > prev) {
        personalBests[session.mode] = score;
        session.isNewBest = prev != null || score > 0;
      }
    }

    // Comfort-zone detector.
    final allMastered =
        session.conceptIds.isNotEmpty &&
        session.conceptIds.every(
          (id) => progressOf(id).status == ConceptStatus.mastered,
        );
    final wasNudged = inComfortZone;
    comfortSessions = allMastered ? comfortSessions + 1 : 0;
    if (comfortSessions == 2) events?.onFocus('comfort_nudge');

    if (task != null) {
      task.done = true;
      if (task.type == TaskType.boss) {
        postponeCounts.remove(task.conceptIds.first);
        events?.onFocus('boss_defeated', conceptId: task.conceptIds.first);
        _award('boss', session);
      }
    }

    if (!missionBonusClaimed && missionDone) {
      missionBonusClaimed = true;
      session.missionCompleted = true;
      missionsCompleted++;
      awardXp(session, 50, 'mission_bonus');
      _award('mission', session);
    }

    _award('first_blitz', session);
    if (session.bestCombo >= 5) _award('combo5', session);
    if (session.repaired.isNotEmpty) _award('slayer', session);
    if (wasNudged && !allMastered) _award('comfort', session);
    if (session.total >= 3 && session.correct == session.total) {
      _award('perfect', session);
    }
    if (level >= 5) _award('level5', session);
    _awardArcadeBadges(session);

    session.ratingAfter = rating;
    events?.onSessionFinished(session, task);
    notifyListeners();
  }

  void _awardArcadeBadges(SessionSummary s) {
    final score = s.score ?? 0;
    switch (s.mode) {
      case 'rush' when score >= 15:
        _award('speed_demon', s);
      case 'survival' when score >= 15:
        _award('survivor', s);
      case 'crunch' when score >= 20:
        _award('number_cruncher', s);
      case 'truefalse' when score >= 15:
        _award('lie_detector', s);
      case 'memory' when s.total <= 10:
        _award('sharp_memory', s);
      case 'duel' when s.outcome == 'win':
        _award('duelist', s);
    }
    const arcade = [
      'rush',
      'truefalse',
      'crunch',
      'survival',
      'memory',
      'duel',
    ];
    if (arcade.every(personalBests.containsKey)) _award('arcade_master', s);
  }

  /// Tomorrow's plan, rebuilt from today's performance.
  List<MissionTask> previewTomorrow() => buildMission();

  void startNextMission() {
    mission = buildMission();
    missionBonusClaimed = false;
    notifyListeners();
  }

  void _award(String id, SessionSummary session) {
    if (badges.add(id)) {
      final badge = allBadges.firstWhere((b) => b.id == id);
      session.newBadges.add(badge);
      events?.onBadge(session, badge);
    }
  }
}

/// Single shared instance until a DI solution (Riverpod) is added.
final gameState = GameState();
