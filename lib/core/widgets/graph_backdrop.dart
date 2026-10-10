import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Slowly drifting knowledge-graph nodes, used behind auth screens as a
/// preview of the app's signature feature.
class GraphBackdrop extends StatefulWidget {
  const GraphBackdrop({super.key, this.opacity = 1});

  final double opacity;

  @override
  State<GraphBackdrop> createState() => _GraphBackdropState();
}

class _GraphBackdropState extends State<GraphBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: widget.opacity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _GraphPainter(_controller.value),
          ),
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter(this.t);

  final double t;

  // Relative node positions + state colour.
  static const _nodes = <(double, double, Color)>[
    (0.15, 0.12, AppColors.mastered),
    (0.45, 0.08, AppColors.mastered),
    (0.80, 0.16, AppColors.weak),
    (0.28, 0.30, AppColors.mastered),
    (0.65, 0.34, AppColors.misconception),
    (0.90, 0.42, AppColors.notStudied),
    (0.10, 0.50, AppColors.weak),
    (0.42, 0.55, AppColors.notStudied),
    (0.75, 0.62, AppColors.mastered),
    (0.20, 0.78, AppColors.notStudied),
    (0.55, 0.85, AppColors.weak),
    (0.88, 0.88, AppColors.notStudied),
  ];

  static const _edges = <(int, int)>[
    (0, 3),
    (1, 3),
    (1, 4),
    (2, 4),
    (2, 5),
    (3, 6),
    (3, 7),
    (4, 7),
    (4, 8),
    (5, 8),
    (6, 9),
    (7, 10),
    (8, 10),
    (8, 11),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    Offset pos(int i) {
      final (x, y, _) = _nodes[i];
      final phase = t * 2 * math.pi + i;
      return Offset(
        x * size.width + math.sin(phase) * 8,
        y * size.height + math.cos(phase * 0.8) * 8,
      );
    }

    final edgePaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    for (final (a, b) in _edges) {
      canvas.drawLine(pos(a), pos(b), edgePaint);
    }

    for (var i = 0; i < _nodes.length; i++) {
      final color = _nodes[i].$3;
      // The "fading" effect: grey nodes pulse in and out like fading memories.
      final fade = color == AppColors.notStudied
          ? 0.35 + 0.25 * math.sin(t * 2 * math.pi + i)
          : 0.9;
      final c = pos(i);
      canvas.drawCircle(
        c,
        14,
        Paint()
          ..color = color.withValues(alpha: 0.18 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(c, 6, Paint()..color = color.withValues(alpha: fade));
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) => old.t != t;
}
