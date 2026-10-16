import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../game/game_state.dart';
import '../shell/app_shell.dart';

/// Plays the "level start" sequence after login, then lands on Home.
void enterGame(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) => const GameEntryScreen(),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
    (_) => false,
  );
}

/// Arcade-style transition: flash + shockwave, hyperspace star warp,
/// "PLAYER READY" title slam, loading bar, then "GO!" and a zoom into Home.
class GameEntryScreen extends StatefulWidget {
  const GameEntryScreen({super.key});

  @override
  State<GameEntryScreen> createState() => _GameEntryScreenState();
}

class _GameEntryScreenState extends State<GameEntryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  bool _goBuzzed = false;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _c
      ..addListener(() {
        if (!_goBuzzed && _c.value > 0.82) {
          _goBuzzed = true;
          HapticFeedback.mediumImpact();
        }
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _goHome();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _goHome() {
    if (!mounted || _left) return;
    _left = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, _, _) => const AppShell(),
        transitionsBuilder: (_, anim, _, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 1.15, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  /// Maps the controller to a 0→1 sub-interval with a curve.
  double _seg(double begin, double end, [Curve curve = Curves.linear]) =>
      curve.transform(((_c.value - begin) / (end - begin)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final tier = tierFor(gameState.rating);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Tap to skip.
        onTap: _goHome,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final slam = _seg(0.12, 0.42, Curves.elasticOut);
            final info = _seg(0.36, 0.5, Curves.easeOut);
            final load = _seg(0.45, 0.8, Curves.easeInOutCubic);
            final go = _seg(0.82, 1.0, Curves.easeOutCubic);
            final textOut = 1 - _seg(0.8, 0.88);

            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _WarpPainter(
                    t: _c.value,
                    speed: _seg(0, 0.85, Curves.easeInQuad),
                    shock: _seg(0, 0.35, Curves.easeOutCubic),
                  ),
                ),
                // Opening flash.
                IgnorePointer(
                  child: ColoredBox(
                    color: Colors.white.withValues(
                      alpha: 0.7 * (1 - _seg(0, 0.14, Curves.easeOut)),
                    ),
                  ),
                ),
                Center(
                  child: Opacity(
                    opacity: textOut,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: _seg(0.08, 0.18),
                          child: const Text(
                            'PLAYER READY',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Transform.scale(
                          scale: 3 - 2 * slam,
                          child: Opacity(
                            opacity: _seg(0.12, 0.2),
                            child: _GlowText(
                              gameState.displayName.toUpperCase(),
                              size: 44,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Opacity(
                          opacity: info,
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - info)),
                            child: Wrap(
                              spacing: 8,
                              children: [
                                _Pill(
                                  'LV ${gameState.level}',
                                  AppColors.primary,
                                ),
                                _Pill(
                                  '${tier.name.toUpperCase()} ${gameState.rating}',
                                  Color(tier.color),
                                ),
                                _Pill(
                                  '🔥 ${gameState.streak}',
                                  AppColors.streak,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Opacity(
                          opacity: _seg(0.42, 0.5),
                          child: SizedBox(
                            width: 240,
                            child: Column(
                              children: [
                                Text(
                                  load < 1
                                      ? 'LOADING MISSION…'
                                      : 'MISSION LOADED',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 3,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _LoadBar(value: load),
                                const SizedBox(height: 6),
                                Text(
                                  '${(load * 100).round()}%',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (go > 0)
                  Center(
                    child: Opacity(
                      opacity: math.sin(go * math.pi).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.6 + go * 2.4,
                        child: const _GlowText('GO!', size: 96),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: 0.5 * textOut,
                    child: const Text(
                      'tap to skip',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GlowText extends StatelessWidget {
  const _GlowText(this.text, {required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 2,
        shadows: const [
          Shadow(color: AppColors.primary, blurRadius: 24),
          Shadow(color: AppColors.secondary, blurRadius: 48),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _LoadBar extends StatelessWidget {
  const _LoadBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: const LinearGradient(
                colors: [AppColors.secondary, AppColors.primary],
              ),
              boxShadow: const [
                BoxShadow(color: AppColors.primary, blurRadius: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hyperspace star streaks radiating from the centre plus a shockwave ring.
class _WarpPainter extends CustomPainter {
  _WarpPainter({required this.t, required this.speed, required this.shock});

  final double t;
  final double speed;
  final double shock;

  static final _rand = math.Random(42);
  static final _stars = List.generate(
    180,
    (_) => (
      angle: _rand.nextDouble() * 2 * math.pi,
      depth: _rand.nextDouble(),
      color: [
        Colors.white,
        AppColors.primary,
        AppColors.secondary,
        const Color(0xFFF472B6),
      ][_rand.nextInt(4)],
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.longestSide * 0.75;

    // Central glow that grows with speed.
    final glowR = maxR * (0.4 + 0.8 * speed);
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.secondary.withValues(alpha: 0.45),
            AppColors.secondary.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: glowR)),
    );

    for (final s in _stars) {
      // Each star travels outward; faster as the warp builds.
      final d = (s.depth + t * (0.6 + 3.5 * speed)) % 1.0;
      final r = maxR * d * d;
      final streak = 6 + 140 * speed * d;
      final dir = Offset(math.cos(s.angle), math.sin(s.angle));
      final p1 = c + dir * r;
      final p0 = c + dir * math.max(0, r - streak);
      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1 + 2.5 * d
          ..color = s.color.withValues(alpha: (0.2 + 0.8 * d).clamp(0, 1)),
      );
    }

    // Shockwave ring from the login burst.
    if (shock < 1) {
      canvas.drawCircle(
        c,
        maxR * shock,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18 * (1 - shock)
          ..color = AppColors.primary.withValues(alpha: 0.8 * (1 - shock))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(_WarpPainter old) => true;
}
