import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../game/game_state.dart';
import 'arcade_widgets.dart';
import 'game_modes.dart';
import 'rush_screen.dart';

/// Number Crunch: typed mental maths. The answer checks itself as you type.
class CrunchScreen extends StatefulWidget {
  const CrunchScreen({super.key});

  @override
  State<CrunchScreen> createState() => _CrunchScreenState();
}

class _CrunchScreenState extends State<CrunchScreen> {
  static const _length = Duration(seconds: 60);
  static const _color = AppColors.primary;

  final _s = gameState.startSession('Number Crunch', 0, mode: 'crunch');
  final _watch = Stopwatch();
  final _focus = FocusNode();
  Timer? _tick;
  DateTime? _endsAt;
  bool _started = false;
  bool _ended = false;
  int _combo = 0;
  String _input = '';
  bool? _flash;
  var _p = questionGen.arithmetic(1);

  int get _level => 1 + _s.correct ~/ 4;

  Duration get _left =>
      _endsAt == null ? _length : _endsAt!.difference(DateTime.now());

  void _start() {
    _endsAt = DateTime.now().add(_length);
    _watch.start();
    _focus.requestFocus();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_left <= Duration.zero) {
        _end();
      } else {
        setState(() {});
      }
    });
    setState(() => _started = true);
  }

  void _key(String k) {
    if (!_started || _ended || _flash != null) return;
    setState(() {
      if (k == '⌫') {
        if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
        return;
      }
      if (_input.length < 6) _input += k;
    });
    final target = '${_p.answer}';
    if (_input == target) {
      _submit(int.parse(_input));
    } else if (_input.length >= target.length) {
      _submit(int.tryParse(_input));
    }
  }

  void _submit(int? given) {
    final right = given == _p.answer;
    gameState.recordArithmetic(
      session: _s,
      prompt: _p.prompt,
      answer: _p.answer,
      given: given,
      taken: _watch.elapsed,
      combo: _combo,
    );
    _s.total++;
    right ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    setState(() {
      _flash = right;
      _combo = right ? _combo + 1 : 0;
      if (_combo > _s.bestCombo) _s.bestCombo = _combo;
    });
    Future.delayed(Duration(milliseconds: right ? 180 : 650), () {
      if (!mounted || _ended) return;
      setState(() {
        _p = questionGen.arithmetic(_level);
        _input = '';
        _flash = null;
      });
      _watch
        ..reset()
        ..start();
    });
  }

  void _skip() {
    if (_flash != null || !_started) return;
    _submit(null);
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
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final ch = e.character;
    if (ch != null && RegExp(r'^[0-9]$').hasMatch(ch)) {
      _key(ch);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _key('⌫');
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final secs = (_left.inMilliseconds / 1000).ceil().clamp(0, 60);
    final display = _flash == false
        ? '${_p.answer}'
        : (_input.isEmpty ? '?' : _input);
    final displayColor = switch (_flash) {
      true => AppColors.mastered,
      false => AppColors.misconception,
      null => _input.isEmpty ? AppColors.textSecondary : AppColors.textPrimary,
    };
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 460,
                    maxHeight: kPlayMaxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    child: Column(
                      children: [
                        ArcadeHud(
                          title: 'Number Crunch',
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
                          fraction:
                              _left.inMilliseconds / _length.inMilliseconds,
                        ),
                        const SizedBox(height: 12),
                        ComboText(combo: _combo),
                        const Spacer(),
                        Text(
                          'LEVEL $_level',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          child: Text(
                            '${_p.prompt} =',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 120),
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            color: displayColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          child: Text(display),
                        ),
                        const Spacer(),
                        _Keypad(onKey: _key, onSkip: _skip),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!_started) GameCountdown(color: _color, onDone: _start),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey, required this.onSkip});

  final ValueChanged<String> onKey;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, VoidCallback onTap, {Color? color}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Material(
          color: color ?? AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final k in row) key(k, () => onKey(k))]),
        Row(
          children: [
            key('Skip', onSkip, color: AppColors.surfaceHigh),
            key('0', () => onKey('0')),
            key('⌫', () => onKey('⌫'), color: AppColors.surfaceHigh),
          ],
        ),
      ],
    );
  }
}
