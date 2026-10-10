import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/game_button.dart';
import '../auth/data/auth_repository.dart';
import '../auth/presentation/welcome_screen.dart';
import '../game/game_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await authRepository.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gameState,
      builder: (context, _) {
        final g = gameState;
        final tier = tierFor(g.rating);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.secondary,
                  child: Text(
                    g.displayName.isEmpty
                        ? '?'
                        : g.displayName[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                g.displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                [if (g.goal != null) g.goal!, 'Level ${g.level}'].join(' · '),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Color(tier.color).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(tier.color), width: 2),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      color: Color(tier.color),
                      size: 48,
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tier.name.toUpperCase(),
                          style: TextStyle(
                            color: Color(tier.color),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          '${g.rating}',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text(
                      'Maths\nrating',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Stat('${g.xp}', 'Total XP', AppColors.xp),
                  _Stat('${g.streak}', 'Streak', AppColors.streak),
                  _Stat(
                    '${(g.accuracy * 100).round()}%',
                    'Accuracy',
                    AppColors.mastered,
                  ),
                  _Stat('${g.bestCombo}×', 'Best combo', AppColors.secondary),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'BADGES',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.8,
                children: [
                  for (final b in allBadges)
                    _BadgeTile(b, earned: g.badges.contains(b.id)),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'DAILY MISSION LENGTH',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 10, label: Text('10m')),
                  ButtonSegment(value: 20, label: Text('20m')),
                  ButtonSegment(value: 38, label: Text('38m')),
                  ButtonSegment(value: 60, label: Text('60m')),
                ],
                selected: {g.dailyMinutes},
                showSelectedIcon: false,
                onSelectionChanged: (s) => g.setDailyMinutes(s.first),
              ),
              const SizedBox(height: 28),
              GameButton.secondary(
                label: 'Sign out',
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => _signOut(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile(this.badge, {required this.earned});

  final GameBadge badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: badge.description,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: earned ? AppColors.xp : AppColors.border),
        ),
        child: Opacity(
          opacity: earned ? 1 : 0.35,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                earned ? badge.emoji : '🔒',
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(height: 6),
              Text(
                badge.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
