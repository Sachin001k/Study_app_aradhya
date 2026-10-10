import 'package:aradhya/features/auth/data/auth_repository.dart';
import 'package:aradhya/features/game/content.dart';
import 'package:aradhya/features/game/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const returning = AppUser(
    id: 'u',
    email: 'a@b.co',
    displayName: 'Asha',
    xp: 1240,
  );
  const newbie = AppUser(
    id: 'n',
    email: 'n@b.co',
    displayName: 'New',
    isNew: true,
  );

  Question q(String id) => questions.firstWhere((q) => q.id == id);

  AnswerResult play(GameState g, String id, int chosen) => g.answer(
    question: q(id),
    chosen: chosen,
    taken: const Duration(seconds: 5),
    limit: const Duration(seconds: 30),
    combo: 0,
    session: g.startSession('t', 1),
  );

  test('every question answer and trap index is in range', () {
    for (final q in questions) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1), reason: q.id);
      for (final i in q.traps.keys) {
        expect(i, isNot(q.answer), reason: q.id);
        expect(conceptById.containsKey(q.traps[i]!.rootCause), isTrue);
      }
    }
  });

  test('a wrong chain-rule answer can blame a prerequisite concept', () {
    final g = GameState()..signIn(returning);
    // Option 3 of chn2 reveals a composition misconception.
    final r = play(g, 'chn2', 3);
    expect(r.correct, isFalse);
    expect(r.diagnosis!.rootCause.id, 'composition');
    expect(g.progressOf('composition').status, ConceptStatus.misconception);
  });

  test('two correct answers in a row repair a misconception', () {
    final g = GameState()..signIn(returning);
    expect(g.progressOf('composition').status, ConceptStatus.misconception);
    play(g, 'cmp1', 1);
    final r = play(g, 'cmp2', 2);
    expect(r.repaired?.id, 'composition');
    expect(g.progressOf('composition').misconception, isNull);
  });

  test('rating rises on correct answers and XP is awarded', () {
    final g = GameState()..signIn(returning);
    final before = g.rating;
    final r = play(g, 'chn1', 1);
    expect(r.ratingDelta, greaterThan(0));
    expect(g.rating, before + r.ratingDelta);
    expect(r.xp, greaterThan(0));
  });

  test('new players start with a placement blitz', () {
    final g = GameState()..signIn(newbie);
    expect(g.mission.first.type, TaskType.placement);
  });

  test('returning players get repair + review tasks', () {
    final g = GameState()..signIn(returning);
    final types = g.mission.map((t) => t.type).toSet();
    expect(types, containsAll([TaskType.repair, TaskType.review]));
  });

  test('postponing a topic 3 times creates a boss fight', () {
    final g = GameState()..signIn(returning);
    final task = g.mission.first;
    for (var i = 0; i < 3; i++) {
      g.postpone(task);
    }
    expect(g.bossConcept?.id, task.conceptIds.first);
  });

  test('finishing every mission task pays the bonus once', () {
    final g = GameState()..signIn(returning);
    final xpBefore = g.xp;
    for (final t in List.of(g.mission)) {
      g.finishSession(g.startSession('t', 0), task: t);
    }
    expect(g.missionDone, isTrue);
    expect(g.xp, xpBefore + 50);
    expect(g.badges, contains('mission'));
  });
}
