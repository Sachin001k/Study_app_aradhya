import 'package:aradhya/features/auth/data/auth_repository.dart';
import 'package:aradhya/features/game/game_state.dart';
import 'package:aradhya/features/game/progress_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AppUser(
    id: 'u1',
    email: 'a@b.co',
    displayName: 'Asha',
    xp: 1240,
  );
  final now = DateTime(2026, 10, 16, 14); // a Friday

  test('week starts on Monday', () {
    expect(ProgressCodec.weekStart(now), DateTime(2026, 10, 12));
  });

  test('profile and stats survive a save/load round trip', () {
    final a = GameState()..signIn(user);
    a
      ..goal = 'JEE'
      ..dailyMinutes = 20
      ..streak = 6
      ..longestStreak = 9
      ..peakRating = 1300
      ..gamesPlayed = 12
      ..lastActiveDay = DateTime(2026, 10, 15)
      ..postponeCounts['limits'] = 2;

    final b = GameState()..signIn(user, seedDemo: false);
    ProgressCodec.applyProfile(b, ProgressCodec.profileRow(a, now));
    ProgressCodec.applyStats(b, ProgressCodec.statsRow(a, now), now);
    expect(b.goal, 'JEE');
    expect(b.dailyMinutes, 20);
    expect(b.onboarded, isTrue);
    expect(b.xp, a.xp);
    expect(b.rating, a.rating);
    expect(b.streak, 6);
    expect(b.longestStreak, 9);
    expect(b.peakRating, 1300);
    expect(b.gamesPlayed, 12);
    expect(b.postponeCounts['limits'], 2);
  });

  test('missing a day resets the streak; a new week resets weekly XP', () {
    final a = GameState()..signIn(user);
    a
      ..streak = 9
      ..weeklyXp = 300
      ..lastActiveDay = DateTime(2026, 10, 13);
    final row = ProgressCodec.statsRow(a, DateTime(2026, 10, 13));

    final b = GameState()..signIn(user, seedDemo: false);
    ProgressCodec.applyStats(b, row, DateTime(2026, 10, 20)); // next Tuesday
    expect(b.streak, 0);
    expect(b.weeklyXp, 0);
  });

  test('concept progress, mission tasks and daily activity round trip', () {
    final a = GameState()..signIn(user);
    final p = a.progressOf('composition');
    final back = ProgressCodec.progressFromRow(
      ProgressCodec.progressRow('u1', 'composition', p, now),
    );
    expect(back.mastery, closeTo(p.mastery, 1e-9));
    expect(back.misconception, p.misconception);
    expect(back.status, p.status);

    a.mission.first.done = true;
    final rows = ProgressCodec.taskRows(
      'u1',
      now,
      a.mission,
      now,
    ).reversed.toList();
    final tasks = ProgressCodec.tasksFromRows(rows);
    expect(tasks.map((t) => t.title), a.mission.map((t) => t.title));
    expect(tasks.first.done, isTrue);
    expect(tasks.first.type, a.mission.first.type);

    a
      ..todayXp = 120
      ..todayQuestions = 14;
    final c = GameState();
    ProgressCodec.applyDaily(c, ProgressCodec.dailyRow(a, now));
    expect(c.todayXp, 120);
    expect(c.todayQuestions, 14);
  });

  test('session and attempt rows carry generated question details', () {
    final g = GameState()..signIn(user);
    final s = g.startSession('Speed Rush', 0, mode: 'rush');
    final q = g.randomQuestion();
    g.answer(
      question: q,
      chosen: q.answer,
      taken: const Duration(seconds: 2),
      limit: const Duration(seconds: 8),
      combo: 0,
      session: s,
    );
    s.score = s.correct;
    g.finishSession(s);

    final att = ProgressCodec.attemptRow(
      'u1',
      s,
      q,
      q.answer,
      true,
      const Duration(seconds: 2),
      5,
    );
    expect(att['session_id'], s.id);
    expect(att['options'], q.options);
    expect(att['given_answer'], att['correct_answer']);

    final row = ProgressCodec.sessionRow('u1', s, null, DateTime.now());
    expect(row['mode'], 'rush');
    expect(row['score'], 1);
    expect(row['rating_after'], g.rating);
    expect(g.personalBests['rush'], 1);
  });
}
