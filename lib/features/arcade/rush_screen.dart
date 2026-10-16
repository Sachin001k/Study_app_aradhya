import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../game/content.dart';
import '../game/game_state.dart';
import 'arcade_widgets.dart';
import 'game_modes.dart';

/// Speed Rush: as many generated questions as possible in 60 seconds.
class RushScreen extends StatefulWidget {
  const RushScreen({super.key});

  @override
  State<RushScreen> createState() => _RushScreenState();
}

class _RushScreenState extends State<RushScreen> {
  static const _length = Duration(seconds: 60);
  static const _color = AppColors.xp;

  final _s = gameState.startSession('Speed Rush', 0, mode: 'rush');
  final _watch = Stopwatch();
  Timer? _tick;
  DateTime? _endsAt;
  bool _started = false;
  bool _ended = false;
  Question _q = gameState.randomQuestion();
  int _combo = 0;
  int? _chosen;

  Duration get _left =>
      _endsAt == null ? _length : _endsAt!.difference(DateTime.now());

  void _start() {
    _endsAt = DateTime.now().add(_length);
    _watch.start();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_left <= Duration.zero) {
        _end();
      } else {
        setState(() {});
      }
    });
    setState(() => _started = true);
  }

  void _answer(int i) {
    if (_chosen != null || _ended) return;
    final r = gameState.answer(
      question: _q,
      chosen: i,
      taken: _watch.elapsed,
      limit: const Duration(seconds: 8),
      combo: _combo,
      session: _s,
    );
    _s.total++;
    r.correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    setState(() {
      _chosen = i;
      _combo = r.correct ? _combo + 1 : 0;
      if (_combo > _s.bestCombo) _s.bestCombo = _combo;
    });
    Future.delayed(Duration(milliseconds: r.correct ? 250 : 700), () {
      if (!mounted || _ended) return;
      setState(() {
        _q = gameState.randomQuestion();
        _chosen = null;
      });
      _watch
        ..reset()
        ..start();
    });
  }

  void _end() {
    if (_ended) return;
    _ended = true;
    _tick?.cancel();
    _s.score = _s.correct;
    endArcadeGame(context, _s);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secs = (_left.inMilliseconds / 1000).ceil().clamp(0, 60);
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  child: Column(
                    children: [
                      ArcadeHud(
                        title: 'Speed Rush',
                        color: _color,
                        trailing: [
                          HudChip(
                            icon: Icons.timer_rounded,
                            text: '${secs}s',
                            color: _color,
                          ),
                          HudChip(
                            icon: Icons.check_circle_rounded,
                            text: '${_s.correct}',
                            color: AppColors.mastered,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TimeBar(
                        fraction: _left.inMilliseconds / _length.inMilliseconds,
                      ),
                      const SizedBox(height: 12),
                      ComboText(combo: _combo),
                      const Spacer(),
                      PromptCard(
                        text: _q.prompt,
                        color: _color,
                        label: conceptById[_q.conceptId]!.name.toUpperCase(),
                      ),
                      const SizedBox(height: 20),
                      OptionGrid(
                        options: _q.options,
                        onTap: _chosen == null ? _answer : null,
                        correct: _chosen == null ? null : _q.answer,
                        chosen: _chosen,
                      ),
                      const Spacer(flex: 2),
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

/// "🔥 4× COMBO" label that pops as the combo grows.
class ComboText extends StatelessWidget {
  const ComboText({super.key, required this.combo});

  final int combo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: combo < 2
          ? null
          : TweenAnimationBuilder<double>(
              key: ValueKey(combo),
              tween: Tween(begin: 1.4, end: 1),
              duration: const Duration(milliseconds: 300),
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: Text(
                '🔥 $combo× COMBO',
                style: const TextStyle(
                  color: AppColors.streak,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
    );
  }
}
