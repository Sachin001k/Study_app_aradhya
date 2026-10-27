import 'package:flutter/foundation.dart';

import '../auth/data/auth_repository.dart';
import 'game_state.dart';
import 'progress_store.dart';

/// Set at startup when Supabase is configured; null in offline mock mode.
SupabaseProgressStore? progressStore;

/// Prepares [gameState] for [user]. Returns a warning to show if saved
/// progress couldn't be loaded (the game then runs without saving, so it
/// never overwrites real data with blanks).
Future<String?> beginSession(AppUser user) async {
  final store = progressStore;
  gameState.signIn(user, seedDemo: store == null);
  if (store == null) return null;
  try {
    // Bounded so a slow network can't leave the app on a blank screen.
    await store.attach(gameState, user).timeout(const Duration(seconds: 15));
    return null;
  } catch (e) {
    debugPrint('Progress load failed: $e');
    return 'Couldn’t load your saved progress, so this session won’t be saved. '
        'Has supabase/schema.sql been run?';
  }
}

Future<void> endSession() async {
  await progressStore?.detach();
  try {
    await authRepository.signOut();
  } catch (e) {
    // Offline: the local session is already cleared, which is what matters.
    debugPrint('Sign-out request failed: $e');
  }
}
