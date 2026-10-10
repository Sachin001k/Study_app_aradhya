import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/stat_chip.dart';
import '../game/game_state.dart';
import '../game/launch.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gameState,
      builder: (context, _) {
        final tier = tierFor(gameState.rating);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Hi, ${gameState.displayName} 👋',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatChip(
                    icon: Icons.local_fire_department_rounded,
                    label: '${gameState.streak} day streak',
                    color: AppColors.streak,
                  ),
                  StatChip(
                    icon: Icons.bolt_rounded,
                    label: '${gameState.xp} XP',
                    color: AppColors.xp,
                  ),
                  StatChip(
                    icon: Icons.shield_rounded,
                    label: '${tier.name} · ${gameState.rating}',
                    color: Color(tier.color),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _LevelBar(),
              ..._focusInterventions(context),
              const SizedBox(height: 20),
              const _MissionCard(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.flash_on_rounded,
                      color: AppColors.secondary,
                      title: 'Quick blitz',
                      subtitle: '5 random questions',
                      onTap: () => launchQuickBlitz(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      icon: Icons.school_rounded,
                      color: AppColors.primary,
                      title: 'Learn next',
                      subtitle: gameState.frontier?.name ?? 'All unlocked!',
                      onTap: gameState.frontier == null
                          ? null
                          : () => launchLesson(context, gameState.frontier!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Focus Intervention System: nudges based on study behaviour.
  List<Widget> _focusInterventions(BuildContext context) {
    final widgets = <Widget>[];
    final boss = gameState.bossConcept;
    if (boss != null) {
      widgets.add(
        _Nudge(
          color: AppColors.misconception,
          emoji: '👹',
          title: 'Boss fight unlocked: ${boss.name}',
          body: 'You’ve postponed this 3 times. Beat it now for 2× XP.',
          action: 'Fight',
          onTap: () => launchTask(
            context,
            MissionTask(
              type: TaskType.boss,
              title: 'Boss fight: ${boss.name}',
              subtitle: '',
              conceptIds: [boss.id],
              minutes: 5,
            ),
          ),
        ),
      );
    }
    final weakest = gameState.weakestConcept;
    if (gameState.inComfortZone && weakest != null) {
      widgets.add(
        _Nudge(
          color: AppColors.weak,
          emoji: '🧗',
          title: 'You’re playing it safe',
          body:
              'Your last sessions were all on mastered topics. '
              'Real gains are in ${weakest.name}.',
          action: 'Go',
          onTap: () => launchPractice(context, weakest),
        ),
      );
    }
    return [
      for (final w in widgets) ...[const SizedBox(height: 12), w],
    ];
  }
}

class _LevelBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lvl = gameState.level;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$lvl',
              style: const TextStyle(
                color: AppColors.textOnPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level $lvl',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: gameState.levelProgress),
                    duration: const Duration(milliseconds: 600),
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 10,
                      color: AppColors.primary,
                      backgroundColor: AppColors.surfaceHigh,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${xpForLevel(lvl + 1) - gameState.xp} XP\nto next',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard();

  @override
  Widget build(BuildContext context) {
    final mission = gameState.mission;
    final done = mission.where((t) => t.done).length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: gameState.missionDone ? AppColors.xp : AppColors.border,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TODAY’S ${gameState.missionMinutes}-MINUTE MISSION',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Text(
                '$done/${mission.length}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: mission.isEmpty ? 0 : done / mission.length,
              minHeight: 8,
              color: AppColors.xp,
              backgroundColor: AppColors.surfaceHigh,
            ),
          ),
          const SizedBox(height: 8),
          for (final t in mission) _TaskTile(task: t),
          if (gameState.missionDone) ...[
            const SizedBox(height: 8),
            const Text(
              '🎉 Mission complete! Tomorrow’s plan has been rebuilt from today’s results.',
              style: TextStyle(
                color: AppColors.xp,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            GameButton.secondary(
              label: 'Play bonus mission',
              onPressed: gameState.startNextMission,
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final MissionTask task;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (task.type) {
      TaskType.placement => (Icons.flag_rounded, AppColors.primary),
      TaskType.repair => (Icons.build_rounded, AppColors.misconception),
      TaskType.review => (Icons.history_rounded, AppColors.weak),
      TaskType.learn => (Icons.school_rounded, AppColors.primary),
      TaskType.exam => (Icons.quiz_rounded, AppColors.secondary),
      TaskType.explain => (Icons.mic_rounded, AppColors.mastered),
      TaskType.boss => (Icons.whatshot_rounded, AppColors.streak),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: AppColors.surfaceHigh.withValues(alpha: task.done ? 0.3 : 0.7),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: task.done ? null : () => launchTask(context, task),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    task.done ? Icons.check_rounded : icon,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration: task.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      Text(
                        '${task.subtitle} · ${task.minutes} min',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!task.done && task.type != TaskType.placement)
                  IconButton(
                    tooltip: 'Do later',
                    icon: const Icon(
                      Icons.snooze_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      gameState.postpone(task);
                      final n =
                          gameState.postponeCounts[task.conceptIds.first] ?? 0;
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(
                              n >= 3
                                  ? 'Postponed $n times — a boss fight has appeared!'
                                  : 'Moved to the end. Postponed $n× so far.',
                            ),
                          ),
                        );
                    },
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Nudge extends StatelessWidget {
  const _Nudge({
    required this.color,
    required this.emoji,
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
  });

  final Color color;
  final String emoji;
  final String title;
  final String body;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                Text(body, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(
              action,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
