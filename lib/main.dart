import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/auth/presentation/onboarding_screen.dart';
import 'features/auth/presentation/welcome_screen.dart';
import 'features/game/game_state.dart';
import 'features/game/progress_store.dart';
import 'features/game/session.dart';
import 'features/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseKey,
    );
    authRepository = SupabaseAuthRepository();
    progressStore = SupabaseProgressStore(Supabase.instance.client);
  }
  final user = authRepository.currentUser;
  if (user != null) await beginSession(user);
  runApp(AradhyaApp(user: user));
}

class AradhyaApp extends StatelessWidget {
  const AradhyaApp({super.key, this.user});

  /// Restored from a previous session, if any.
  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aradhya',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: switch (user) {
        null => const WelcomeScreen(),
        final u when !gameState.onboarded => OnboardingScreen(user: u),
        _ => const AppShell(),
      },
    );
  }
}
