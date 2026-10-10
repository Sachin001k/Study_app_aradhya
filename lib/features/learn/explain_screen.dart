import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_button.dart';
import '../blitz/results_screen.dart';
import '../game/content.dart';
import '../game/game_state.dart';

/// "Explain one concept aloud" (Feynman technique). Recording is simulated
/// for now; later speech-to-text + AI will grade the explanation.
class ExplainScreen extends StatefulWidget {
  const ExplainScreen({super.key, required this.concept, this.task});

  final Concept concept;
  final MissionTask? task;

  @override
  State<ExplainScreen> createState() => _ExplainScreenState();
}

class _ExplainScreenState extends State<ExplainScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _ticker;
  int _seconds = 0;
  bool _recording = false;
  bool _reviewing = false;
  final Set<int> _covered = {};

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_recording) {
      _ticker?.cancel();
      _pulse.stop();
      setState(() {
        _recording = false;
        _reviewing = true;
      });
      return;
    }
    _pulse.repeat(reverse: true);
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _seconds++),
    );
    setState(() => _recording = true);
  }

  void _finish() {
    final session = gameState.startSession(
      'Explain: ${widget.concept.name}',
      widget.concept.keyPoints.length,
    );
    gameState.recordExplanation(session, widget.concept.id, _covered.length);
    gameState.finishSession(session, task: widget.task);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultsScreen(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.concept;
    return Scaffold(
      appBar: AppBar(title: const Text('Explain it aloud')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Teach “${c.name}” to a friend',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Explaining out loud is one of the strongest ways to lock in '
                  'memory. Aim for about a minute, in your own words.',
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 40),
                Center(
                  child: GestureDetector(
                    onTap: _reviewing ? null : _toggle,
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, child) => Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _recording
                              ? AppColors.misconception
                              : AppColors.secondary,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_recording
                                          ? AppColors.misconception
                                          : AppColors.secondary)
                                      .withValues(alpha: 0.5),
                              blurRadius: 20 + 30 * _pulse.value,
                              spreadRadius: 4 * _pulse.value,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                      child: Icon(
                        _recording ? Icons.stop_rounded : Icons.mic_rounded,
                        size: 64,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _reviewing
                      ? 'Recorded ${_seconds}s'
                      : _recording
                      ? 'Listening… ${_seconds}s  ·  tap to stop'
                      : 'Tap to start',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_reviewing) ...[
                  const SizedBox(height: 32),
                  const Text(
                    'Which of these did you cover?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < c.keyPoints.length; i++)
                    CheckboxListTile(
                      value: _covered.contains(i),
                      activeColor: AppColors.primary,
                      checkColor: AppColors.textOnPrimary,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(c.keyPoints[i]),
                      onChanged: (v) => setState(
                        () => v! ? _covered.add(i) : _covered.remove(i),
                      ),
                    ),
                  const SizedBox(height: 20),
                  GameButton(
                    label: 'Claim +${_covered.length * 10} XP',
                    onPressed: _finish,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
