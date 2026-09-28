import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// Firebase Authentication implementation of [AuthService].
/// Syncs user records to Cloud Firestore `users/{uid}`.
class FirebaseAuthService implements AuthService {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  FirebaseAuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  @override
  String? get currentUserEmail => _firebaseAuth.currentUser?.email;

  @override
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  @override
  Stream<String?> get authStateChanges =>
      _firebaseAuth.authStateChanges().map((user) => user?.uid);

  @override
  Future<void> signInWithEmailAndPassword(AuthCredentials credentials) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: credentials.email.trim(),
        password: credentials.password,
      );

      final user = userCredential.user;
      if (user != null) {
        await _ensureUserDocumentExists(user);
      }
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException('Authentication failed. Please check your credentials.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException('Sign out failed. Please try again.');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(
        email: email.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw const AuthException('Failed to send password reset email. Please try again.');
    }
  }

  /// Ensures a user profile document exists under `users/{uid}`.
  Future<void> _ensureUserDocumentExists(User user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        final userModel = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          createdAt: DateTime.now(),
        );
        await docRef.set(userModel.toFirestore());
      }
    } catch (_) {
      // Document sync error should not block authentication
    }
  }

  /// Maps Firebase auth exception codes to user-friendly messages.
  AuthException _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return AuthException('Invalid email address or password.', code: e.code);
      case 'user-disabled':
        return AuthException(
          'This account has been disabled. Please contact your administrator.',
          code: e.code,
        );
      case 'too-many-requests':
        return AuthException(
          'Too many attempts. Please try again later.',
          code: e.code,
        );
      case 'invalid-email':
        return AuthException('Please enter a valid email address.', code: e.code);
      case 'network-request-failed':
        return AuthException(
          'Network error. Please check your internet connection.',
          code: e.code,
        );
      case 'unavailable':
        return AuthException(
          'Service unavailable. Please try again later.',
          code: e.code,
        );
      default:
        return AuthException(
          e.message ?? 'Authentication failed. Please try again.',
          code: e.code,
        );
    }
  }
}

