import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/game_button.dart';
import '../../game/game_state.dart';
import '../../entry/game_entry_screen.dart';
import '../data/auth_repository.dart';

/// Three quick questions after sign-up. Answers feed the mission planner
/// (daily minutes) and seed the knowledge graph (goal + subjects).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _step = 0;

  String? _goal;
  final Set<String> _subjects = {};
  int? _minutes;

  static const _goals = [
    ('Class 9–10', Icons.school_rounded),
    ('Class 11–12', Icons.auto_stories_rounded),
    ('JEE', Icons.calculate_rounded),
    ('NEET', Icons.biotech_rounded),
    ('Just curious', Icons.psychology_rounded),
  ];
  static const _subjectOptions = [
    'Maths',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'Computer Science',
  ];
  static const _minuteOptions = [
    (10, 'Casual'),
    (20, 'Regular'),
    (38, 'Serious'),
    (60, 'Beast mode'),
  ];

  bool get _canContinue => switch (_step) {
    0 => _goal != null,
    1 => _subjects.isNotEmpty,
    _ => _minutes != null,
  };

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
      _pages.animateToPage(
        _step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    // TODO: persist goal/subjects/minutes to the user's profile document.
    gameState.completeOnboarding(
      goal: _goal!,
      subjects: _subjects,
      minutes: _minutes!,
    );
    enterGame(context);
  }

  void _back() {
    setState(() => _step--);
    _pages.animateToPage(
      _step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _step == 0 ? null : _back,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: (_step + 1) / 3),
                            duration: const Duration(milliseconds: 300),
                            builder: (_, value, _) => LinearProgressIndicator(
                              value: value,
                              minHeight: 12,
                              backgroundColor: AppColors.surfaceHigh,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _Step(
                          title: 'What are you preparing for?',
                          child: Column(
                            children: [
                              for (final (label, icon) in _goals)
                                _OptionTile(
                                  label: label,
                                  icon: icon,
                                  selected: _goal == label,
                                  onTap: () => setState(() => _goal = label),
                                ),
                            ],
                          ),
                        ),
                        _Step(
                          title: 'Pick your subjects',
                          subtitle:
                              'We\'ll build a knowledge map for each one.',
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final s in _subjectOptions)
                                _SubjectChip(
                                  label: s,
                                  selected: _subjects.contains(s),
                                  onTap: () => setState(() {
                                    _subjects.contains(s)
                                        ? _subjects.remove(s)
                                        : _subjects.add(s);
                                  }),
                                ),
                            ],
                          ),
                        ),
                        _Step(
                          title: 'Daily mission length',
                          subtitle: 'You can change this any time.',
                          child: Column(
                            children: [
                              for (final (mins, label) in _minuteOptions)
                                _OptionTile(
                                  label: '$mins min · $label',
                                  icon: Icons.timer_rounded,
                                  selected: _minutes == mins,
                                  onTap: () => setState(() => _minutes = mins),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  GameButton(
                    label: _step < 2 ? 'Continue' : 'Start my first mission',
                    onPressed: _canContinue ? _next : null,
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

class _Step extends StatelessWidget {
  const _Step({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.secondary : AppColors.border,
            width: 2,
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
