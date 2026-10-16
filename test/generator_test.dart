import 'dart:math' as math;

import 'package:aradhya/features/game/content.dart';
import 'package:aradhya/features/game/generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every concept generates valid, varied questions', () {
    final gen = QuestionGenerator(math.Random(1));
    for (final c in concepts) {
      final prompts = <String>{};
      for (var i = 0; i < 400; i++) {
        final q = gen.forConcept(c.id, level: 1 + i % 3);
        prompts.add(q.prompt);
        expect(q.conceptId, c.id);
        expect(q.options.length, 4, reason: q.prompt);
        expect(q.options.toSet().length, 4, reason: '${q.prompt} ${q.options}');
        expect(q.answer, inInclusiveRange(0, 3));
        expect(q.traps.containsKey(q.answer), isFalse, reason: q.prompt);
        for (final t in q.traps.values) {
          expect(conceptById.containsKey(t.rootCause), isTrue);
        }
        for (final o in q.options) {
          expect(o.contains('+ −'), isFalse, reason: o);
          expect(RegExp(r'(^|[^0-9])1x').hasMatch(o), isFalse, reason: o);
        }
      }
      expect(prompts.length, greaterThan(15), reason: '${c.id} lacks variety');
    }
  });

  test('batch has no duplicate prompts', () {
    final qs = QuestionGenerator().batch(['algebra', 'chain_rule'], 10);
    expect(qs.map((q) => q.prompt).toSet().length, qs.length);
  });

  test('arcade generators: statements, arithmetic, pairs', () {
    final gen = QuestionGenerator(math.Random(3));
    for (var i = 0; i < 300; i++) {
      final s = gen.statement(['chain_rule', 'exponents', 'limits']);
      expect(s.isTrue, s.shown == s.question.answer);
      final a = gen.arithmetic(1 + i % 5);
      expect(a.answer, greaterThanOrEqualTo(0), reason: a.prompt);
    }
    for (var i = 0; i < 50; i++) {
      final p = gen.pairs(6);
      expect(p.length, 6);
      final all = [
        for (final (l, r) in p) ...[l, r],
      ];
      expect(all.toSet().length, 12, reason: '$p');
    }
  });

  test('linear formatting', () {
    expect(linear(1, 0), 'x');
    expect(linear(-1, 3), '−x + 3');
    expect(linear(2, -5), '2x − 5');
    expect(linear(0, 4), '4');
  });
}
