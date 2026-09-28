import 'dart:async';
import 'auth_service.dart';

/// Local mock implementation of [AuthService] for development and tests.
class MockAuthService implements AuthService {
  String? _currentUserId;
  String? _currentUserEmail;
  bool shouldFailSignIn;
  String? signInErrorMessage;
  bool shouldFailReset;
  String? resetErrorMessage;
  String? lastResetEmailSent;

  final StreamController<String?> _authStateController =
      StreamController<String?>.broadcast();

  MockAuthService({
    String? initialUserId,
    String? initialUserEmail = 'driver@organization.com',
    this.shouldFailSignIn = false,
    this.signInErrorMessage,
    this.shouldFailReset = false,
    this.resetErrorMessage,
  })  : _currentUserId = initialUserId,
        _currentUserEmail = initialUserEmail;

  @override
  String? get currentUserId => _currentUserId;

  @override
  String? get currentUserEmail => _currentUserEmail;

  @override
  bool get isSignedIn => _currentUserId != null;

  @override
  Stream<String?> get authStateChanges => _authStateController.stream;

  @override
  Future<void> signInWithEmailAndPassword(AuthCredentials credentials) async {
    if (shouldFailSignIn) {
      throw AuthException(
        signInErrorMessage ?? 'Invalid email address or password.',
      );
    }
    // Validate credentials format
    if (credentials.email.isEmpty || credentials.password.isEmpty) {
      throw const AuthException('Email and password cannot be empty.');
    }
    _currentUserId = 'mock_user_123';
    _currentUserEmail = credentials.email;
    _authStateController.add(_currentUserId);
  }

  @override
  Future<void> signOut() async {
    _currentUserId = null;
    _currentUserEmail = null;
    _authStateController.add(null);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (shouldFailReset) {
      throw AuthException(
        resetErrorMessage ?? 'Failed to send password reset email.',
      );
    }
    if (email.isEmpty) {
      throw const AuthException('Email address is required.');
    }
    lastResetEmailSent = email;
  }
}

