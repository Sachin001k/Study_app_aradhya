import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/layout.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../game/content.dart';
import '../game/game_state.dart';
import 'arcade_widgets.dart';
import 'game_modes.dart';
import 'rush_screen.dart';

/// Survival: 3 lives, 15 s per question, difficulty rises every 4 correct.
class SurvivalScreen extends StatefulWidget {
  const SurvivalScreen({super.key});

  @override
  State<SurvivalScreen> createState() => _SurvivalScreenState();
}

class _SurvivalScreenState extends State<SurvivalScreen> {
  static const _perQuestion = Duration(seconds: 15);
  static const _color = AppColors.misconception;

  final _s = gameState.startSession('Survival', 0, mode: 'survival');
  final _watch = Stopwatch();
  final _rand = math.Random();
  Timer? _tick;
  bool _started = false;
  bool _ended = false;
  int _lives = 3;
  int _combo = 0;
  int? _chosen;
  late Question _q = _next();

  /// Stage 1–5: levels 1–3 on known concepts, then every concept.
  int get _stage => 1 + _s.correct ~/ 4;

  Question _next() {
    final level = math.min(3, _stage);
    final ids = _stage > 3
        ? concepts.map((c) => c.id).toList()
        : gameState.unlockedConceptIds;
    return questionGen.forConcept(ids[_rand.nextInt(ids.length)], level: level);
  }

  void _start() {
    setState(() => _started = true);
    _watch.start();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_chosen == null && _watch.elapsed >= _perQuestion) {
        _answer(-1);
      } else {
        setState(() {});
      }
    });
  }

  void _answer(int i) {
    if (_chosen != null || _ended) return;
    _watch.stop();
    final r = gameState.answer(
      question: _q,
      chosen: i,
      taken: _watch.elapsed,
      limit: _perQuestion,
      combo: _combo,
      session: _s,
    );
    _s.total++;
    if (r.correct) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
      _lives--;
    }
    setState(() {
      _chosen = i;
      _combo = r.correct ? _combo + 1 : 0;
      if (_combo > _s.bestCombo) _s.bestCombo = _combo;
    });
    Future.delayed(Duration(milliseconds: r.correct ? 300 : 900), () {
      if (!mounted || _ended) return;
      if (_lives <= 0) return _end();
      setState(() {
        _q = _next();
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
    final left =
        1 - _watch.elapsed.inMilliseconds / _perQuestion.inMilliseconds;
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
                        title: 'Survival',
                        color: _color,
                        trailing: [
                          LivesRow(lives: _lives),
                          HudChip(
                            icon: Icons.stairs_rounded,
                            text: 'LV $_stage',
                            color: AppColors.weak,
                          ),
                          HudChip(
                            icon: Icons.check_circle_rounded,
                            text: '${_s.correct}',
                            color: AppColors.mastered,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TimeBar(fraction: _chosen == null ? left : 0),
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
