import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_button.dart';
import '../blitz/blitz_screen.dart';
import '../game/content.dart';
import '../game/game_state.dart';

/// The 5-minute "Learn" step: swipeable key-idea cards, then a blitz.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.concept, this.task});

  final Concept concept;
  final MissionTask? task;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final _pages = PageController();
  late final Timer _ticker;
  int _secondsLeft = 5 * 60;
  int _page = 0;

  int get _pageCount => widget.concept.keyPoints.length + 1;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft > 0) setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BlitzScreen(
          title: widget.concept.name,
          questions: widget.task != null
              ? gameState.questionsForTask(widget.task!)
              : questionGen.batch([widget.concept.id], 4, level: 1),
          task: widget.task,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.concept;
    final mm = (_secondsLeft ~/ 60).toString();
    final ss = (_secondsLeft % 60).toString().padLeft(2, '0');
    final isLast = _page == _pageCount - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('5-min learn'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$mm:$ss',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 520,
              maxHeight: kPlayMaxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    c.name,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Then a quick blitz with fresh questions',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      onPageChanged: (p) => setState(() => _page = p),
                      children: [
                        for (var i = 0; i < c.keyPoints.length; i++)
                          _Card(
                            label: 'KEY IDEA ${i + 1}',
                            color: AppColors.secondary,
                            text: c.keyPoints[i],
                          ),
                        _Card(
                          label: 'WORKED EXAMPLE',
                          color: AppColors.primary,
                          text: c.example,
                          mono: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pageCount; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? AppColors.primary
                                : AppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GameButton(
                    label: isLast ? 'Start blitz ⚡' : 'Next',
                    onPressed: _next,
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

class _Card extends StatelessWidget {
  const _Card({
    required this.label,
    required this.color,
    required this.text,
    this.mono = false,
  });

  final String label;
  final Color color;
  final String text;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    // Sized to its text and centred in the page, so a short key idea doesn't
    // sit inside a screen-tall empty box. Long text scrolls instead.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 220),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                text,
                style: TextStyle(
                  fontSize: mono ? 22 : 24,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
