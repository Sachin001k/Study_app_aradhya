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
  final warning = user == null ? null : await beginSession(user);
  runApp(EkagnaApp(user: user, startupWarning: warning));
}

class EkagnaApp extends StatelessWidget {
  const EkagnaApp({super.key, this.user, this.startupWarning});

  /// Restored from a previous session, if any.
  final AppUser? user;

  /// Shown once after launch when saved progress couldn't be loaded.
  final String? startupWarning;

  static final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final warning = startupWarning;
    if (warning != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _messenger.currentState?.showSnackBar(
          SnackBar(
            content: Text(warning),
            duration: const Duration(seconds: 6),
          ),
        ),
      );
    }
    return MaterialApp(
      title: 'Ekagna',
      scaffoldMessengerKey: _messenger,
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
