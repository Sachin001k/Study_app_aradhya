import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/layout.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../game/game_state.dart';
import 'arcade_widgets.dart';
import 'game_modes.dart';

/// Memory Match: flip cards to pair each expression with its result.
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _Card {
  _Card(this.text, this.pair, {required this.isExpression});

  final String text;
  final int pair;
  final bool isExpression;
}

class _MemoryScreenState extends State<MemoryScreen> {
  static const _pairs = 6;
  static const _color = AppColors.mastered;

  final _s = gameState.startSession('Memory Match', 0, mode: 'memory');
  final _watch = Stopwatch();
  late final List<_Card> _cards;
  final Set<int> _up = {};
  final Set<int> _matched = {};
  Timer? _tick;
  bool _started = false;
  bool _ended = false;
  bool _locked = false;
  int _moves = 0;

  @override
  void initState() {
    super.initState();
    final pairs = questionGen.pairs(_pairs);
    _cards = [
      for (var i = 0; i < pairs.length; i++) ...[
        _Card(pairs[i].$1, i, isExpression: true),
        _Card(pairs[i].$2, i, isExpression: false),
      ],
    ]..shuffle(math.Random());
  }

  void _start() {
    _watch.start();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    setState(() => _started = true);
  }

  void _flip(int i) {
    if (_locked || _ended || _up.contains(i) || _matched.contains(i)) return;
    HapticFeedback.selectionClick();
    setState(() => _up.add(i));
    if (_up.length < 2) return;

    _moves++;
    final [a, b] = _up.toList();
    if (_cards[a].pair == _cards[b].pair) {
      HapticFeedback.lightImpact();
      setState(() {
        _matched.addAll([a, b]);
        _up.clear();
      });
      if (_matched.length == _cards.length) _end();
    } else {
      _locked = true;
      Future.delayed(const Duration(milliseconds: 850), () {
        if (!mounted) return;
        setState(() {
          _up.clear();
          _locked = false;
        });
      });
    }
  }

  void _end() {
    _ended = true;
    _tick?.cancel();
    _watch.stop();
    final secs = _watch.elapsed.inSeconds;
    _s
      ..total = _moves
      ..correct = _pairs
      ..score = math.max(10, 300 - (_moves - _pairs) * 15 - secs);
    gameState.awardXp(_s, 25 + (_moves <= 10 ? 25 : 0), 'memory');
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) endArcadeGame(context, _s);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 560,
                  maxHeight: kPlayMaxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  child: Column(
                    children: [
                      ArcadeHud(
                        title: 'Memory Match',
                        color: _color,
                        trailing: [
                          HudChip(
                            icon: Icons.timer_rounded,
                            text: '${_watch.elapsed.inSeconds}s',
                            color: _color,
                          ),
                          HudChip(
                            icon: Icons.touch_app_rounded,
                            text: '$_moves',
                            color: AppColors.weak,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_matched.length ~/ 2}/$_pairs pairs',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) {
                            const cols = 3, rows = 4, gap = 10.0;
                            // Largest 5:6 card that fits both directions, so
                            // the grid never stretches or overflows.
                            final fitW = (c.maxWidth - gap * (cols - 1)) / cols;
                            final fitH =
                                (c.maxHeight - gap * (rows - 1)) / rows / 1.2;
                            final w = math.min(math.min(fitW, fitH), 150.0);
                            return Center(
                              child: SizedBox(
                                width: w * cols + gap * (cols - 1),
                                child: Wrap(
                                  spacing: gap,
                                  runSpacing: gap,
                                  children: [
                                    for (var i = 0; i < _cards.length; i++)
                                      SizedBox(
                                        width: w,
                                        height: w * 1.2,
                                        child: _FlipCard(
                                          card: _cards[i],
                                          faceUp:
                                              _up.contains(i) ||
                                              _matched.contains(i),
                                          matched: _matched.contains(i),
                                          onTap: () => _flip(i),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!_started) GameCountdown(color: _color, onDone: _start),
        ],
      ),
    );
  }
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({
    required this.card,
    required this.faceUp,
    required this.matched,
    required this.onTap,
  });

  final _Card card;
  final bool faceUp;
  final bool matched;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: faceUp ? 1 : 0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        builder: (context, t, _) {
          final showFront = t >= 0.5;
          final angle = t * math.pi;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(showFront ? angle - math.pi : angle),
            child: showFront ? _front() : _back(),
          );
        },
      ),
    );
  }

  Widget _back() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.secondary, Color(0xFF3B2A7A)],
      ),
      border: Border.all(
        color: AppColors.secondary.withValues(alpha: 0.8),
        width: 2,
      ),
    ),
    child: const Center(
      child: Icon(Icons.bolt_rounded, size: 36, color: AppColors.primary),
    ),
  );

  Widget _front() {
    final color = matched
        ? AppColors.mastered
        : (card.isExpression ? AppColors.xp : AppColors.primary);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: matched
            ? AppColors.mastered.withValues(alpha: 0.15)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            card.text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
