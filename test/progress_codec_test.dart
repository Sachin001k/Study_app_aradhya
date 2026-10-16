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

  test('profile survives a save/load round trip', () {
    final a = GameState()..signIn(user);
    a
      ..goal = 'JEE'
      ..dailyMinutes = 20
      ..streak = 6
      ..lastActiveDay = DateTime(2026, 10, 15)
      ..badges.add('combo5')
      ..postponeCounts['limits'] = 2;
    final row = ProgressCodec.profileRow(a, now);

    final b = GameState()..signIn(user, seedDemo: false);
    ProgressCodec.applyProfile(b, row, now);
    expect(b.goal, 'JEE');
    expect(b.dailyMinutes, 20);
    expect(b.xp, a.xp);
    expect(b.rating, a.rating);
    expect(b.streak, 6);
    expect(b.badges, containsAll(['combo5', 'first_blitz']));
    expect(b.postponeCounts['limits'], 2);
    expect(b.onboarded, isTrue);
  });

  test('missing a day resets the streak; a new week resets weekly XP', () {
    final a = GameState()..signIn(user);
    a
      ..streak = 9
      ..weeklyXp = 300
      ..lastActiveDay = DateTime(2026, 10, 13);
    final row = ProgressCodec.profileRow(a, DateTime(2026, 10, 13));

    final b = GameState()..signIn(user, seedDemo: false);
    ProgressCodec.applyProfile(b, row, DateTime(2026, 10, 20)); // next Tuesday
    expect(b.streak, 0);
    expect(b.weeklyXp, 0);
  });

  test('concept progress and missions round trip', () {
    final a = GameState()..signIn(user);
    final p = a.progressOf('composition');
    final back = ProgressCodec.progressFromRow(
      ProgressCodec.progressRow('u1', 'composition', p, now),
    );
    expect(back.mastery, closeTo(p.mastery, 1e-9));
    expect(back.misconception, p.misconception);
    expect(back.status, p.status);

    a.mission.first.done = true;
    final tasks = ProgressCodec.tasksFromJson(
      ProgressCodec.tasksToJson(a.mission),
    );
    expect(tasks.map((t) => t.title), a.mission.map((t) => t.title));
    expect(tasks.first.done, isTrue);
    expect(tasks.first.type, a.mission.first.type);
  });
}
