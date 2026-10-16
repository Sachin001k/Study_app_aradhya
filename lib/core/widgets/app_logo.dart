import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Glowing bolt badge + EKAGNA wordmark.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.3),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.secondary],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.5),
                blurRadius: size * 0.5,
              ),
            ],
          ),
          child: Icon(
            Icons.bolt_rounded,
            size: size * 0.7,
            color: AppColors.textOnPrimary,
          ),
        ),
        SizedBox(width: size * 0.25),
        Text(
          'EKAGNA',
          style: TextStyle(
            fontSize: size * 0.48,
            fontWeight: FontWeight.w900,
            letterSpacing: size * 0.08,
            color: AppColors.textPrimary,
            shadows: const [Shadow(color: AppColors.secondary, blurRadius: 18)],
          ),
        ),
      ],
    );
  }
}
