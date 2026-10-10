import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/game_button.dart';

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

class SocialButtons extends StatelessWidget {
  const SocialButtons({
    super.key,
    required this.onGoogle,
    required this.onApple,
  });

  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  @override
  Widget build(BuildContext context) {
    final showApple =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return Column(
      children: [
        GameButton.secondary(
          label: 'Continue with Google',
          icon: const Text(
            'G',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          onPressed: onGoogle,
        ),
        if (showApple) ...[
          const SizedBox(height: 12),
          GameButton.secondary(
            label: 'Continue with Apple',
            icon: const Icon(Icons.apple, color: AppColors.textPrimary),
            onPressed: onApple,
          ),
        ],
      ],
    );
  }
}
