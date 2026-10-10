/// Contract for authentication. The UI only talks to this interface, so the
/// mock below can be swapped for a `SupabaseAuthRepository` without touching
/// any screen.
abstract class AuthRepository {
  Future<AppUser> signInWithEmail(String email, String password);
  Future<AppUser> signUpWithEmail({
    required String name,
    required String username,
    required String email,
    required String password,
  });
  Future<AppUser> signInWithGoogle();
  Future<AppUser> signInWithApple();
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.xp = 0,
    this.streak = 0,
    this.rating = 1000,
    this.isNew = false,
  });

  final String id;
  final String email;
  final String displayName;
  final int xp;
  final int streak;
  final int rating;

  /// True right after sign-up, so the app routes to onboarding.
  final bool isNew;
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// In-memory implementation for building the UI before Supabase is wired up.
class MockAuthRepository implements AuthRepository {
  static const _delay = Duration(milliseconds: 900);

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    await Future.delayed(_delay);
    if (password == 'wrong') {
      throw const AuthException('Incorrect email or password.');
    }
    return AppUser(
      id: 'mock-user',
      email: email,
      displayName: email.split('@').first,
      xp: 1240,
      streak: 6,
      rating: 1185,
    );
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    await Future.delayed(_delay);
    return AppUser(
      id: 'mock-new',
      email: email,
      displayName: name,
      isNew: true,
    );
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    await Future.delayed(_delay);
    return const AppUser(
      id: 'mock-google',
      email: 'student@gmail.com',
      displayName: 'Student',
    );
  }

  @override
  Future<AppUser> signInWithApple() async {
    await Future.delayed(_delay);
    return const AppUser(
      id: 'mock-apple',
      email: 'student@icloud.com',
      displayName: 'Student',
    );
  }

  @override
  Future<void> sendPasswordReset(String email) => Future.delayed(_delay);

  @override
  Future<void> signOut() async {}
}

/// Single shared instance until a DI solution (Riverpod) is added.
final AuthRepository authRepository = MockAuthRepository();
