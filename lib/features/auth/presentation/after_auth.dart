import 'package:flutter/material.dart';

import '../../entry/game_entry_screen.dart';
import '../../game/game_state.dart';
import '../../game/session.dart';
import '../data/auth_repository.dart';
import 'onboarding_screen.dart';
import 'widgets/auth_scaffold.dart';

/// After any successful sign-in or sign-up: load progress, then either
/// onboard a new player or play the entry transition into Home.
Future<void> continueAfterAuth(BuildContext context, AppUser user) async {
  final warning = await beginSession(user);
  if (!context.mounted) return;
  if (warning != null) showAuthError(context, warning);
  if (gameState.onboarded) {
    enterGame(context);
  } else {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => OnboardingScreen(user: user)),
      (_) => false,
    );
  }
}
