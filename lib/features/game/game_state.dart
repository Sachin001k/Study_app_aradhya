import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../auth/data/auth_repository.dart';
import 'content.dart';

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
  });

  final String title;
  final int total;
  final int ratingBefore;
  final int levelBefore;
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
];

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
  String displayName = 'Player';
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
  DateTime? lastActiveDay;

  final Map<String, ConceptProgress> progress = {};
  List<MissionTask> mission = [];
  bool missionBonusClaimed = false;
  final Set<String> badges = {};

  // Focus-intervention signals.
  final Map<String, int> postponeCounts = {};
  int comfortSessions = 0;
  bool comfortNudgeShown = false;

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

  void signIn(AppUser user) {
    displayName = user.displayName;
    xp = user.xp;
    weeklyXp = (user.xp * 0.2).round();
    streak = user.streak;
    rating = user.rating;
    progress.clear();
    badges.clear();
    postponeCounts.clear();
    comfortSessions = 0;
    comfortNudgeShown = false;
    missionBonusClaimed = false;
    if (user.isNew) {
      answered = correctAnswers = bestCombo = 0;
    } else {
      _seedDemoProgress();
    }
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
    mission = buildMission();
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

  /// Questions to play for a mission task.
  List<Question> questionsForTask(MissionTask task) {
    final rnd = math.Random();
    List<Question> pool(String id) => questionsFor(id)..shuffle(rnd);
    switch (task.type) {
      case TaskType.placement:
      case TaskType.review:
        return [for (final id in task.conceptIds) pool(id).first];
      case TaskType.exam:
        final all = [for (final id in task.conceptIds) ...questionsFor(id)]
          ..sort((a, b) => b.difficulty.compareTo(a.difficulty));
        return all.take(2).toList();
      case TaskType.repair:
      case TaskType.learn:
      case TaskType.boss:
      case TaskType.explain:
        return pool(task.conceptIds.first);
    }
  }

  void postpone(MissionTask task) {
    for (final id in task.conceptIds) {
      postponeCounts[id] = (postponeCounts[id] ?? 0) + 1;
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

  SessionSummary startSession(String title, int total) => SessionSummary(
    title: title,
    total: total,
    ratingBefore: rating,
    levelBefore: level,
  );

  /// Scores one answer. [chosen] is -1 when the timer ran out.
  AnswerResult answer({
    required Question question,
    required int chosen,
    required Duration taken,
    required Duration limit,
    required int combo,
    required SessionSummary session,
    int xpMultiplier = 1,
  }) {
    final p = progressOf(question.conceptId);
    final correct = chosen == question.answer;
    final now = DateTime.now();

    // Elo update against the question's own difficulty.
    final expected =
        1 / (1 + math.pow(10, (question.difficulty - rating) / 400));
    final delta = (32 * ((correct ? 1 : 0) - expected)).round();
    rating = math.max(100, rating + delta);

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
      }
    }
    p.lastReview = now;

    answered++;
    if (correct) correctAnswers++;
    xp += gained;
    weeklyXp += gained;
    session
      ..xp += gained
      ..correct += correct ? 1 : 0
      ..conceptIds.add(question.conceptId);
    notifyListeners();

    return AnswerResult(
      correct: correct,
      xp: gained,
      ratingDelta: delta,
      diagnosis: diagnosis,
      repaired: repaired,
    );
  }

  /// Explaining a concept aloud refreshes memory; XP per key point covered.
  void recordExplanation(
    SessionSummary session,
    String conceptId,
    int covered,
  ) {
    final gained = covered * 10;
    final p = progressOf(conceptId)
      ..lastReview = DateTime.now()
      ..attempts += 1;
    p.stabilityDays = math.min(60, p.stabilityDays * (1 + 0.2 * covered));
    xp += gained;
    weeklyXp += gained;
    session
      ..xp += gained
      ..correct = covered
      ..conceptIds.add(conceptId);
    notifyListeners();
  }

  /// Called once a blitz (or explain task) ends.
  void finishSession(SessionSummary session, {MissionTask? task}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (lastActiveDay != today) {
      streak++;
      lastActiveDay = today;
    }
    bestCombo = math.max(bestCombo, session.bestCombo);

    // Comfort-zone detector.
    final allMastered =
        session.conceptIds.isNotEmpty &&
        session.conceptIds.every(
          (id) => progressOf(id).status == ConceptStatus.mastered,
        );
    final wasNudged = inComfortZone;
    comfortSessions = allMastered ? comfortSessions + 1 : 0;

    if (task != null) {
      task.done = true;
      if (task.type == TaskType.boss) {
        postponeCounts.remove(task.conceptIds.first);
        _award('boss', session);
      }
    }

    if (!missionBonusClaimed && missionDone) {
      missionBonusClaimed = true;
      session.missionCompleted = true;
      xp += 50;
      weeklyXp += 50;
      session.xp += 50;
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
    notifyListeners();
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
      session.newBadges.add(allBadges.firstWhere((b) => b.id == id));
    }
  }
}

/// Single shared instance until a DI solution (Riverpod) is added.
final gameState = GameState();
