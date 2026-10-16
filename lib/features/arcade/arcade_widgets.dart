import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Full-screen "3 · 2 · 1 · GO!" before a game starts.
class GameCountdown extends StatefulWidget {
  const GameCountdown({super.key, required this.color, required this.onDone});

  final Color color;
  final VoidCallback onDone;

  @override
  State<GameCountdown> createState() => _GameCountdownState();
}

class _GameCountdownState extends State<GameCountdown> {
  int _n = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    HapticFeedback.selectionClick();
    _timer = Timer.periodic(const Duration(milliseconds: 650), (t) {
      if (_n == 0) {
        t.cancel();
        widget.onDone();
        return;
      }
      HapticFeedback.selectionClick();
      setState(() => _n--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background.withValues(alpha: 0.92),
      child: Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(_n),
          tween: Tween(begin: 1.8, end: 1),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutBack,
          builder: (_, s, child) => Transform.scale(scale: s, child: child),
          child: Text(
            _n == 0 ? 'GO!' : '$_n',
            style: TextStyle(
              fontSize: 110,
              fontWeight: FontWeight.w900,
              color: _n == 0 ? AppColors.primary : AppColors.textPrimary,
              shadows: [Shadow(color: widget.color, blurRadius: 40)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Top bar shared by arcade games.
class ArcadeHud extends StatelessWidget {
  const ArcadeHud({
    super.key,
    required this.title,
    required this.color,
    required this.trailing,
  });

  final String title;
  final Color color;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Text(
            title.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...trailing,
        const SizedBox(width: 8),
      ],
    );
  }
}

class HudChip extends StatelessWidget {
  const HudChip({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin bar that drains as time runs out, turning red at the end.
class TimeBar extends StatelessWidget {
  const TimeBar({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final color = fraction > 0.5
        ? AppColors.mastered
        : fraction > 0.2
        ? AppColors.weak
        : AppColors.misconception;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: fraction.clamp(0, 1),
        minHeight: 6,
        backgroundColor: AppColors.surface,
        color: color,
      ),
    );
  }
}

class LivesRow extends StatelessWidget {
  const LivesRow({super.key, required this.lives, this.max = 3});

  final int lives;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++)
          AnimatedScale(
            scale: i < lives ? 1 : 0.7,
            duration: const Duration(milliseconds: 250),
            child: Icon(
              i < lives
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: i < lives ? AppColors.misconception : AppColors.notStudied,
              size: 22,
            ),
          ),
      ],
    );
  }
}

/// 2×2 grid of answer buttons with an instant green/red flash.
class OptionGrid extends StatelessWidget {
  const OptionGrid({
    super.key,
    required this.options,
    required this.onTap,
    this.correct,
    this.chosen,
  });

  final List<String> options;
  final ValueChanged<int>? onTap;

  /// When set, the grid is showing feedback for [chosen].
  final int? correct;
  final int? chosen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 380;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < options.length; i++)
              SizedBox(
                width: wide ? (c.maxWidth - 12) / 2 : c.maxWidth,
                child: _Option(
                  text: options[i],
                  state: correct == null
                      ? null
                      : i == correct
                      ? true
                      : i == chosen
                      ? false
                      : null,
                  onTap: onTap == null ? null : () => onTap!(i),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.text, required this.state, required this.onTap});

  final String text;

  /// true = correct, false = chosen wrong, null = neutral.
  final bool? state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      true => AppColors.mastered,
      false => AppColors.misconception,
      null => AppColors.border,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: state == null ? AppColors.surface : color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

/// Big centred prompt card.
class PromptCard extends StatelessWidget {
  const PromptCard({
    super.key,
    required this.text,
    required this.color,
    this.label,
  });

  final String text;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 30),
        ],
      ),
      child: Column(
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
