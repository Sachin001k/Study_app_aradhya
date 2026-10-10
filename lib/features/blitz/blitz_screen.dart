import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_button.dart';
import '../game/content.dart';
import '../game/game_state.dart';
import 'results_screen.dart';

/// Timed question round: speed + accuracy → XP, combo and rating.
class BlitzScreen extends StatefulWidget {
  const BlitzScreen({
    super.key,
    required this.title,
    required this.questions,
    this.task,
    this.xpMultiplier = 1,
  });

  final String title;
  final List<Question> questions;
  final MissionTask? task;
  final int xpMultiplier;

  @override
  State<BlitzScreen> createState() => _BlitzScreenState();
}

class _BlitzScreenState extends State<BlitzScreen>
    with SingleTickerProviderStateMixin {
  static const _limit = Duration(seconds: 30);

  late final AnimationController _timer =
      AnimationController(vsync: this, duration: _limit)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _submit(-1);
        });
  final _stopwatch = Stopwatch();
  late final SessionSummary _session = gameState.startSession(
    widget.title,
    widget.questions.length,
  );

  int _index = 0;
  int _combo = 0;
  int? _chosen;
  AnswerResult? _result;

  Question get _q => widget.questions[_index];

  @override
  void initState() {
    super.initState();
    _startQuestion();
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  void _startQuestion() {
    _chosen = null;
    _result = null;
    _stopwatch
      ..reset()
      ..start();
    _timer.forward(from: 0);
  }

  void _submit(int option) {
    if (_result != null) return;
    _timer.stop();
    _stopwatch.stop();
    final result = gameState.answer(
      question: _q,
      chosen: option,
      taken: _stopwatch.elapsed,
      limit: _limit,
      combo: _combo,
      session: _session,
      xpMultiplier: widget.xpMultiplier,
    );
    setState(() {
      _chosen = option;
      _result = result;
      _combo = result.correct ? _combo + 1 : 0;
      if (_combo > _session.bestCombo) _session.bestCombo = _combo;
    });
  }

  void _next() {
    if (_index + 1 < widget.questions.length) {
      setState(() => _index++);
      _startQuestion();
      return;
    }
    gameState.finishSession(_session, task: widget.task);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultsScreen(session: _session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final concept = conceptById[_q.conceptId]!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
                    progress:
                        (_index + (_result == null ? 0 : 1)) /
                        widget.questions.length,
                    combo: _combo,
                    xp: _session.xp,
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _timer,
                    builder: (_, _) => _TimerBar(value: 1 - _timer.value),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _Tag(concept.name),
                      if (widget.xpMultiplier > 1) ...[
                        const SizedBox(width: 8),
                        _Tag('${widget.xpMultiplier}× XP', color: AppColors.xp),
                      ],
                      const Spacer(),
                      Text(
                        '${_index + 1}/${widget.questions.length}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        Text(
                          _q.prompt,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 24),
                        for (var i = 0; i < _q.options.length; i++)
                          _OptionButton(
                            letter: String.fromCharCode(65 + i),
                            text: _q.options[i],
                            state: _optionState(i),
                            onTap: _result == null ? () => _submit(i) : null,
                          ),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, anim) => SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(anim),
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: _result == null
                          ? const SizedBox.shrink()
                          : _Feedback(
                              key: ValueKey(_index),
                              question: _q,
                              result: _result!,
                              timedOut: _chosen == -1,
                              isLast: _index + 1 == widget.questions.length,
                              onContinue: _next,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _OptionState _optionState(int i) {
    if (_result == null) return _OptionState.idle;
    if (i == _q.answer) return _OptionState.correct;
    if (i == _chosen) return _OptionState.wrong;
    return _OptionState.dimmed;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.progress,
    required this.combo,
    required this.xp,
  });

  final double progress;
  final int combo;
  final int xp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 300),
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 12,
                backgroundColor: AppColors.surfaceHigh,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        AnimatedScale(
          scale: combo >= 2 ? 1 : 0.85,
          duration: const Duration(milliseconds: 200),
          child: Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: combo >= 2 ? AppColors.streak : AppColors.notStudied,
              ),
              Text(
                '${combo}x',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: combo >= 2 ? AppColors.streak : AppColors.notStudied,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.bolt_rounded, color: AppColors.xp, size: 20),
        TweenAnimationBuilder<int>(
          tween: IntTween(end: xp),
          duration: const Duration(milliseconds: 500),
          builder: (_, v, _) => Text(
            '$v',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.xp,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _TimerBar extends StatelessWidget {
  const _TimerBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final color = value > 0.5
        ? AppColors.mastered
        : value > 0.2
        ? AppColors.weak
        : AppColors.misconception;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 6,
        backgroundColor: AppColors.surface,
        color: color,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.color = AppColors.secondary});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String letter;
  final String text;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (border, fill) = switch (state) {
      _OptionState.correct => (
        AppColors.mastered,
        AppColors.mastered.withValues(alpha: 0.15),
      ),
      _OptionState.wrong => (
        AppColors.misconception,
        AppColors.misconception.withValues(alpha: 0.15),
      ),
      _ => (AppColors.border, AppColors.surface),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: state == _OptionState.dimmed ? 0.4 : 1,
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: border, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      letter,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (state == _OptionState.correct)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.mastered,
                    ),
                  if (state == _OptionState.wrong)
                    const Icon(
                      Icons.cancel_rounded,
                      color: AppColors.misconception,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    super.key,
    required this.question,
    required this.result,
    required this.timedOut,
    required this.isLast,
    required this.onContinue,
  });

  final Question question;
  final AnswerResult result;
  final bool timedOut;
  final bool isLast;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final correct = result.correct;
    final color = correct ? AppColors.mastered : AppColors.misconception;
    final diagnosis = result.diagnosis;
    final sign = result.ratingDelta >= 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        correct
                            ? 'Nailed it!'
                            : timedOut
                            ? 'Time’s up!'
                            : 'Not quite',
                        style: TextStyle(
                          color: color,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (result.xp > 0)
                        _Pop(
                          child: Text(
                            '+${result.xp} XP',
                            style: const TextStyle(
                              color: AppColors.xp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Text(
                        '$sign${result.ratingDelta}',
                        style: TextStyle(
                          color: result.ratingDelta >= 0
                              ? AppColors.primary
                              : AppColors.misconception,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if (!correct) ...[
                    const SizedBox(height: 8),
                    Text(
                      question.explanation,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                  if (diagnosis != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.psychology_alt_rounded,
                            color: AppColors.misconception,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Root cause: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(
                                    text: diagnosis.rootCause.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.misconception,
                                    ),
                                  ),
                                  TextSpan(text: '\n${diagnosis.explanation}'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (result.repaired != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '🗡️ Misconception repaired: ${result.repaired!.name}',
                      style: const TextStyle(
                        color: AppColors.mastered,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          GameButton(
            label: isLast ? 'See results' : 'Continue',
            color: correct ? AppColors.primary : AppColors.misconception,
            shadowColor: correct
                ? AppColors.primaryShadow
                : const Color(0xFFB02A44),
            textColor: correct
                ? AppColors.textOnPrimary
                : AppColors.textPrimary,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

/// Small scale-in "pop" used for XP rewards.
class _Pop extends StatelessWidget {
  const _Pop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: child,
    );
  }
}
