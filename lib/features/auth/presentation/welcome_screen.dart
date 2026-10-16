import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/game_button.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/game_background.dart';
import '../../../core/widgets/stat_chip.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: GameBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      const AppLogo(size: 44),
                      const Spacer(flex: 3),
                      const Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatChip(
                            icon: Icons.bolt_rounded,
                            label: '+120 XP',
                            color: AppColors.xp,
                          ),
                          StatChip(
                            icon: Icons.local_fire_department_rounded,
                            label: '7 day streak',
                            color: AppColors.streak,
                          ),
                          StatChip(
                            icon: Icons.trending_up_rounded,
                            label: '1240 rating',
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                              ),
                          children: const [
                            TextSpan(
                              text: 'Study 5 mins.\nBattle questions.\n',
                            ),
                            TextSpan(
                              text: 'Level up.',
                              style: TextStyle(color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your brain, mapped. Ekagna finds what you\'re '
                        'forgetting and turns fixing it into a game.',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const Spacer(),
                      GameButton(
                        label: 'Get started',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GameButton.secondary(
                        label: 'I have an account',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
