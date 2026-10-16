import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Animated arcade backdrop for the auth screens: drifting neon glows,
/// floating maths symbols, twinkling stars and a scrolling synthwave grid.
class GameBackground extends StatefulWidget {
  const GameBackground({super.key, this.child});

  final Widget? child;

  @override
  State<GameBackground> createState() => _GameBackgroundState();
}

class _GameBackgroundState extends State<GameBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(painter: _BackgroundPainter(_controller)),
        ),
        ?widget.child,
      ],
    );
  }
}

class _Glyph {
  _Glyph(math.Random r)
    : text = _symbols[r.nextInt(_symbols.length)],
      x = r.nextDouble(),
      phase = r.nextDouble(),
      speed = 0.6 + r.nextDouble() * 0.9,
      size = 16 + r.nextDouble() * 26,
      sway = r.nextDouble() * 2 * math.pi,
      spin = (r.nextDouble() - 0.5) * 0.8,
      color = _colors[r.nextInt(_colors.length)];

  static const _symbols = [
    '∫',
    '∑',
    'π',
    '√',
    '∞',
    'Δ',
    'x²',
    'θ',
    'λ',
    '±',
    '≈',
    'f(x)',
    'dy/dx',
    'eˣ',
    'sin',
    '∂',
    '÷',
    '%',
    'Σ',
    'α',
  ];
  static const _colors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.mastered,
    AppColors.xp,
    Color(0xFFF472B6),
  ];

  final String text;
  final double x, phase, speed, size, sway, spin;
  final Color color;
  // Painters cached per opacity step so no layer is needed each frame.
  final _painters = List<TextPainter?>.filled(11, null);

  TextPainter painterAt(double opacity) {
    final step = (opacity.clamp(0.0, 1.0) * 10).round();
    return _painters[step] ??= TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color.withValues(alpha: step / 10),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter(this.anim) : super(repaint: anim);

  final Animation<double> anim;

  static final _rand = math.Random(7);
  static final _glyphs = List.generate(22, (_) => _Glyph(_rand));
  static final _stars = List.generate(
    70,
    (_) => (_rand.nextDouble(), _rand.nextDouble() * 0.7, _rand.nextDouble()),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value; // 0 → 1 over 30 s
    final w = size.width, h = size.height;
    final tau = 2 * math.pi;

    // Base gradient.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0C1C), Color(0xFF130F2E), Color(0xFF0D0E1A)],
        ).createShader(Offset.zero & size),
    );

    // Drifting neon orbs.
    void orb(Offset c, double r, Color color) => canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final m = math.max(w, h);
    orb(
      Offset(
        w * (0.2 + 0.1 * math.sin(t * tau)),
        h * (0.18 + 0.05 * math.cos(t * tau)),
      ),
      m * 0.45,
      AppColors.secondary,
    );
    orb(
      Offset(
        w * (0.85 + 0.08 * math.cos(t * tau * 2)),
        h * (0.45 + 0.08 * math.sin(t * tau)),
      ),
      m * 0.38,
      const Color(0xFFF472B6),
    );
    orb(
      Offset(w * (0.4 + 0.15 * math.sin(t * tau * 3)), h * 0.9),
      m * 0.4,
      AppColors.primary,
    );

    // Twinkling stars.
    for (var i = 0; i < _stars.length; i++) {
      final (sx, sy, p) = _stars[i];
      final a = 0.25 + 0.75 * (0.5 + 0.5 * math.sin((t * 12 + p) * tau));
      canvas.drawCircle(
        Offset(sx * w, sy * h),
        0.6 + p * 1.2,
        Paint()..color = Colors.white.withValues(alpha: a * 0.7),
      );
    }

    _paintGrid(canvas, size, t);

    // Floating maths symbols rising from the bottom.
    for (final g in _glyphs) {
      final progress = (g.phase + t * g.speed * 3) % 1.0;
      final y = h * 1.1 - progress * h * 1.25;
      final x = g.x * w + math.sin(progress * tau * 1.5 + g.sway) * 24;
      // Fade in at the bottom, out at the top.
      final fade = math.sin(progress * math.pi);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(g.spin * math.sin(progress * tau));
      final tp = g.painterAt(0.3 * fade);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  /// Retro perspective grid scrolling toward the viewer.
  void _paintGrid(Canvas canvas, Size size, double t) {
    final w = size.width, h = size.height;
    final horizon = h * 0.68;
    final rect = Rect.fromLTRB(0, horizon, w, h);
    final paint = Paint()
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.secondary.withValues(alpha: 0),
          AppColors.secondary.withValues(alpha: 0.55),
          AppColors.primary.withValues(alpha: 0.35),
        ],
      ).createShader(rect);

    // Horizontal lines: spacing grows toward the viewer.
    final scroll = (t * 40) % 1.0;
    for (var i = 0; i < 14; i++) {
      final z = (i + scroll) / 14; // 0 = horizon, 1 = bottom
      final y = horizon + (h - horizon) * z * z;
      canvas.drawLine(Offset(0, y), Offset(w, y), paint);
    }
    // Vertical lines converging on a vanishing point.
    final vp = Offset(w / 2, horizon);
    for (var i = -10; i <= 10; i++) {
      canvas.drawLine(vp, Offset(w / 2 + i * w * 0.18, h), paint);
    }
    // Horizon glow.
    canvas.drawRect(
      Rect.fromLTRB(0, horizon - 2, w, horizon + 2),
      Paint()
        ..color = AppColors.secondary.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => false;
}
