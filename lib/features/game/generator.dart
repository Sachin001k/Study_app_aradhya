import 'dart:math' as math;

import 'content.dart';

/// Procedural question generator. Every call produces fresh numbers, while
/// each wrong option is still tagged with the misconception it reveals, so
/// root-cause diagnosis keeps working on generated questions.
class QuestionGenerator {
  QuestionGenerator([math.Random? random]) : _r = random ?? math.Random();

  final math.Random _r;
  int _seq = 0;

  /// A fresh question for [conceptId]. [level] 1–3 scales number size and
  /// difficulty rating. Occasionally mixes in a hand-written question.
  Question forConcept(String conceptId, {int level = 2}) {
    final handWritten = questionsFor(conceptId);
    if (handWritten.isNotEmpty && _r.nextDouble() < 0.15) {
      return handWritten[_r.nextInt(handWritten.length)];
    }
    final templates = _templates[conceptId]!;
    return templates[_r.nextInt(templates.length)](this, level.clamp(1, 3));
  }

  /// [count] questions spread over [conceptIds], no two prompts alike.
  List<Question> batch(List<String> conceptIds, int count, {int level = 2}) {
    final out = <Question>[];
    final prompts = <String>{};
    var guard = 0;
    while (out.length < count && guard++ < count * 20) {
      final q = forConcept(
        conceptIds[out.length % conceptIds.length],
        level: level,
      );
      if (prompts.add(q.prompt)) out.add(q);
    }
    return out;
  }

  /// A True/False statement built from a generated question: either its
  /// correct answer or (often) a trap answer. [shown] is the option index.
  ({String text, bool isTrue, Question question, int shown}) statement(
    List<String> conceptIds, {
    int level = 2,
  }) {
    final q = forConcept(_pick(conceptIds), level: level);
    final isTrue = _r.nextBool();
    var shown = q.answer;
    if (!isTrue) {
      final wrong = [
        for (var i = 0; i < q.options.length; i++)
          if (i != q.answer) i,
      ];
      final traps = wrong.where(q.traps.containsKey).toList();
      shown = traps.isNotEmpty && _r.nextDouble() < 0.7
          ? _pick(traps)
          : _pick(wrong);
    }
    final p = q.prompt;
    final text = p.endsWith('= ?')
        ? '${p.substring(0, p.length - 1)}${q.options[shown]}'
        : '$p\n→ ${q.options[shown]}';
    return (text: text, isTrue: isTrue, question: q, shown: shown);
  }

  /// Mental-maths drill for Number Crunch; answers are never negative.
  ({String prompt, int answer}) arithmetic(int level) {
    switch (level.clamp(1, 5)) {
      case 1:
        final a = _int(2, 20), b = _int(2, 20);
        return _r.nextBool()
            ? (prompt: '$a + $b', answer: a + b)
            : (
                prompt: '${math.max(a, b)} − ${math.min(a, b)}',
                answer: (a - b).abs(),
              );
      case 2:
        if (_r.nextBool()) {
          final a = _int(2, 12), b = _int(2, 10);
          return (prompt: '$a × $b', answer: a * b);
        }
        final a = _int(20, 99), b = _int(11, 60);
        return _r.nextBool()
            ? (prompt: '$a + $b', answer: a + b)
            : (
                prompt: '${math.max(a, b)} − ${math.min(a, b)}',
                answer: (a - b).abs(),
              );
      case 3:
        if (_r.nextBool()) {
          final a = _int(12, 30), b = _int(3, 9);
          return (prompt: '$a × $b', answer: a * b);
        }
        final b = _int(3, 12), q = _int(3, 15);
        return (prompt: '${b * q} ÷ $b', answer: q);
      case 4:
        if (_r.nextBool()) {
          final n = _int(11, 25);
          return (prompt: '$n²', answer: n * n);
        }
        final pct = _pick([10, 20, 25, 50]), n = 20 * _int(1, 20);
        return (prompt: '$pct% of $n', answer: n * pct ~/ 100);
      default:
        if (_r.nextBool()) {
          final a = _int(6, 15), b = _int(6, 15), c = _int(5, 50);
          return (prompt: '$a × $b + $c', answer: a * b + c);
        }
        final a = _int(150, 999), b = _int(101, 600);
        return _r.nextBool()
            ? (prompt: '$a + $b', answer: a + b)
            : (
                prompt: '${math.max(a, b)} − ${math.min(a, b)}',
                answer: (a - b).abs(),
              );
    }
  }

  /// [count] expression ↔ result pairs for Memory Match, all distinct.
  List<(String, String)> pairs(int count) {
    final makers = <(String, String) Function()>[
      () {
        final a = _int(2, 6), b = _int(2, 6);
        return ('${_pow('x', a)}·${_pow('x', b)}', _pow('x', a + b));
      },
      () {
        final a = _int(2, 4), b = _int(2, 4);
        return ('(${_pow('x', a)})${_sup(b)}', _pow('x', a * b));
      },
      () {
        final n = _int(2, 7);
        return ('d/dx ${_pow('x', n)}', _coef(n, _pow('x', n - 1)));
      },
      () {
        final k = _int(2, 9);
        return ('d/dx sin(${k}x)', '$k cos(${k}x)');
      },
      () {
        final k = _int(2, 9);
        return ('d/dx e^(${k}x)', '${k}e^(${k}x)');
      },
      () {
        final k = _int(2, 9);
        return ('lim x→0 sin(${k}x)/x', '$k');
      },
      () {
        final a = _int(3, 12), b = _int(3, 12);
        return ('$a × $b', '${a * b}');
      },
      () {
        final n = _int(4, 19);
        return ('√${n * n}', '$n');
      },
      () {
        final n = _int(2, 6);
        return ('1/${_pow('x', n)}', _pow('x', -n));
      },
      () => ('d/dx sin x', 'cos x'),
      () => ('d/dx cos x', '−sin x'),
      () {
        final a = _int(2, 9);
        return ('(x + $a)(x − $a)', 'x² − ${a * a}');
      },
    ];
    final out = <(String, String)>[];
    final seen = <String>{};
    var guard = 0;
    while (out.length < count && guard++ < 500) {
      final (l, r) = _pick(makers)();
      if (seen.contains(l) || seen.contains(r)) continue;
      seen
        ..add(l)
        ..add(r);
      out.add((l, r));
    }
    return out;
  }

  // ------------------------------------------------------------ helpers

  int _int(int lo, int hi) => lo + _r.nextInt(hi - lo + 1);
  int _nz(int lo, int hi) {
    int v;
    do {
      v = _int(lo, hi);
    } while (v == 0);
    return v;
  }

  T _pick<T>(List<T> xs) => xs[_r.nextInt(xs.length)];

  /// Builds a shuffled 4-option question. [traps] maps a wrong option to the
  /// misconception it reveals; [fillers] are plain wrong options.
  Question _mcq({
    required String concept,
    required String prompt,
    required String correct,
    required int difficulty,
    required String explanation,
    Map<String, Misconception> traps = const {},
    List<String> fillers = const [],
  }) {
    final wrong = <String>[];
    for (final o in [...traps.keys, ...fillers]) {
      if (o != correct && !wrong.contains(o)) wrong.add(o);
    }
    // Keep traps first so they survive the trim to three wrong options.
    final chosen = wrong.take(3).toList();
    var pad = 1;
    while (chosen.length < 3) {
      final extra = '$correct + ${pad++}';
      if (!chosen.contains(extra)) chosen.add(extra);
    }
    final options = [correct, ...chosen]..shuffle(_r);
    return Question(
      id: 'gen-$concept-${DateTime.now().microsecondsSinceEpoch}-${_seq++}',
      conceptId: concept,
      prompt: prompt,
      options: options,
      answer: options.indexOf(correct),
      difficulty: difficulty,
      explanation: explanation,
      traps: {
        for (var i = 0; i < options.length; i++)
          if (i != options.indexOf(correct) && traps.containsKey(options[i]))
            i: traps[options[i]]!,
      },
    );
  }

  static const _templates =
      <String, List<Question Function(QuestionGenerator, int)>>{
        'algebra': [_distribute, _solveLinear, _expandSquare],
        'exponents': [
          _productOfPowers,
          _powerOfPower,
          _quotientOfPowers,
          _negativePower,
        ],
        'functions': [
          _evaluateLinear,
          _substituteExpression,
          _evaluateNegative,
        ],
        'composition': [_composeSymbolic, _composeNumeric, _innerFunction],
        'limits': [_limitSubstitute, _limitFactor, _limitSinKx, _limitInfinity],
        'derivatives': [_derivConstant, _derivLinear, _tangentSlope],
        'power_rule': [
          _powerMonomial,
          _powerPolynomial,
          _powerReciprocal,
          _powerRoot,
        ],
        'product_rule': [_productTrig, _productExp, _productLinear],
        'chain_rule': [
          _chainLinearPower,
          _chainQuadraticPower,
          _chainExp,
          _chainRoot,
        ],
        'trig_derivs': [_trigSin, _trigCos, _trigCombo],
        'composite_trig': [_sinKx, _cosPower, _sinPower, _sinLinear],
      };

  // ------------------------------------------------------------ algebra

  static Question _distribute(QuestionGenerator g, int lvl) {
    final a = g._int(2, 3 + 2 * lvl),
        b = g._int(1, 4 + 3 * lvl),
        c = g._int(1, a - 1);
    return g._mcq(
      concept: 'algebra',
      prompt: 'Simplify $a(x + $b) − ${_coef(c, 'x')}',
      correct: linear(a - c, a * b),
      difficulty: 850 + 50 * lvl,
      explanation:
          '$a(x + $b) = ${a}x + ${a * b}, then subtract ${_coef(c, 'x')}.',
      traps: {
        linear(a - c, b): const Misconception(
          'algebra',
          'Multiply every term inside the bracket.',
        ),
      },
      fillers: [
        linear(a + c, a * b),
        linear(a - c, a + b),
        linear(a, a * b - c),
      ],
    );
  }

  static Question _solveLinear(QuestionGenerator g, int lvl) {
    final x = g._nz(-3 * lvl - 3, 3 * lvl + 3), a = g._int(2, 3 + 2 * lvl);
    final b = g._nz(-5 * lvl - 5, 5 * lvl + 5), c = a * x + b;
    final traps = <String, Misconception>{};
    if ((c + b) % a == 0) {
      traps['x = ${_n((c + b) ~/ a)}'] = const Misconception(
        'algebra',
        'When moving a term across =, flip its sign.',
      );
    }
    traps['x = ${_n(c - b)}'] = const Misconception(
      'algebra',
      'Divide both sides by the coefficient of x.',
    );
    return g._mcq(
      concept: 'algebra',
      prompt: 'Solve ${linear(a, b)} = ${_n(c)}',
      correct: 'x = ${_n(x)}',
      difficulty: 820 + 60 * lvl,
      explanation: '${a}x = ${_n(c - b)}, so x = ${_n(x)}.',
      traps: traps,
      fillers: ['x = ${_n(-x)}', 'x = ${_n(x + 1)}', 'x = ${_n(x - 2)}'],
    );
  }

  static Question _expandSquare(QuestionGenerator g, int lvl) {
    final a = g._nz(-2 - 2 * lvl, 2 + 2 * lvl);
    final sign = a < 0 ? '−' : '+';
    return g._mcq(
      concept: 'algebra',
      prompt: 'Expand (x $sign ${a.abs()})²',
      correct: _poly({2: 1, 1: 2 * a, 0: a * a}),
      difficulty: 950 + 50 * lvl,
      explanation: '(a + b)² = a² + 2ab + b², here with b = ${_n(a)}.',
      traps: {
        _poly({2: 1, 0: a * a}): const Misconception(
          'algebra',
          '(a + b)² ≠ a² + b² — you lost the 2ab term.',
        ),
        _poly({2: 1, 0: -(a * a)}): const Misconception(
          'algebra',
          'That’s a difference of squares, not a square.',
        ),
      },
      fillers: [
        _poly({2: 1, 1: a, 0: a * a}),
        _poly({1: 2, 0: 2 * a}),
      ],
    );
  }

  // ------------------------------------------------------------ exponents

  static Question _productOfPowers(QuestionGenerator g, int lvl) {
    int a, b;
    do {
      a = g._int(2, 4 + 2 * lvl);
      b = g._int(2, 4 + 2 * lvl);
    } while (a * b == a + b);
    return g._mcq(
      concept: 'exponents',
      prompt: '${_pow('x', a)} · ${_pow('x', b)} = ?',
      correct: _pow('x', a + b),
      difficulty: 900 + 50 * lvl,
      explanation: 'Same base: add the powers, $a + $b = ${a + b}.',
      traps: {
        _pow('x', a * b): const Misconception(
          'exponents',
          'Multiplying powers is for (xᵃ)ᵇ, not xᵃ·xᵇ.',
        ),
      },
      fillers: [
        '2${_pow('x', a + b)}',
        _pow('x', (a - b).abs() + 1),
        '${_pow('x', a)}${_sup(b)}',
      ],
    );
  }

  static Question _powerOfPower(QuestionGenerator g, int lvl) {
    int a, b;
    do {
      a = g._int(2, 3 + lvl);
      b = g._int(2, 3 + lvl);
    } while (a * b == a + b);
    return g._mcq(
      concept: 'exponents',
      prompt: '(${_pow('x', a)})${_sup(b)} = ?',
      correct: _pow('x', a * b),
      difficulty: 950 + 50 * lvl,
      explanation: 'Power of a power: multiply, $a × $b = ${a * b}.',
      traps: {
        _pow('x', a + b): const Misconception(
          'exponents',
          'Adding powers is for xᵃ·xᵇ; here you multiply.',
        ),
      },
      fillers: ['$b${_pow('x', a)}', _pow('x', a * b + 1), '$a${_pow('x', b)}'],
    );
  }

  static Question _quotientOfPowers(QuestionGenerator g, int lvl) {
    final b = g._int(2, 2 + lvl), a = b * g._int(2, 3) + g._int(0, 2);
    final traps = <String, Misconception>{
      _pow('x', a + b): const Misconception(
        'exponents',
        'Dividing powers with the same base subtracts them.',
      ),
    };
    if (a % b == 0 && a ~/ b != a - b) {
      traps[_pow('x', a ~/ b)] = const Misconception(
        'exponents',
        'Subtract the powers — don’t divide them.',
      );
    }
    return g._mcq(
      concept: 'exponents',
      prompt: '${_pow('x', a)} ÷ ${_pow('x', b)} = ?',
      correct: _pow('x', a - b),
      difficulty: 950 + 50 * lvl,
      explanation: 'Same base: subtract the powers, $a − $b = ${a - b}.',
      traps: traps,
      fillers: [
        _pow('x', a * b),
        _pow('x', a - b + 1),
        '1/${_pow('x', a - b)}',
      ],
    );
  }

  static Question _negativePower(QuestionGenerator g, int lvl) {
    final n = g._int(2, 3 + lvl);
    return g._mcq(
      concept: 'exponents',
      prompt: 'Write 1/${_pow('x', n)} as a power of x',
      correct: _pow('x', -n),
      difficulty: 1000 + 50 * lvl,
      explanation: 'A reciprocal flips the sign of the power: 1/xⁿ = x⁻ⁿ.',
      traps: {
        '−${_pow('x', n)}': const Misconception(
          'exponents',
          'A negative power means reciprocal, not a negative number.',
        ),
      },
      fillers: ['x^(1/$n)', 'x^(−1/$n)', _pow('x', n - 1)],
    );
  }

  // ------------------------------------------------------------ functions

  static Question _evaluateLinear(QuestionGenerator g, int lvl) {
    final a = g._nz(-2 - lvl, 3 + 2 * lvl),
        b = g._nz(-4 * lvl, 4 * lvl),
        k = g._nz(-3 * lvl, 3 * lvl + 2);
    return g._mcq(
      concept: 'functions',
      prompt: 'f(x) = ${linear(a, b)}. Find f(${_n(k)})',
      correct: _n(a * k + b),
      difficulty: 850 + 50 * lvl,
      explanation:
          'Replace x with ${_n(k)}: ${_n(a)}·(${_n(k)}) ${b < 0 ? '−' : '+'} ${b.abs()} = ${_n(a * k + b)}.',
      fillers: [_n(a * k), _n(a * (k + b)), _n(a * k - b), _n(a + k + b)],
    );
  }

  static Question _substituteExpression(QuestionGenerator g, int lvl) {
    final k = g._int(1, 2 + lvl), c = g._nz(-5, 5);
    return g._mcq(
      concept: 'functions',
      prompt: 'f(x) = ${_poly({2: 1, 0: c})}. Find f(t + $k)',
      correct: _poly({2: 1, 1: 2 * k, 0: k * k + c}, v: 't'),
      difficulty: 1000 + 50 * lvl,
      explanation:
          'f(t + $k) = (t + $k)² ${c < 0 ? '−' : '+'} ${c.abs()} = t² + ${2 * k}t + ${k * k} ${c < 0 ? '−' : '+'} ${c.abs()}.',
      traps: {
        _poly({2: 1, 0: k * k + c}, v: 't'): const Misconception(
          'algebra',
          'You substituted correctly but expanded (t + k)² as t² + k².',
        ),
      },
      fillers: [
        _poly({2: 1, 1: k, 0: c}, v: 't'),
        _poly({2: 1, 0: k + c}, v: 't'),
      ],
    );
  }

  static Question _evaluateNegative(QuestionGenerator g, int lvl) {
    final a = g._int(1, 3 + lvl), k = g._int(2, 3 + lvl);
    final value = k * k + a * k; // f(−k) for f(x) = x² − ax
    return g._mcq(
      concept: 'functions',
      prompt: 'f(x) = ${_poly({2: 1, 1: -a})}. Find f(−$k)',
      correct: _n(value),
      difficulty: 950 + 50 * lvl,
      explanation:
          '(−$k)² − ${_coef(a, '')}(−$k) = ${k * k} + ${a * k} = $value.',
      traps: {
        _n(-k * k + a * k): const Misconception(
          'algebra',
          '(−k)² is positive: a negative squared is positive.',
        ),
        _n(k * k - a * k): const Misconception(
          'algebra',
          'Minus times minus is plus: −a·(−k) = +ak.',
        ),
      },
      fillers: [_n(-value), _n(value + k)],
    );
  }

  // ------------------------------------------------------------ composition

  static Question _composeSymbolic(QuestionGenerator g, int lvl) {
    final a = g._int(1, 3 + 2 * lvl), b = g._int(2, 3 + lvl);
    return g._mcq(
      concept: 'composition',
      prompt: 'f(x) = x + $a, g(x) = ${b}x. Find f(g(x))',
      correct: linear(b, a),
      difficulty: 1000 + 50 * lvl,
      explanation: 'Apply g first: ${b}x, then f adds $a.',
      traps: {
        linear(b, a * b): Misconception(
          'composition',
          '${linear(b, a * b)} is g(f(x)). The inner function goes first.',
        ),
      },
      fillers: [linear(b + 1, a), '${b}x² + $a', linear(1, a + b)],
    );
  }

  static Question _composeNumeric(QuestionGenerator g, int lvl) {
    final a = g._int(1, 2 + lvl), k = g._int(1, 2 + lvl);
    return g._mcq(
      concept: 'composition',
      prompt: 'f(x) = x², g(x) = x + $a. Find f(g($k))',
      correct: '${(k + a) * (k + a)}',
      difficulty: 1000 + 50 * lvl,
      explanation: 'g($k) = ${k + a}, then f(${k + a}) = ${(k + a) * (k + a)}.',
      traps: {
        '${k * k + a}': Misconception(
          'composition',
          '${k * k + a} is g(f($k)) — the order is reversed.',
        ),
      },
      fillers: [
        '${k * k + a * a}',
        '${2 * (k + a)}',
        '${(k + a) * (k + a) + 1}',
      ],
    );
  }

  static Question _innerFunction(QuestionGenerator g, int lvl) {
    final n = g._int(2, 3 + lvl), a = g._int(2, 5);
    final (expr, inner, outer) = g._pick([
      ('sin(${_pow('x', n)})', _pow('x', n), 'sin x'),
      ('(${a}x + 1)${_sup(n)}', '${a}x + 1', _pow('x', n)),
      ('e^(${a}x)', '${a}x', 'eˣ'),
      ('cos(${a}x)', '${a}x', 'cos x'),
    ]);
    return g._mcq(
      concept: 'composition',
      prompt: 'In h(x) = $expr, what is the inner function?',
      correct: inner,
      difficulty: 1050 + 50 * lvl,
      explanation: '$inner is computed first; then $outer is applied to it.',
      traps: {
        outer: const Misconception(
          'composition',
          'The inner function is the one applied first.',
        ),
      },
      fillers: ['x', expr, 'x + 1'],
    );
  }

  // ------------------------------------------------------------ limits

  static Question _limitSubstitute(QuestionGenerator g, int lvl) {
    final a = g._nz(-4, 4 + lvl), b = g._nz(-6, 6), k = g._nz(-3, 3 + lvl);
    return g._mcq(
      concept: 'limits',
      prompt: 'lim x→${_n(k)} of (${linear(a, b)})',
      correct: _n(a * k + b),
      difficulty: 900 + 50 * lvl,
      explanation: 'Continuous, so substitute x = ${_n(k)}.',
      fillers: [_n(a * k), _n(a + b), 'does not exist', _n(a * k - b)],
    );
  }

  static Question _limitFactor(QuestionGenerator g, int lvl) {
    final a = g._int(2, 3 + 2 * lvl);
    return g._mcq(
      concept: 'limits',
      prompt: 'lim x→$a of (x² − ${a * a})/(x − $a)',
      correct: '${2 * a}',
      difficulty: 1100 + 50 * lvl,
      explanation: 'Factor: (x − $a)(x + $a)/(x − $a) = x + $a → ${2 * a}.',
      traps: {
        'undefined': const Misconception(
          'limits',
          'A 0/0 form means simplify first — the limit can still exist.',
        ),
        '0': const Misconception('limits', '0/0 is indeterminate, not 0.'),
      },
      fillers: ['$a', '${a * a}'],
    );
  }

  static Question _limitSinKx(QuestionGenerator g, int lvl) {
    final k = g._int(2, 4 + 2 * lvl);
    return g._mcq(
      concept: 'limits',
      prompt: 'lim x→0 of sin(${k}x)/x',
      correct: '$k',
      difficulty: 1150 + 50 * lvl,
      explanation: 'sin(${k}x)/x = $k · sin(${k}x)/(${k}x) → $k · 1.',
      traps: {
        '1': Misconception(
          'limits',
          'Rewrite as $k·sin(${k}x)/(${k}x) — the $k comes out.',
        ),
        '0': const Misconception('limits', '0/0 is indeterminate, not 0.'),
      },
      fillers: ['1/$k', '∞'],
    );
  }

  static Question _limitInfinity(QuestionGenerator g, int lvl) {
    final a = g._int(1, 3 + lvl),
        c = g._int(2, 4 + lvl),
        b = g._int(1, 9),
        d = g._int(1, 9);
    return g._mcq(
      concept: 'limits',
      prompt: 'lim x→∞ of (${_poly({2: a, 0: b})})/(${_poly({2: c, 0: d})})',
      correct: _frac(a, c),
      difficulty: 1150 + 50 * lvl,
      explanation: 'Highest powers dominate: ${a}x²/${c}x² → ${_frac(a, c)}.',
      traps: {
        '∞': const Misconception(
          'limits',
          'Compare leading terms: equal degrees give a finite limit.',
        ),
        _frac(b, d): const Misconception(
          'limits',
          'As x → ∞ the constant terms stop mattering.',
        ),
      },
      fillers: ['0', _frac(a + b, c + d)],
    );
  }

  // ------------------------------------------------------------ derivatives

  static Question _derivConstant(QuestionGenerator g, int lvl) {
    final c = g._int(2, 20 * lvl);
    return g._mcq(
      concept: 'derivatives',
      prompt: 'd/dx ($c) = ?',
      correct: '0',
      difficulty: 850 + 30 * lvl,
      explanation: 'A constant never changes, so its slope is 0.',
      traps: {
        '$c': const Misconception(
          'derivatives',
          'A constant has zero rate of change.',
        ),
      },
      fillers: ['1', '${c}x', '−$c'],
    );
  }

  static Question _derivLinear(QuestionGenerator g, int lvl) {
    final a = g._nz(-5 - lvl, 5 + 2 * lvl), b = g._nz(-9, 9);
    return g._mcq(
      concept: 'derivatives',
      prompt: 'd/dx (${linear(a, b)}) = ?',
      correct: _n(a),
      difficulty: 900 + 40 * lvl,
      explanation:
          'The slope of a straight line is its x-coefficient; the constant vanishes.',
      traps: {
        _n(a + b): const Misconception(
          'derivatives',
          'The constant term has derivative 0.',
        ),
      },
      fillers: [_n(b), _coef(a, 'x'), '0'],
    );
  }

  static Question _tangentSlope(QuestionGenerator g, int lvl) {
    final k = g._nz(-3 - lvl, 3 + lvl);
    return g._mcq(
      concept: 'derivatives',
      prompt: 'Slope of the tangent to y = x² at x = ${_n(k)}?',
      correct: _n(2 * k),
      difficulty: 1000 + 50 * lvl,
      explanation: 'dy/dx = 2x, so the slope at x = ${_n(k)} is ${_n(2 * k)}.',
      traps: {
        _n(k * k): const Misconception(
          'derivatives',
          'That’s the y-value of the curve, not its slope.',
        ),
      },
      fillers: [_n(k), _n(2 * k + 1), '0'],
    );
  }

  // ------------------------------------------------------------ power rule

  static Question _powerMonomial(QuestionGenerator g, int lvl) {
    final a = g._int(1, 3 + 2 * lvl), n = g._int(2, 4 + 2 * lvl);
    return g._mcq(
      concept: 'power_rule',
      prompt: 'd/dx ${_coef(a, _pow('x', n))} = ?',
      correct: _coef(a * n, _pow('x', n - 1)),
      difficulty: 900 + 50 * lvl,
      explanation: 'Bring down $n, subtract one from the power.',
      traps: {
        _coef(a * n, _pow('x', n)): const Misconception(
          'power_rule',
          'Remember to subtract 1 from the power.',
        ),
        _coef(a, _pow('x', n - 1)): const Misconception(
          'power_rule',
          'Bring the power down as a multiplier.',
        ),
      },
      fillers: [
        _coef(a * (n - 1), _pow('x', n)),
        _coef(a * n, _pow('x', n + 1)),
      ],
    );
  }

  static Question _powerPolynomial(QuestionGenerator g, int lvl) {
    final a = g._int(1, 3 + lvl), b = g._nz(-6, 6 + lvl), c = g._nz(-9, 9);
    return g._mcq(
      concept: 'power_rule',
      prompt: 'd/dx (${_poly({2: a, 1: b, 0: c})}) = ?',
      correct: linear(2 * a, b),
      difficulty: 950 + 50 * lvl,
      explanation:
          'Term by term: ${2 * a}x ${b < 0 ? '−' : '+'} ${b.abs()}, and the constant vanishes.',
      traps: {
        _coef(2 * a, 'x'): Misconception(
          'power_rule',
          'd/dx (${_coef(b, 'x')}) = ${_n(b)}, not 0 — only constants vanish.',
        ),
        linear(2 * a, b + c): const Misconception(
          'derivatives',
          'The constant term has derivative 0.',
        ),
      },
      fillers: [
        linear(a, b),
        '${_coef(2 * a, 'x²')} ${b < 0 ? '−' : '+'} ${b.abs()}',
      ],
    );
  }

  static Question _powerReciprocal(QuestionGenerator g, int lvl) {
    final a = g._int(1, 2 + lvl), n = g._int(1, 2 + lvl);
    final den = _pow('x', n + 1);
    return g._mcq(
      concept: 'power_rule',
      prompt: 'd/dx ($a/${_pow('x', n)}) = ?',
      correct: '−${a * n}/$den',
      difficulty: 1100 + 50 * lvl,
      explanation:
          '$a/${_pow('x', n)} = ${_coef(a, _pow('x', -n))} → ${_n(-a * n)}${_pow('x', -n - 1)}.',
      traps: {
        '${a * n}/$den': const Misconception(
          'exponents',
          'Rewrite 1/xⁿ as x⁻ⁿ first — the power is negative.',
        ),
        if (n > 1)
          '−${a * n}/${_pow('x', n - 1)}': const Misconception(
            'exponents',
            'x⁻ⁿ differentiates to power −n − 1, not −n + 1.',
          ),
      },
      fillers: [
        '−$a/$den',
        '${a * n}/${_pow('x', n)}',
        '−${a * n}/${_pow('x', n + 2)}',
      ],
    );
  }

  static Question _powerRoot(QuestionGenerator g, int lvl) {
    final h = g._int(1, 2 + lvl), a = 2 * h;
    return g._mcq(
      concept: 'power_rule',
      prompt: 'd/dx ($a√x) = ?',
      correct: '${h == 1 ? '1' : '$h'}/√x',
      difficulty: 1150 + 50 * lvl,
      explanation: '$a·x^½ → $a·½·x^(−½) = $h/√x.',
      traps: {
        '${h == 1 ? '' : '$h'}√x': const Misconception(
          'exponents',
          '√x = x^½, so its derivative has power −½.',
        ),
      },
      fillers: ['$a/√x', '${a * 2}√x', '1/($a√x)'],
    );
  }

  // ------------------------------------------------------------ product rule

  static Question _productTrig(QuestionGenerator g, int lvl) {
    final n = g._int(2, 3 + lvl);
    final dU = _coef(n, _pow('x', n - 1)), u = _pow('x', n);
    return g._mcq(
      concept: 'product_rule',
      prompt: 'd/dx ($u · sin x) = ?',
      correct: '$dU sin x + $u cos x',
      difficulty: 1150 + 50 * lvl,
      explanation: 'u = $u, v = sin x: u′v + uv′.',
      traps: {
        '$dU cos x': const Misconception(
          'product_rule',
          'You multiplied the derivatives. Use u′v + uv′.',
        ),
        '$u cos x': const Misconception(
          'product_rule',
          'You only differentiated one factor.',
        ),
      },
      fillers: ['$dU sin x', '$dU sin x − $u cos x'],
    );
  }

  static Question _productExp(QuestionGenerator g, int lvl) {
    final n = g._int(2, 3 + lvl);
    final dU = _coef(n, _pow('x', n - 1)), u = _pow('x', n);
    return g._mcq(
      concept: 'product_rule',
      prompt: 'd/dx ($u · eˣ) = ?',
      correct: '$dU eˣ + $u eˣ',
      difficulty: 1150 + 50 * lvl,
      explanation: 'u′v + uv′ = $dU·eˣ + $u·eˣ.',
      traps: {
        '$dU eˣ': const Misconception(
          'product_rule',
          'You only differentiated one factor.',
        ),
      },
      fillers: ['$u eˣ', '$dU eˣ⁻¹', '${_coef(n, _pow('x', n))} eˣ'],
    );
  }

  static Question _productLinear(QuestionGenerator g, int lvl) {
    final a = g._nz(-5, 5 + lvl), b = g._nz(-5, 5 + lvl);
    String bracket(int c) => '(x ${c < 0 ? '−' : '+'} ${c.abs()})';
    return g._mcq(
      concept: 'product_rule',
      prompt: 'd/dx ${bracket(a)}${bracket(b)} = ?',
      correct: linear(2, a + b),
      difficulty: 1100 + 50 * lvl,
      explanation:
          'u′v + uv′ = ${bracket(b)} + ${bracket(a)} = ${linear(2, a + b)}.',
      traps: {
        '1': const Misconception(
          'product_rule',
          'The derivative of a product is not the product of the derivatives.',
        ),
      },
      fillers: [
        linear(2, a * b),
        linear(1, a + b),
        _poly({2: 1, 1: a + b}),
      ],
    );
  }

  // ------------------------------------------------------------ chain rule

  static Question _chainLinearPower(QuestionGenerator g, int lvl) {
    final a = g._int(2, 3 + lvl), b = g._nz(-5, 5), n = g._int(2, 4 + lvl);
    final inner = '(${linear(a, b)})';
    return g._mcq(
      concept: 'chain_rule',
      prompt: 'd/dx $inner${_sup(n)} = ?',
      correct: '${n * a}$inner${_supPow(n - 1)}',
      difficulty: 1150 + 50 * lvl,
      explanation: '$n$inner${_supPow(n - 1)} × $a (derivative of the inside).',
      traps: {
        '$n$inner${_supPow(n - 1)}': Misconception(
          'chain_rule',
          'You forgot to multiply by the inner derivative ($a).',
        ),
        '${n * a}$inner${_sup(n)}': const Misconception(
          'power_rule',
          'The outer power should drop by one.',
        ),
        '${n * a}${_pow('x', n - 1)}': const Misconception(
          'composition',
          'Keep the whole inside — don’t replace it with x.',
        ),
      },
      fillers: ['$n(${a}x)${_supPow(n - 1)}'],
    );
  }

  static Question _chainQuadraticPower(QuestionGenerator g, int lvl) {
    final c = g._nz(-5, 5 + lvl), n = g._int(2, 3 + lvl);
    final inner = '(${_poly({2: 1, 0: c})})';
    return g._mcq(
      concept: 'chain_rule',
      prompt: 'd/dx $inner${_sup(n)} = ?',
      correct: '${2 * n}x$inner${_supPow(n - 1)}',
      difficulty: 1200 + 50 * lvl,
      explanation: '$n$inner${_supPow(n - 1)} × 2x.',
      traps: {
        '$n$inner${_supPow(n - 1)}': const Misconception(
          'chain_rule',
          'Missing × 2x — the derivative of the inside.',
        ),
        '${2 * n}x$inner${_sup(n)}': const Misconception(
          'power_rule',
          'The outer power should drop by one.',
        ),
        '$n(2x)${_supPow(n - 1)}': const Misconception(
          'composition',
          'You replaced the inside with its derivative instead of keeping it.',
        ),
      },
    );
  }

  static Question _chainExp(QuestionGenerator g, int lvl) {
    final k = g._int(2, 4 + 2 * lvl);
    return g._mcq(
      concept: 'chain_rule',
      prompt: 'd/dx e^(${k}x) = ?',
      correct: '${k}e^(${k}x)',
      difficulty: 1100 + 50 * lvl,
      explanation: 'e^(u) differentiates to e^(u)·u′ with u′ = $k.',
      traps: {
        'e^(${k}x)': Misconception(
          'chain_rule',
          'Multiply by the inner derivative ($k).',
        ),
        '${k}x·e^(${k}x − 1)': const Misconception(
          'power_rule',
          'The power rule doesn’t apply to e^(kx).',
        ),
      },
      fillers: ['e^($k)', '${k}e^x'],
    );
  }

  static Question _chainRoot(QuestionGenerator g, int lvl) {
    final a = g._int(2, 4 + lvl), b = g._int(1, 9);
    final root = '√(${linear(a, b)})';
    return g._mcq(
      concept: 'chain_rule',
      prompt: 'd/dx $root = ?',
      correct: '$a/(2$root)',
      difficulty: 1250 + 50 * lvl,
      explanation: '(${linear(a, b)})^½ → ½(${linear(a, b)})^−½ × $a.',
      traps: {
        '1/(2$root)': Misconception(
          'chain_rule',
          'Close! You forgot × $a from the inside.',
        ),
        '½$root': const Misconception(
          'exponents',
          '√ is a power of ½; differentiating gives power −½.',
        ),
      },
      fillers: ['$a$root', '2$a/$root'],
    );
  }

  // ------------------------------------------------------------ trig

  static Question _trigSin(QuestionGenerator g, int lvl) {
    final a = g._int(1, 3 + 2 * lvl);
    return g._mcq(
      concept: 'trig_derivs',
      prompt: 'd/dx (${_coef(a, 'sin x')}) = ?',
      correct: _coef(a, 'cos x'),
      difficulty: 950 + 40 * lvl,
      explanation: 'd/dx sin x = cos x, constants multiply through.',
      traps: {
        '−${_coef(a, 'cos x')}': const Misconception(
          'trig_derivs',
          'sin differentiates to +cos.',
        ),
      },
      fillers: ['−${_coef(a, 'sin x')}', _coef(a, 'sin x')],
    );
  }

  static Question _trigCos(QuestionGenerator g, int lvl) {
    final a = g._int(1, 3 + 2 * lvl);
    return g._mcq(
      concept: 'trig_derivs',
      prompt: 'd/dx (${_coef(a, 'cos x')}) = ?',
      correct: '−${_coef(a, 'sin x')}',
      difficulty: 1000 + 40 * lvl,
      explanation: 'd/dx cos x = −sin x.',
      traps: {
        _coef(a, 'sin x'): const Misconception(
          'trig_derivs',
          'Watch the sign: cos differentiates to −sin.',
        ),
      },
      fillers: ['−${_coef(a, 'cos x')}', _coef(a, 'cos x')],
    );
  }

  static Question _trigCombo(QuestionGenerator g, int lvl) {
    final a = g._int(1, 3 + lvl), b = g._int(1, 3 + lvl);
    return g._mcq(
      concept: 'trig_derivs',
      prompt: 'd/dx (${_coef(a, 'sin x')} + ${_coef(b, 'cos x')}) = ?',
      correct: '${_coef(a, 'cos x')} − ${_coef(b, 'sin x')}',
      difficulty: 1050 + 50 * lvl,
      explanation: 'sin → cos and cos → −sin, term by term.',
      traps: {
        '${_coef(a, 'cos x')} + ${_coef(b, 'sin x')}': const Misconception(
          'trig_derivs',
          'cos differentiates to −sin.',
        ),
      },
      fillers: [
        '−${_coef(a, 'cos x')} + ${_coef(b, 'sin x')}',
        '${_coef(a, 'cos x')} − ${_coef(b, 'cos x')}',
      ],
    );
  }

  // ------------------------------------------------------------ composite trig

  static Question _sinKx(QuestionGenerator g, int lvl) {
    final k = g._int(2, 4 + 2 * lvl);
    return g._mcq(
      concept: 'composite_trig',
      prompt: 'd/dx sin(${k}x) = ?',
      correct: '$k cos(${k}x)',
      difficulty: 1150 + 50 * lvl,
      explanation: 'cos(${k}x) × $k from the inside.',
      traps: {
        'cos(${k}x)': Misconception(
          'chain_rule',
          'Multiply by the inner derivative, $k.',
        ),
        '$k cos x': Misconception(
          'composition',
          'Keep ${k}x inside the cosine.',
        ),
        '−$k cos(${k}x)': const Misconception(
          'trig_derivs',
          'sin differentiates to +cos.',
        ),
      },
    );
  }

  static Question _cosPower(QuestionGenerator g, int lvl) {
    final n = g._int(2, 3 + lvl);
    final inner = _pow('x', n), dInner = _coef(n, _pow('x', n - 1));
    return g._mcq(
      concept: 'composite_trig',
      prompt: 'd/dx cos($inner) = ?',
      correct: '−$dInner sin($inner)',
      difficulty: 1250 + 50 * lvl,
      explanation: '−sin($inner) × $dInner.',
      traps: {
        '−sin($inner)': Misconception(
          'chain_rule',
          'Missing × $dInner from the inner function.',
        ),
        '$dInner sin($inner)': const Misconception(
          'trig_derivs',
          'cos differentiates to −sin.',
        ),
        '−sin($dInner)': const Misconception(
          'composition',
          'You replaced the inside with its derivative — keep it.',
        ),
      },
    );
  }

  static Question _sinPower(QuestionGenerator g, int lvl) {
    final n = g._int(2, 3 + lvl);
    final sinPow = n - 1 == 1 ? 'sin x' : 'sin${_sup(n - 1)}x';
    return g._mcq(
      concept: 'composite_trig',
      prompt: 'd/dx sin${_sup(n)}x = ?',
      correct: '$n $sinPow cos x',
      difficulty: 1300 + 50 * lvl,
      explanation:
          'sin${_sup(n)}x = (sin x)${_sup(n)}: $n(sin x)${_supPow(n - 1)} × cos x.',
      traps: {
        '$n $sinPow': const Misconception(
          'chain_rule',
          'Multiply by the derivative of sin x.',
        ),
        'cos${_sup(n)}x': const Misconception(
          'composition',
          'sinⁿx is (sin x)ⁿ — the outer layer is the power, not sin.',
        ),
      },
      fillers: ['$n cos${_supPow(n - 1)}x'],
    );
  }

  static Question _sinLinear(QuestionGenerator g, int lvl) {
    final a = g._int(2, 4 + lvl), b = g._int(1, 9);
    final inner = linear(a, b);
    return g._mcq(
      concept: 'composite_trig',
      prompt: 'd/dx sin($inner) = ?',
      correct: '$a cos($inner)',
      difficulty: 1200 + 50 * lvl,
      explanation: 'cos($inner) × $a.',
      traps: {
        'cos($inner)': Misconception(
          'chain_rule',
          'Multiply by the inner derivative, $a.',
        ),
        '$a cos x': const Misconception(
          'composition',
          'Keep the whole inside in the cosine.',
        ),
      },
      fillers: ['−$a cos($inner)', '$a sin($inner)'],
    );
  }
}

// ---------------------------------------------------------------- formatting

const _supDigits = {
  '0': '⁰',
  '1': '¹',
  '2': '²',
  '3': '³',
  '4': '⁴',
  '5': '⁵',
  '6': '⁶',
  '7': '⁷',
  '8': '⁸',
  '9': '⁹',
  '-': '⁻',
};

/// Superscript form of [n], e.g. 12 → ¹², −3 → ⁻³.
String _sup(int n) => n.toString().split('').map((c) => _supDigits[c]!).join();

/// Superscript, but empty for a power of 1.
String _supPow(int n) => n == 1 ? '' : _sup(n);

/// Uses a proper minus sign for negatives.
String _n(int v) => v < 0 ? '−${-v}' : '$v';

String _pow(String base, int n) => switch (n) {
  0 => '1',
  1 => base,
  _ => '$base${_sup(n)}',
};

/// Coefficient times a term, hiding 1 and −1.
String _coef(int c, String term) {
  if (term.isEmpty) return _n(c);
  if (c == 1) return term;
  if (c == -1) return '−$term';
  return '${_n(c)}$term';
}

/// Reduced fraction a/b (or an integer).
String _frac(int a, int b) {
  int gcd(int x, int y) => y == 0 ? x.abs() : gcd(y, x % y);
  final g = gcd(a, b);
  final (p, q) = (a ~/ g, b ~/ g);
  return q == 1 ? _n(p) : '${_n(p)}/$q';
}

/// Polynomial from {power: coefficient}, highest power first.
String _poly(Map<int, int> terms, {String v = 'x'}) {
  final powers = terms.keys.where((p) => terms[p] != 0).toList()
    ..sort((a, b) => b - a);
  if (powers.isEmpty) return '0';
  final buf = StringBuffer();
  for (final p in powers) {
    final c = terms[p]!;
    final body = p == 0 ? '${c.abs()}' : _coef(c.abs(), _pow(v, p));
    if (buf.isEmpty) {
      buf.write(c < 0 ? '−$body' : body);
    } else {
      buf.write(c < 0 ? ' − $body' : ' + $body');
    }
  }
  return buf.toString();
}

/// "ax + b" with tidy signs.
String linear(int a, int b, {String v = 'x'}) => _poly({1: a, 0: b}, v: v);
