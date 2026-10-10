import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../game/game_state.dart';

/// Weekly XP league (mock opponents until the backend exists).
class LeagueScreen extends StatelessWidget {
  const LeagueScreen({super.key});

  static const _promote = 3;
  static const _demote = 3;

  static const _rivals = <(String, int)>[
    ('Ishaan', 640),
    ('Meera', 585),
    ('Kabir', 512),
    ('Ananya', 470),
    ('Vihaan', 431),
    ('Diya', 388),
    ('Arjun', 342),
    ('Saanvi', 297),
    ('Reyansh', 251),
    ('Myra', 204),
    ('Aarav', 160),
    ('Kiara', 95),
    ('Advait', 48),
    ('Zoya', 20),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gameState,
      builder: (context, _) {
        final players = [
          ..._rivals.map((r) => (name: r.$1, xp: r.$2, me: false)),
          (name: gameState.displayName, xp: gameState.weeklyXp, me: true),
        ]..sort((a, b) => b.xp.compareTo(a.xp));
        final tier = tierFor(gameState.rating);

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shield_rounded,
                    color: Color(tier.color),
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tier.name} League',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Top 3 promote · ends Sunday',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              for (var i = 0; i < players.length; i++) ...[
                if (i == _promote)
                  const _ZoneDivider('PROMOTION ZONE ↑', AppColors.mastered),
                if (i == players.length - _demote)
                  const _ZoneDivider(
                    'DEMOTION ZONE ↓',
                    AppColors.misconception,
                  ),
                _Row(
                  rank: i + 1,
                  name: players[i].name,
                  xp: players[i].xp,
                  me: players[i].me,
                  zoneColor: i < _promote
                      ? AppColors.mastered
                      : i >= players.length - _demote
                      ? AppColors.misconception
                      : null,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ZoneDivider extends StatelessWidget {
  const _ZoneDivider(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: color.withValues(alpha: 0.5))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(child: Divider(color: color.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.rank,
    required this.name,
    required this.xp,
    required this.me,
    this.zoneColor,
  });

  final int rank;
  final String name;
  final int xp;
  final bool me;
  final Color? zoneColor;

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: me
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: me ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              medal ?? '$rank',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: zoneColor ?? AppColors.textSecondary,
                fontSize: medal != null ? 20 : 15,
              ),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceHigh,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              me ? '$name (you)' : name,
              style: TextStyle(
                fontWeight: me ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$xp XP',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.xp,
            ),
          ),
        ],
      ),
    );
  }
}
