import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_button.dart';
import '../game/game_state.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.session, this.replay});

  final SessionSummary session;

  /// Builds a fresh game for "Play again" (arcade modes).
  final Widget Function()? replay;

  (String, String) get _headline => switch (session.outcome) {
    'win' => ('🏆', 'Victory!'),
    'loss' => ('😤', 'Defeated'),
    'draw' => ('🤝', 'Draw!'),
    _ when session.missionCompleted => ('🎯', 'Mission complete!'),
    _ when session.isNewBest => ('🚀', 'New personal best!'),
    _ => ('', ''),
  };

  @override
  Widget build(BuildContext context) {
    final ratingAfter = gameState.rating;
    final delta = ratingAfter - session.ratingBefore;
    final leveledUp = gameState.level > session.levelBefore;
    final accuracy = session.total == 0
        ? 0
        : (100 * session.correct / session.total).round();
    final tier = tierFor(ratingAfter);
    final tomorrow = session.missionCompleted
        ? gameState.previewTomorrow()
        : const <MissionTask>[];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 12),
                Text(
                  _headline.$1.isNotEmpty
                      ? _headline.$1
                      : (accuracy >= 70 ? '🏆' : '💪'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 56),
                ),
                const SizedBox(height: 8),
                Text(
                  _headline.$2.isNotEmpty
                      ? _headline.$2
                      : accuracy >= 70
                      ? 'Great round!'
                      : 'Good fight!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  session.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (session.score != null) ...[
                  const SizedBox(height: 20),
                  _ScoreBanner(session: session),
                ],
                const SizedBox(height: 24),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _StatTile(
                      label: 'XP earned',
                      color: AppColors.xp,
                      icon: Icons.bolt_rounded,
                      child: _CountUp(to: session.xp, prefix: '+'),
                    ),
                    if (session.mode == 'memory')
                      _StatTile(
                        label: 'Moves',
                        color: AppColors.mastered,
                        icon: Icons.touch_app_rounded,
                        child: _CountUp(to: session.total),
                      )
                    else
                      _StatTile(
                        label: 'Accuracy',
                        color: AppColors.mastered,
                        icon: Icons.track_changes_rounded,
                        child: _CountUp(to: accuracy, suffix: '%'),
                      ),
                    _StatTile(
                      label: 'Best combo',
                      color: AppColors.streak,
                      icon: Icons.local_fire_department_rounded,
                      child: _CountUp(to: session.bestCombo, suffix: '×'),
                    ),
                    _StatTile(
                      label: '${tier.name} · ${delta >= 0 ? '+' : ''}$delta',
                      color: Color(tier.color),
                      icon: delta >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      child: _CountUp(
                        from: session.ratingBefore,
                        to: ratingAfter,
                      ),
                    ),
                  ],
                ),
                if (leveledUp) ...[
                  const SizedBox(height: 16),
                  _Banner(
                    color: AppColors.primary,
                    icon: Icons.military_tech_rounded,
                    title: 'Level up! You reached level ${gameState.level}',
                  ),
                ],
                if (session.missionCompleted) ...[
                  const SizedBox(height: 12),
                  const _Banner(
                    color: AppColors.xp,
                    icon: Icons.emoji_events_rounded,
                    title: '+50 XP mission bonus · streak kept alive',
                  ),
                ],
                for (final c in session.repaired) ...[
                  const SizedBox(height: 12),
                  _Banner(
                    color: AppColors.mastered,
                    icon: Icons.healing_rounded,
                    title: 'Misconception repaired: ${c.name}',
                  ),
                ],
                if (session.diagnoses.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionTitle('What we found'),
                  for (final d in session.diagnoses)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.question.prompt,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 10,
                                color: AppColors.misconception,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Real gap: ${d.rootCause.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(d.explanation),
                        ],
                      ),
                    ),
                ],
                if (session.newBadges.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionTitle('Badges unlocked'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final b in session.newBadges)
                        Chip(
                          avatar: Text(b.emoji),
                          label: Text(b.name),
                          backgroundColor: AppColors.surfaceHigh,
                          side: const BorderSide(color: AppColors.xp),
                        ),
                    ],
                  ),
                ],
                if (tomorrow.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    'Tomorrow’s mission (rebuilt from today)',
                  ),
                  for (final t in tomorrow)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.primary,
                      ),
                      title: Text(t.title),
                      subtitle: Text(
                        t.subtitle,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: Text('${t.minutes} min'),
                    ),
                ],
                const SizedBox(height: 28),
                if (replay != null) ...[
                  GameButton(
                    label: 'Play again',
                    icon: const Icon(
                      Icons.replay_rounded,
                      color: AppColors.textOnPrimary,
                    ),
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => replay!()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GameButton.secondary(
                    label: 'Back to arcade',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ] else
                  GameButton(
                    label: 'Continue',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreBanner extends StatelessWidget {
  const _ScoreBanner({required this.session});

  final SessionSummary session;

  @override
  Widget build(BuildContext context) {
    final best = session.previousBest;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withValues(alpha: 0.35),
            AppColors.primary.withValues(alpha: 0.18),
          ],
        ),
        border: Border.all(
          color: session.isNewBest ? AppColors.xp : AppColors.border,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          const Text(
            'SCORE',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w900),
            child: _CountUp(to: session.score!),
          ),
          if (session.opponent != null)
            Text(
              'vs ${session.opponent}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          const SizedBox(height: 6),
          if (session.isNewBest)
            const Text(
              '🚀 NEW PERSONAL BEST',
              style: TextStyle(
                color: AppColors.xp,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            )
          else if (best != null)
            Text(
              'Best: $best',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        fontSize: 13,
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.color,
    required this.icon,
    required this.child,
  });

  final String label;
  final Color color;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _CountUp extends StatelessWidget {
  const _CountUp({
    this.from = 0,
    required this.to,
    this.prefix = '',
    this.suffix = '',
  });

  final int from;
  final int to;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: from, end: to),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text('$prefix$v$suffix'),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.title});

  final Color color;
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
