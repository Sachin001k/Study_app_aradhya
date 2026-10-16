import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'auth_repository.dart';

/// Real authentication backed by Supabase Auth.
class SupabaseAuthRepository implements AuthRepository {
  sb.GoTrueClient get _auth => sb.Supabase.instance.client.auth;

  /// Deep link the OAuth browser returns to on Android/iOS. Must match the
  /// intent-filter in AndroidManifest.xml and a Supabase Redirect URL.
  static const _mobileRedirect = 'com.aradhya.aradhya://login-callback';

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : _toAppUser(user);
  }

  @override
  Future<AppUser> signInWithEmail(String email, String password) =>
      _guard(() async {
        final res = await _auth.signInWithPassword(
          email: email,
          password: password,
        );
        return _toAppUser(res.user!);
      });

  @override
  Future<AppUser> signUpWithEmail({
    required String name,
    required String username,
    required String email,
    required String password,
  }) => _guard(() async {
    final res = await _auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'username': username},
    );
    if (res.session == null) {
      // "Confirm email" is switched on in the Supabase dashboard.
      throw const AuthException(
        'Account created! Check your inbox to confirm your email, then log in.',
      );
    }
    return _toAppUser(res.user!, isNew: true);
  });

  @override
  Future<AppUser> signInWithGoogle() => _oauth(sb.OAuthProvider.google);

  @override
  Future<AppUser> signInWithApple() => _oauth(sb.OAuthProvider.apple);

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.resetPasswordForEmail(email));

  @override
  Future<void> signOut() => _auth.signOut();

  /// On web this redirects away and the app reloads signed in; on mobile it
  /// returns once the auth callback fires.
  Future<AppUser> _oauth(sb.OAuthProvider provider) => _guard(() async {
    final signedIn = _auth.onAuthStateChange.firstWhere(
      (s) => s.event == sb.AuthChangeEvent.signedIn,
    );
    await _auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? Uri.base.origin : _mobileRedirect,
    );
    final state = await signedIn.timeout(const Duration(minutes: 5));
    return _toAppUser(state.session!.user);
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException {
      rethrow;
    } on sb.AuthException catch (e) {
      throw AuthException(e.message);
    } on TimeoutException {
      throw const AuthException('Sign-in timed out. Please try again.');
    } catch (_) {
      throw const AuthException(
        'Can’t reach the server. Check your connection.',
      );
    }
  }

  AppUser _toAppUser(sb.User user, {bool isNew = false}) {
    final meta = user.userMetadata ?? const {};
    final email = user.email ?? '';
    return AppUser(
      id: user.id,
      email: email,
      displayName: (meta['name'] ?? meta['full_name'] ?? email.split('@').first)
          .toString(),
      isNew: isNew,
    );
  }
}
