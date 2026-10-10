/// Static study content. Later this comes from the backend; for now it is a
/// single Maths (Calculus) knowledge graph with lessons and tagged questions.
library;

class Concept {
  const Concept({
    required this.id,
    required this.name,
    required this.prereqs,
    required this.keyPoints,
    required this.example,
  });

  final String id;
  final String name;

  /// Concepts that must be understood first (edges of the knowledge graph).
  final List<String> prereqs;

  /// Bite-sized lesson content for the 5-minute "Learn" step.
  final List<String> keyPoints;
  final String example;
}

/// What a specific wrong option reveals. [rootCause] may point to a
/// *different* concept than the question's own — that's how a chain-rule
/// mistake can be traced back to algebra or function composition.
class Misconception {
  const Misconception(this.rootCause, this.explanation);

  final String rootCause;
  final String explanation;
}

class Question {
  const Question({
    required this.id,
    required this.conceptId,
    required this.prompt,
    required this.options,
    required this.answer,
    required this.difficulty,
    required this.explanation,
    this.traps = const {},
  });

  final String id;
  final String conceptId;
  final String prompt;
  final List<String> options;
  final int answer;

  /// Elo-style difficulty rating of the question itself.
  final int difficulty;
  final String explanation;

  /// Option index → misconception it reveals.
  final Map<int, Misconception> traps;
}

const subjectName = 'Maths · Calculus';

const concepts = <Concept>[
  Concept(
    id: 'algebra',
    name: 'Algebra basics',
    prereqs: [],
    keyPoints: [
      'Distribute: a(b + c) = ab + ac — multiply *every* term inside.',
      'Collect like terms: 3x + 2 − x = 2x + 2.',
      '(a + b)² = a² + 2ab + b², never just a² + b².',
    ],
    example: '(x + 3)² = x² + 2·x·3 + 9 = x² + 6x + 9',
  ),
  Concept(
    id: 'exponents',
    name: 'Exponents',
    prereqs: ['algebra'],
    keyPoints: [
      'Multiply same base → add powers: xᵃ·xᵇ = xᵃ⁺ᵇ.',
      'Power of a power → multiply: (xᵃ)ᵇ = xᵃᵇ.',
      'Negative power = reciprocal: x⁻ⁿ = 1/xⁿ. Roots are fractional powers: √x = x^½.',
    ],
    example: 'x³·x⁴ = x⁷, (x²)³ = x⁶, 1/x² = x⁻²',
  ),
  Concept(
    id: 'functions',
    name: 'Functions',
    prereqs: ['algebra'],
    keyPoints: [
      'A function gives exactly one output for each input.',
      'f(a) means: replace every x with a.',
      'Replace x with a whole expression in brackets: f(a + 1).',
    ],
    example: 'f(x) = x² ⇒ f(a + 1) = (a + 1)² = a² + 2a + 1',
  ),
  Concept(
    id: 'composition',
    name: 'Function composition',
    prereqs: ['functions'],
    keyPoints: [
      'f(g(x)) means: apply g first, then f.',
      'Order matters: f(g(x)) is usually not g(f(x)).',
      'In sin(x²), the inner function is x² and the outer is sin.',
    ],
    example: 'f(x) = x + 2, g(x) = 3x ⇒ f(g(x)) = 3x + 2',
  ),
  Concept(
    id: 'limits',
    name: 'Limits',
    prereqs: ['functions'],
    keyPoints: [
      'A limit is the value f(x) approaches, not necessarily f(a).',
      'For nice (continuous) functions, just substitute.',
      '0/0 is indeterminate — factor or simplify first.',
    ],
    example: '(x² − 9)/(x − 3) = x + 3 → 6 as x → 3',
  ),
  Concept(
    id: 'derivatives',
    name: 'Derivatives',
    prereqs: ['limits'],
    keyPoints: [
      'The derivative is the instantaneous rate of change — the slope of the tangent.',
      'f′(a) > 0 ⇒ increasing at a; f′(a) < 0 ⇒ decreasing.',
      'The derivative of a constant is 0.',
    ],
    example: 'Position s(t) ⇒ velocity s′(t)',
  ),
  Concept(
    id: 'power_rule',
    name: 'Power rule',
    prereqs: ['derivatives', 'exponents'],
    keyPoints: [
      'd/dx xⁿ = n·xⁿ⁻¹: bring the power down, subtract one.',
      'Differentiate term by term; constants multiply through.',
      'Rewrite roots and fractions as powers first: 1/x = x⁻¹.',
    ],
    example: 'd/dx (3x² + 4x) = 6x + 4',
  ),
  Concept(
    id: 'product_rule',
    name: 'Product rule',
    prereqs: ['derivatives'],
    keyPoints: [
      '(uv)′ = u′v + uv′.',
      'The derivative of a product is NOT the product of derivatives.',
      'Label u and v before you start.',
    ],
    example: 'd/dx (x·sin x) = 1·sin x + x·cos x',
  ),
  Concept(
    id: 'chain_rule',
    name: 'Chain rule',
    prereqs: ['power_rule', 'composition'],
    keyPoints: [
      'd/dx f(g(x)) = f′(g(x)) · g′(x).',
      'Differentiate the outer function, keep the inside, then multiply by the inside’s derivative.',
      'Forgetting “× inner derivative” is the #1 mistake.',
    ],
    example: 'd/dx (3x + 1)⁴ = 4(3x + 1)³ · 3 = 12(3x + 1)³',
  ),
  Concept(
    id: 'trig_derivs',
    name: 'Trig derivatives',
    prereqs: ['derivatives'],
    keyPoints: [
      'd/dx sin x = cos x.',
      'd/dx cos x = −sin x (watch the sign!).',
      'Angles are in radians for these rules.',
    ],
    example: 'd/dx (2 sin x + cos x) = 2 cos x − sin x',
  ),
  Concept(
    id: 'composite_trig',
    name: 'Composite functions',
    prereqs: ['chain_rule', 'trig_derivs'],
    keyPoints: [
      'Spot the layers: sin(x²) = outer sin, inner x².',
      'sin²x means (sin x)²: the outer layer is the square.',
      'Each layer contributes one factor to the derivative.',
    ],
    example: 'd/dx sin(x²) = cos(x²) · 2x',
  ),
];

const questions = <Question>[
  // Algebra
  Question(
    id: 'alg1',
    conceptId: 'algebra',
    prompt: 'Simplify 3(x + 2) − x',
    options: ['2x + 6', '2x + 2', '3x + 6', '4x + 6'],
    answer: 0,
    difficulty: 900,
    explanation: '3(x + 2) = 3x + 6, then 3x + 6 − x = 2x + 6.',
    traps: {1: Misconception('algebra', 'The 3 multiplies the 2 as well.')},
  ),
  Question(
    id: 'alg2',
    conceptId: 'algebra',
    prompt: 'Solve 2x + 5 = 13',
    options: ['x = 9', 'x = 4', 'x = 6.5', 'x = 8'],
    answer: 1,
    difficulty: 850,
    explanation: '2x = 8, so x = 4.',
  ),
  Question(
    id: 'alg3',
    conceptId: 'algebra',
    prompt: 'Expand (x + 3)²',
    options: ['x² + 9', 'x² + 3x + 9', 'x² + 6x + 9', '2x + 6'],
    answer: 2,
    difficulty: 1000,
    explanation: '(x + 3)² = x² + 2·3·x + 9.',
    traps: {
      0: Misconception(
        'algebra',
        '(a + b)² ≠ a² + b² — you lost the 2ab term.',
      ),
    },
  ),
  // Exponents
  Question(
    id: 'exp1',
    conceptId: 'exponents',
    prompt: 'x³ · x⁴ = ?',
    options: ['x¹²', 'x⁷', '2x⁷', 'x'],
    answer: 1,
    difficulty: 950,
    explanation: 'Same base: add the powers, 3 + 4 = 7.',
    traps: {
      0: Misconception(
        'exponents',
        'Multiplying powers is for (xᵃ)ᵇ, not xᵃ·xᵇ.',
      ),
    },
  ),
  Question(
    id: 'exp2',
    conceptId: 'exponents',
    prompt: '(x²)³ = ?',
    options: ['x⁵', 'x⁸', 'x⁶', '3x²'],
    answer: 2,
    difficulty: 1000,
    explanation: 'Power of a power: multiply, 2 × 3 = 6.',
    traps: {
      0: Misconception(
        'exponents',
        'Adding powers is for xᵃ·xᵇ; here you multiply.',
      ),
    },
  ),
  Question(
    id: 'exp3',
    conceptId: 'exponents',
    prompt: 'Write 1/x² as a power of x',
    options: ['x^½', '−x²', 'x⁻½', 'x⁻²'],
    answer: 3,
    difficulty: 1050,
    explanation: 'A reciprocal flips the sign of the power: 1/x² = x⁻².',
    traps: {
      1: Misconception(
        'exponents',
        'A negative power means reciprocal, not a negative number.',
      ),
    },
  ),
  // Functions
  Question(
    id: 'fn1',
    conceptId: 'functions',
    prompt: 'f(x) = 2x + 1. Find f(3)',
    options: ['6', '7', '5', '9'],
    answer: 1,
    difficulty: 900,
    explanation: 'f(3) = 2·3 + 1 = 7.',
  ),
  Question(
    id: 'fn2',
    conceptId: 'functions',
    prompt: 'f(x) = x². Find f(a + 1)',
    options: ['a² + 1', 'a² + 2a + 1', 'a + 1', '2a + 2'],
    answer: 1,
    difficulty: 1050,
    explanation: 'f(a + 1) = (a + 1)² = a² + 2a + 1.',
    traps: {
      0: Misconception(
        'algebra',
        'You substituted correctly but expanded (a + 1)² as a² + 1.',
      ),
    },
  ),
  Question(
    id: 'fn3',
    conceptId: 'functions',
    prompt: 'Which of these is NOT a function?',
    options: [
      '{(1,2), (2,2), (3,2)}',
      'y = x²',
      '{(1,2), (2,3), (2,5)}',
      'y = 3',
    ],
    answer: 2,
    difficulty: 1000,
    explanation: 'Input 2 has two outputs (3 and 5), so it is not a function.',
  ),
  // Composition
  Question(
    id: 'cmp1',
    conceptId: 'composition',
    prompt: 'f(x) = x + 2, g(x) = 3x. Find f(g(x))',
    options: ['3x + 6', '3x + 2', '3x²', 'x + 5'],
    answer: 1,
    difficulty: 1050,
    explanation: 'Apply g first: 3x, then f: 3x + 2.',
    traps: {
      0: Misconception(
        'composition',
        '3x + 6 is g(f(x)). Inner function goes first.',
      ),
    },
  ),
  Question(
    id: 'cmp2',
    conceptId: 'composition',
    prompt: 'f(x) = x², g(x) = x + 1. Find f(g(2))',
    options: ['5', '4', '9', '6'],
    answer: 2,
    difficulty: 1050,
    explanation: 'g(2) = 3, then f(3) = 9.',
    traps: {
      0: Misconception('composition', '5 is g(f(2)) — the order is reversed.'),
    },
  ),
  Question(
    id: 'cmp3',
    conceptId: 'composition',
    prompt: 'In h(x) = sin(x²), what is the inner function?',
    options: ['sin x', 'x²', 'x', 'sin'],
    answer: 1,
    difficulty: 1100,
    explanation: 'x² is computed first, then sin is applied to it.',
    traps: {
      0: Misconception(
        'composition',
        'The inner function is the one applied first.',
      ),
    },
  ),
  // Limits
  Question(
    id: 'lim1',
    conceptId: 'limits',
    prompt: 'lim x→2 of (3x + 1)',
    options: ['6', '1', '7', 'undefined'],
    answer: 2,
    difficulty: 950,
    explanation: 'Continuous, so substitute: 3·2 + 1 = 7.',
  ),
  Question(
    id: 'lim2',
    conceptId: 'limits',
    prompt: 'lim x→0 of (sin x)/x',
    options: ['0', '1', 'undefined', '∞'],
    answer: 1,
    difficulty: 1150,
    explanation: 'A standard limit: (sin x)/x → 1 as x → 0.',
    traps: {0: Misconception('limits', '0/0 is indeterminate, not 0.')},
  ),
  Question(
    id: 'lim3',
    conceptId: 'limits',
    prompt: 'lim x→3 of (x² − 9)/(x − 3)',
    options: ['0', 'undefined', '3', '6'],
    answer: 3,
    difficulty: 1150,
    explanation: 'Factor: (x − 3)(x + 3)/(x − 3) = x + 3 → 6.',
    traps: {
      1: Misconception(
        'limits',
        'A 0/0 form means simplify first — the limit can still exist.',
      ),
    },
  ),
  // Derivatives
  Question(
    id: 'der1',
    conceptId: 'derivatives',
    prompt: 'A derivative measures…',
    options: [
      'the area under a curve',
      'the instantaneous rate of change',
      'the average value',
      'the maximum value',
    ],
    answer: 1,
    difficulty: 950,
    explanation:
        'It is the slope of the tangent: the instantaneous rate of change.',
    traps: {
      0: Misconception(
        'derivatives',
        'Area under a curve is integration, the reverse process.',
      ),
    },
  ),
  Question(
    id: 'der2',
    conceptId: 'derivatives',
    prompt: 'd/dx (5) = ?',
    options: ['5', '1', '0', '5x'],
    answer: 2,
    difficulty: 900,
    explanation: 'A constant never changes, so its slope is 0.',
    traps: {
      0: Misconception('derivatives', 'A constant has zero rate of change.'),
    },
  ),
  Question(
    id: 'der3',
    conceptId: 'derivatives',
    prompt: 'If f′(a) > 0, then at x = a the function is…',
    options: ['decreasing', 'at a maximum', 'increasing', 'constant'],
    answer: 2,
    difficulty: 1000,
    explanation: 'Positive slope means the function is going up.',
  ),
  // Power rule
  Question(
    id: 'pow1',
    conceptId: 'power_rule',
    prompt: 'd/dx x⁵ = ?',
    options: ['5x⁵', 'x⁴', '4x⁵', '5x⁴'],
    answer: 3,
    difficulty: 950,
    explanation: 'Bring down 5, subtract one from the power: 5x⁴.',
    traps: {
      0: Misconception('power_rule', 'Remember to subtract 1 from the power.'),
    },
  ),
  Question(
    id: 'pow2',
    conceptId: 'power_rule',
    prompt: 'd/dx (3x² + 4x) = ?',
    options: ['6x + 4', '6x', '3x + 4', '6x² + 4'],
    answer: 0,
    difficulty: 1000,
    explanation: 'Term by term: 6x + 4.',
    traps: {
      1: Misconception(
        'power_rule',
        'd/dx (4x) = 4, not 0 — only constants vanish.',
      ),
    },
  ),
  Question(
    id: 'pow3',
    conceptId: 'power_rule',
    prompt: 'd/dx (1/x) = ?',
    options: ['1/x²', '−1/x²', 'ln x', '−1/x'],
    answer: 1,
    difficulty: 1150,
    explanation: '1/x = x⁻¹ → −1·x⁻² = −1/x².',
    traps: {
      0: Misconception(
        'exponents',
        'Rewrite 1/x as x⁻¹ first — the power is negative.',
      ),
      2: Misconception(
        'derivatives',
        'ln x is the integral of 1/x, not its derivative.',
      ),
    },
  ),
  // Product rule
  Question(
    id: 'prd1',
    conceptId: 'product_rule',
    prompt: 'd/dx (x · sin x) = ?',
    options: ['cos x', 'x cos x', 'sin x + x cos x', 'sin x cos x'],
    answer: 2,
    difficulty: 1150,
    explanation: 'u = x, v = sin x: u′v + uv′ = sin x + x cos x.',
    traps: {
      0: Misconception(
        'product_rule',
        'You multiplied the derivatives. Use u′v + uv′.',
      ),
    },
  ),
  Question(
    id: 'prd2',
    conceptId: 'product_rule',
    prompt: 'd/dx (x² · eˣ) = ?',
    options: ['2x eˣ', '2x eˣ + x² eˣ', 'x² eˣ', '2x'],
    answer: 1,
    difficulty: 1150,
    explanation: 'u′v + uv′ = 2x·eˣ + x²·eˣ.',
    traps: {
      0: Misconception('product_rule', 'You only differentiated one factor.'),
    },
  ),
  // Chain rule
  Question(
    id: 'chn1',
    conceptId: 'chain_rule',
    prompt: 'd/dx (3x + 1)⁴ = ?',
    options: ['4(3x + 1)³', '12(3x + 1)³', '12x³', '4(3x)³'],
    answer: 1,
    difficulty: 1200,
    explanation: '4(3x + 1)³ × 3 (derivative of the inside) = 12(3x + 1)³.',
    traps: {
      0: Misconception(
        'chain_rule',
        'You forgot to multiply by the inner derivative (3).',
      ),
    },
  ),
  Question(
    id: 'chn2',
    conceptId: 'chain_rule',
    prompt: 'd/dx (x² + 1)³ = ?',
    options: ['3(x² + 1)²', '6x(x² + 1)³', '6x(x² + 1)²', '3(2x)²'],
    answer: 2,
    difficulty: 1250,
    explanation: '3(x² + 1)² × 2x = 6x(x² + 1)².',
    traps: {
      0: Misconception(
        'chain_rule',
        'Missing × 2x — the derivative of the inside.',
      ),
      1: Misconception(
        'power_rule',
        'The outer power should drop from 3 to 2.',
      ),
      3: Misconception(
        'composition',
        'You replaced the inside with its derivative instead of keeping it.',
      ),
    },
  ),
  Question(
    id: 'chn3',
    conceptId: 'chain_rule',
    prompt: 'd/dx √(2x) = ?',
    options: ['1/(2√(2x))', '1/√(2x)', '2√(2x)', '½√(2x)'],
    answer: 1,
    difficulty: 1300,
    explanation: '(2x)^½ → ½(2x)^−½ × 2 = 1/√(2x).',
    traps: {
      0: Misconception('chain_rule', 'Close! You forgot × 2 from the inside.'),
      3: Misconception(
        'exponents',
        '√ is a power of ½; differentiating gives power −½.',
      ),
    },
  ),
  // Trig derivatives
  Question(
    id: 'trg1',
    conceptId: 'trig_derivs',
    prompt: 'd/dx sin x = ?',
    options: ['−cos x', 'cos x', '−sin x', 'sin x'],
    answer: 1,
    difficulty: 1000,
    explanation: 'd/dx sin x = cos x.',
  ),
  Question(
    id: 'trg2',
    conceptId: 'trig_derivs',
    prompt: 'd/dx cos x = ?',
    options: ['sin x', '−cos x', '−sin x', 'cos x'],
    answer: 2,
    difficulty: 1050,
    explanation: 'd/dx cos x = −sin x.',
    traps: {
      0: Misconception(
        'trig_derivs',
        'Watch the sign: cos differentiates to −sin.',
      ),
    },
  ),
  // Composite functions
  Question(
    id: 'cmt1',
    conceptId: 'composite_trig',
    prompt: 'd/dx sin(x²) = ?',
    options: ['cos(x²)', '2x cos(x²)', 'cos(2x)', '2x cos x'],
    answer: 1,
    difficulty: 1300,
    explanation: 'Outer: cos(x²). Inner derivative: 2x. Multiply.',
    traps: {
      0: Misconception('chain_rule', 'Missing × 2x from the inner function.'),
      2: Misconception(
        'composition',
        'You replaced the inside with its derivative — keep x² inside.',
      ),
      3: Misconception('composition', 'The inside of cos must stay x².'),
    },
  ),
  Question(
    id: 'cmt2',
    conceptId: 'composite_trig',
    prompt: 'd/dx cos(3x) = ?',
    options: ['−sin(3x)', '3 sin(3x)', '−3 sin(3x)', '−3 sin x'],
    answer: 2,
    difficulty: 1250,
    explanation: '−sin(3x) × 3 = −3 sin(3x).',
    traps: {
      0: Misconception('chain_rule', 'Multiply by the inner derivative, 3.'),
      1: Misconception('trig_derivs', 'cos differentiates to −sin.'),
      3: Misconception('composition', 'Keep 3x inside the sine.'),
    },
  ),
  Question(
    id: 'cmt3',
    conceptId: 'composite_trig',
    prompt: 'd/dx sin²x = ?',
    options: ['2 sin x', 'cos²x', '2 cos x', '2 sin x cos x'],
    answer: 3,
    difficulty: 1350,
    explanation: 'sin²x = (sin x)²: 2 sin x × cos x.',
    traps: {
      0: Misconception('chain_rule', 'Multiply by the derivative of sin x.'),
      1: Misconception(
        'composition',
        'sin²x is (sin x)² — the outer layer is the square, not sin.',
      ),
    },
  ),
];

final conceptById = {for (final c in concepts) c.id: c};

List<Question> questionsFor(String conceptId) =>
    questions.where((q) => q.conceptId == conceptId).toList();
