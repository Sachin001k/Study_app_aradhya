import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_button.dart';
import '../game/game_state.dart';
import 'arcade_widgets.dart';
import 'game_modes.dart';
import 'rush_screen.dart';

/// True or False: judge generated statements; false ones are usually traps.
class TrueFalseScreen extends StatefulWidget {
  const TrueFalseScreen({super.key});

  @override
  State<TrueFalseScreen> createState() => _TrueFalseScreenState();
}

class _TrueFalseScreenState extends State<TrueFalseScreen> {
  static const _length = Duration(seconds: 45);
  static const _color = AppColors.secondary;

  final _s = gameState.startSession('True or False', 0, mode: 'truefalse');
  final _watch = Stopwatch();
  Timer? _tick;
  DateTime? _endsAt;
  bool _started = false;
  bool _ended = false;
  int _combo = 0;

  /// Feedback for the last answer: true = right, false = wrong.
  bool? _flash;
  var _st = questionGen.statement(gameState.unlockedConceptIds);

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

  void _judge(bool saysTrue) {
    if (_flash != null || _ended) return;
    final right = saysTrue == _st.isTrue;
    // Map onto the question so diagnosis still works: accepting a false
    // statement means choosing that (often trap) option.
    final chosen = right ? _st.question.answer : (saysTrue ? _st.shown : -1);
    gameState.answer(
      question: _st.question,
      chosen: chosen,
      taken: _watch.elapsed,
      limit: const Duration(seconds: 6),
      combo: _combo,
      session: _s,
    );
    _s.total++;
    right ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    setState(() {
      _flash = right;
      _combo = right ? _combo + 1 : 0;
      if (_combo > _s.bestCombo) _s.bestCombo = _combo;
    });
    Future.delayed(Duration(milliseconds: right ? 250 : 800), () {
      if (!mounted || _ended) return;
      setState(() {
        _st = questionGen.statement(gameState.unlockedConceptIds);
        _flash = null;
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
    final secs = (_left.inMilliseconds / 1000).ceil().clamp(0, 45);
    final flashColor = switch (_flash) {
      true => AppColors.mastered,
      false => AppColors.misconception,
      null => _color,
    };
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ArcadeHud(
                        title: 'True or False',
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
                      Center(child: ComboText(combo: _combo)),
                      const Spacer(),
                      AnimatedScale(
                        scale: _flash == null ? 1 : 0.96,
                        duration: const Duration(milliseconds: 120),
                        child: PromptCard(
                          text: _st.text,
                          color: flashColor,
                          label: _flash == null
                              ? 'TRUE OR FALSE?'
                              : _flash!
                              ? 'CORRECT!'
                              : 'NOPE — IT WAS ${_st.isTrue ? 'TRUE' : 'FALSE'}',
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: GameButton(
                              label: '✗ False',
                              color: AppColors.misconception,
                              shadowColor: const Color(0xFFB02A44),
                              textColor: AppColors.textPrimary,
                              onPressed: () => _judge(false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GameButton(
                              label: '✓ True',
                              color: AppColors.mastered,
                              shadowColor: const Color(0xFF23934F),
                              onPressed: () => _judge(true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
