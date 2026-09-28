/// Custom exception representing user-facing authentication errors.
class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException(this.message, {this.code});

  @override
  String toString() => message;
}

/// User credentials model representing authentication payload.
final class AuthCredentials {
  final String email;
  final String password;

  const AuthCredentials({
    required this.email,
    required this.password,
  });
}

/// Abstract contract for authentication service.
/// Decouples the UI from Firebase Authentication.
abstract class AuthService {
  /// Current authenticated user ID, or null if not signed in.
  String? get currentUserId;

  /// Current authenticated user email, or null if not signed in.
  String? get currentUserEmail;

  /// Whether a user is currently authenticated.
  bool get isSignedIn;

  /// Stream of authentication state changes.
  Stream<String?> get authStateChanges;

  /// Sign in with email and password.
  Future<void> signInWithEmailAndPassword(AuthCredentials credentials);

  /// Sign out the current user session.
  Future<void> signOut();

  /// Send a password reset email.
  Future<void> sendPasswordResetEmail(String email);
}

