import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/auth/services/firebase_auth_service.dart';
import '../../features/auth/services/mock_auth_service.dart';
import '../../features/systems/services/firebase_systems_repository.dart';
import '../../features/systems/services/mock_systems_repository.dart';
import '../../features/systems/services/systems_repository.dart';
import '../../features/violations/services/firebase_violations_repository.dart';
import '../../features/violations/services/mock_violations_repository.dart';
import '../../features/violations/services/violations_repository.dart';
import '../../firebase_options.dart';

/// Centralized service handling Firebase initialization and repository resolution.
/// Ensures the application boots gracefully whether Firebase is configured or in mock mode.
abstract final class FirebaseService {
  static bool _isInitialized = false;

  /// Whether Firebase has been successfully initialized in the current runtime.
  static bool get isInitialized => _isInitialized;

  /// Attempts to initialize Firebase using platform configuration.
  /// Catches and logs any configuration absence to prevent boot crashes.
  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _isInitialized = true;
        return;
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isInitialized = true;
      debugPrint('[FirebaseService] Firebase successfully initialized.');
    } catch (e) {
      _isInitialized = false;
      debugPrint(
        '[FirebaseService] Firebase not initialized. Falling back to local mock repositories. Details: $e',
      );
    }
  }

  /// Resolves the active [AuthService] based on Firebase availability.
  static AuthService resolveAuthService({AuthService? custom}) {
    if (custom != null) return custom;
    if (_isInitialized) return FirebaseAuthService();
    return MockAuthService();
  }

  /// Resolves the active [SystemsRepository] based on Firebase availability.
  static SystemsRepository resolveSystemsRepository({
    SystemsRepository? custom,
    String? ownerUid,
  }) {
    if (custom != null) return custom;
    if (_isInitialized) {
      return FirebaseSystemsRepository(ownerUid: ownerUid);
    }
    return MockSystemsRepository();
  }

  /// Resolves the active [ViolationsRepository] based on Firebase availability.
  static ViolationsRepository resolveViolationsRepository({
    ViolationsRepository? custom,
  }) {
    if (custom != null) return custom;
    if (_isInitialized) return FirebaseViolationsRepository();
    return MockViolationsRepository();
  }
}
