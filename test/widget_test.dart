import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigidrive/core/constants/app_strings.dart';
import 'package:vigidrive/core/theme/app_theme.dart';
import 'package:vigidrive/features/auth/models/user_model.dart';
import 'package:vigidrive/features/auth/presentation/login_screen.dart';
import 'package:vigidrive/features/auth/services/auth_service.dart';
import 'package:vigidrive/features/auth/services/mock_auth_service.dart';
import 'package:vigidrive/features/home/presentation/home_screen.dart';
import 'package:vigidrive/features/notifications/presentation/notifications_screen.dart';
import 'package:vigidrive/features/recordings/presentation/recordings_screen.dart';
import 'package:vigidrive/features/settings/presentation/settings_screen.dart';
import 'package:vigidrive/features/shell/main_shell.dart';
import 'package:vigidrive/features/systems/models/system_model.dart';
import 'package:vigidrive/features/systems/presentation/active_systems_screen.dart';
import 'package:vigidrive/features/systems/presentation/system_details_screen.dart';
import 'package:vigidrive/features/systems/services/mock_systems_repository.dart';
import 'package:vigidrive/features/violations/models/violation_model.dart';
import 'package:vigidrive/features/violations/presentation/all_violations_screen.dart';
import 'package:vigidrive/features/violations/presentation/violation_details_screen.dart';
import 'package:vigidrive/features/violations/services/mock_violations_repository.dart';
import 'package:vigidrive/main.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget buildApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: child,
  );
}

/// Pumps [ActiveSystemsScreen] with optional custom systems, then settles.
Future<void> pumpActiveSystemsScreen(
  WidgetTester tester, {
  List<SystemModel>? systems,
  AuthService? authService,
}) async {
  final repo = MockSystemsRepository(initialSystems: systems);
  await tester.pumpWidget(
    buildApp(
      ActiveSystemsScreen(
        repository: repo,
        authService: authService ?? MockAuthService(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Default LakshaysPC model (matches mock data).
const _lakshaysPC = SystemModel(
  id: 'sys_lakshays_pc',
  name: 'LakshaysPC',
  isConnected: true,
  hasUnresolvedViolations: true,
  driverName: 'Lakshay',
  driverPhone: '+919876543210',
  ownerUid: 'owner_123',
);

/// Pumps [SystemDetailsScreen] for LakshaysPC with the default mock violations.
Future<void> pumpSystemDetails(WidgetTester tester) async {
  await tester.pumpWidget(
    buildApp(
      SystemDetailsScreen(
        system: _lakshaysPC,
        violationsRepository: MockViolationsRepository(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Authentication & Login Screen ──────────────────────────────────────

  group('Authentication & Login screen', () {
    testWidgets('LoginScreen validates empty email and password locally',
        (tester) async {
      await tester.pumpWidget(buildApp(const LoginScreen()));

      // Tap Sign In without filling inputs
      await tester.tap(find.text(AppStrings.signInButton));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.emailRequired), findsOneWidget);
      expect(find.text(AppStrings.passwordRequired), findsOneWidget);
      expect(find.byType(ActiveSystemsScreen), findsNothing);
    });

    testWidgets('LoginScreen validates invalid email and short password',
        (tester) async {
      await tester.pumpWidget(buildApp(const LoginScreen()));

      await tester.enterText(find.byType(TextFormField).first, 'invalid-email');
      await tester.enterText(find.byType(TextFormField).last, '123');

      await tester.tap(find.text(AppStrings.signInButton));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.emailInvalid), findsOneWidget);
      expect(find.text(AppStrings.passwordMinLength), findsOneWidget);
      expect(find.byType(ActiveSystemsScreen), findsNothing);
    });

    testWidgets('successful login navigates to Active Systems screen',
        (tester) async {
      final mockAuth = MockAuthService();
      await tester.pumpWidget(
        buildApp(LoginScreen(authService: mockAuth)),
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'driver@organization.com',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'securePassword123',
      );

      await tester.tap(find.text(AppStrings.signInButton));
      await tester.pumpAndSettle();

      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(mockAuth.isSignedIn, isTrue);
      expect(mockAuth.currentUserEmail, 'driver@organization.com');
    });

    testWidgets('failed login stays on Login screen and shows error snackbar',
        (tester) async {
      final mockAuth = MockAuthService(
        shouldFailSignIn: true,
        signInErrorMessage: 'Invalid email address or password.',
      );
      await tester.pumpWidget(
        buildApp(LoginScreen(authService: mockAuth)),
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'wrong@organization.com',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'wrongPassword',
      );

      await tester.tap(find.text(AppStrings.signInButton));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ActiveSystemsScreen), findsNothing);
      expect(
        find.text('Invalid email address or password.'),
        findsOneWidget,
      );
    });

    testWidgets('password visibility toggle reveals and obscures text',
        (tester) async {
      await tester.pumpWidget(buildApp(const LoginScreen()));

      expect(find.byTooltip('Show password'), findsOneWidget);

      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Hide password'), findsOneWidget);
    });

    testWidgets('forgot password with empty email shows prompt dialog',
        (tester) async {
      await tester.pumpWidget(buildApp(const LoginScreen()));

      await tester.tap(find.text(AppStrings.forgotPassword));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Please provide your registered email address to receive password reset instructions.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Please provide your registered email address'), findsNothing);
    });

    testWidgets('forgot password with entered email sends reset email',
        (tester) async {
      final mockAuth = MockAuthService();
      await tester.pumpWidget(
        buildApp(LoginScreen(authService: mockAuth)),
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'operator@company.com',
      );

      await tester.tap(find.text(AppStrings.forgotPassword));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Password reset instructions have been sent to operator@company.com.',
        ),
        findsOneWidget,
      );
      expect(mockAuth.lastResetEmailSent, 'operator@company.com');

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('forgot password failure shows error snackbar',
        (tester) async {
      final mockAuth = MockAuthService(
        shouldFailReset: true,
        resetErrorMessage: 'Network error. Please check your internet connection.',
      );
      await tester.pumpWidget(
        buildApp(LoginScreen(authService: mockAuth)),
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'operator@company.com',
      );

      await tester.tap(find.text(AppStrings.forgotPassword));
      await tester.pumpAndSettle();

      expect(
        find.text('Network error. Please check your internet connection.'),
        findsOneWidget,
      );
    });
  });

  // ── Auth State on App Startup ──────────────────────────────────────────

  group('Auth state on app startup', () {
    testWidgets('opens MainShell when user is already authenticated',
        (tester) async {
      final authenticatedAuth = MockAuthService(
        initialUserId: 'user_active_999',
        initialUserEmail: 'logged_in@vigidrive.com',
      );

      await tester.pumpWidget(
        VigiDriveApp(authService: authenticatedAuth),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('opens LoginScreen when no user is authenticated',
        (tester) async {
      final unauthenticatedAuth = MockAuthService();

      await tester.pumpWidget(
        VigiDriveApp(authService: unauthenticatedAuth),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
    });
  });

  // ── Active Systems Screen ──────────────────────────────────────────────

  group('Active Systems screen', () {
    testWidgets('displays LakshaysPC in the list', (tester) async {
      await pumpActiveSystemsScreen(tester);
      expect(find.text('LakshaysPC'), findsOneWidget);
    });

    testWidgets('displays all three systems', (tester) async {
      await pumpActiveSystemsScreen(tester);
      expect(find.text('LakshaysPC'), findsOneWidget);
      expect(find.text('Vehicle-PC-02'), findsOneWidget);
      expect(find.text('Vehicle-PC-03'), findsOneWidget);
    });

    testWidgets('LakshaysPC tile shows the violation indicator',
        (tester) async {
      await pumpActiveSystemsScreen(tester);
      expect(
        find.byKey(const Key('violation_indicator_sys_lakshays_pc')),
        findsOneWidget,
      );
    });

    testWidgets('other system tiles do NOT show a violation indicator',
        (tester) async {
      await pumpActiveSystemsScreen(tester);
      expect(
        find.byKey(const Key('violation_indicator_sys_vehicle_pc_02')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('violation_indicator_sys_vehicle_pc_03')),
        findsNothing,
      );
    });

    testWidgets('tapping a system tile opens System Details screen',
        (tester) async {
      await pumpActiveSystemsScreen(tester);
      await tester.tap(find.text('LakshaysPC'));
      await tester.pumpAndSettle();
      expect(find.byType(SystemDetailsScreen), findsOneWidget);
    });

    testWidgets(
        'back navigation from System Details returns to Active Systems',
        (tester) async {
      await pumpActiveSystemsScreen(tester);
      await tester.tap(find.text('LakshaysPC'));
      await tester.pumpAndSettle();
      expect(find.byType(SystemDetailsScreen), findsOneWidget);

      final NavigatorState navigator =
          tester.state(find.byType(Navigator).last);
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(ActiveSystemsScreen), findsOneWidget);
      expect(find.byType(SystemDetailsScreen), findsNothing);
    });

    testWidgets('settings tab in MainShell opens SettingsScreen', (tester) async {
      final repo = MockSystemsRepository();
      final auth = MockAuthService();
      await tester.pumpWidget(
        buildApp(
          MainShell(
            authService: auth,
            systemsRepository: repo,
            violationsRepository: MockViolationsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Settings tab (index 3) via its key.
      await tester.tap(find.byKey(const Key('nav_tab_settings')));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  // ── Settings Screen & Sign Out ─────────────────────────────────────────

  group('Settings screen & Sign Out', () {
    Future<void> pumpSettingsScreen(
      WidgetTester tester, {
      AuthService? authService,
    }) async {
      await tester.pumpWidget(
        buildApp(SettingsScreen(authService: authService)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('displays expected sections and account info', (tester) async {
      final auth = MockAuthService(
        initialUserId: 'user_1',
        initialUserEmail: 'driver@organization.com',
      );
      await pumpSettingsScreen(tester, authService: auth);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Account Information'), findsOneWidget);
      expect(find.text('driver@organization.com'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.text('Application'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(
        find.text('Unavailable until backend service connection'),
        findsOneWidget,
      );
      expect(find.text('About VigiDrive'), findsOneWidget);
    });

    testWidgets('tapping About VigiDrive displays about dialog and closes',
        (tester) async {
      await pumpSettingsScreen(tester);
      await tester.tap(find.byKey(const Key('about_vigidrive_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Driver Safety Monitoring'), findsOneWidget);
      expect(find.text('Version 1.0.0+1'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Driver Safety Monitoring'), findsNothing);
    });

    testWidgets('tapping Sign Out clears auth session and returns to LoginScreen',
        (tester) async {
      final auth = MockAuthService(
        initialUserId: 'user_123',
        initialUserEmail: 'driver@organization.com',
      );
      expect(auth.isSignedIn, isTrue);

      await pumpSettingsScreen(tester, authService: auth);
      await tester.tap(find.byKey(const Key('sign_out_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);
      expect(auth.isSignedIn, isFalse);
    });
  });

  // ── System Details ─────────────────────────────────────────────────────

  group('System Details screen', () {
    testWidgets('displays the system name', (tester) async {
      await pumpSystemDetails(tester);
      expect(find.text('LakshaysPC'), findsOneWidget);
    });

    testWidgets('displays system status ACTIVE', (tester) async {
      await pumpSystemDetails(tester);
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('displays assigned driver name', (tester) async {
      await pumpSystemDetails(tester);
      expect(find.text('Lakshay'), findsOneWidget);
    });

    testWidgets('Contact Driver action exists', (tester) async {
      await pumpSystemDetails(tester);
      expect(find.text('Contact Driver'), findsOneWidget);
    });

    testWidgets('displays recent violations', (tester) async {
      await pumpSystemDetails(tester);
      expect(find.text('19:31:42'), findsOneWidget);
      expect(find.text('18:54:17'), findsOneWidget);
      expect(find.text('17:22:03'), findsOneWidget);
    });

    testWidgets('View All Violations opens AllViolationsScreen',
        (tester) async {
      await pumpSystemDetails(tester);
      await tester.ensureVisible(find.text('View All Violations'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View All Violations'));
      await tester.pumpAndSettle();
      expect(find.byType(AllViolationsScreen), findsOneWidget);
    });
  });

  // ── All Violations screen ──────────────────────────────────────────────

  group('All Violations screen', () {
    Future<void> pumpAllViolations(WidgetTester tester) async {
      await tester.pumpWidget(
        buildApp(
          AllViolationsScreen(
            systemId: 'sys_lakshays_pc',
            systemName: 'LakshaysPC',
            violationsRepository: MockViolationsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('displays multiple violations', (tester) async {
      await pumpAllViolations(tester);
      expect(find.text('19:31:42'), findsOneWidget);
      expect(find.text('18:54:17'), findsOneWidget);
      expect(find.text('17:22:03'), findsOneWidget);
    });

    testWidgets('tapping View opens ViolationDetailsScreen', (tester) async {
      await pumpAllViolations(tester);
      // Tap the first View button
      await tester.tap(find.text('View').first);
      await tester.pumpAndSettle();
      expect(find.byType(ViolationDetailsScreen), findsOneWidget);
    });
  });

  // ── Violation Details screen ───────────────────────────────────────────

  group('Violation Details screen', () {
    Future<void> pumpViolationDetails(WidgetTester tester) async {
      final violation = ViolationModel(
        id: 'vio_001',
        systemId: 'sys_lakshays_pc',
        timestamp: DateTime(2026, 9, 21, 19, 31, 42),
        type: 'Drowsiness detected',
        durationSeconds: 4.2,
        confidence: 0.92,
        driverName: 'Lakshay',
      );
      await tester.pumpWidget(
        buildApp(
          ViolationDetailsScreen(
            violation: violation,
            systemName: 'LakshaysPC',
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('displays timestamp, duration, confidence and system',
        (tester) async {
      await pumpViolationDetails(tester);
      expect(find.text('19:31:42'), findsOneWidget);
      expect(find.text('04.2 seconds'), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('LakshaysPC'), findsOneWidget);
    });

    testWidgets('displays driver name and detection result', (tester) async {
      await pumpViolationDetails(tester);
      expect(find.text('Lakshay'), findsOneWidget);
      expect(find.text('Sleepy'), findsOneWidget);
    });

    testWidgets('displays recording placeholder', (tester) async {
      await pumpViolationDetails(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('recording_placeholder')),
        200.0,
      );
      expect(find.byKey(const Key('recording_placeholder')), findsOneWidget);
    });

    testWidgets('back navigation returns to previous screen', (tester) async {
      await tester.pumpWidget(
        buildApp(
          AllViolationsScreen(
            systemId: 'sys_lakshays_pc',
            systemName: 'LakshaysPC',
            violationsRepository: MockViolationsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View').first);
      await tester.pumpAndSettle();
      expect(find.byType(ViolationDetailsScreen), findsOneWidget);

      final NavigatorState navigator =
          tester.state(find.byType(Navigator).last);
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(AllViolationsScreen), findsOneWidget);
      expect(find.byType(ViolationDetailsScreen), findsNothing);
    });
  });

  // ── Firestore Data Models & Mappings ───────────────────────────────────

  group('Firestore Data Models & Mappings Unit Tests', () {
    test('UserModel converts to and from Firestore map payload', () {
      final user = UserModel(
        uid: 'user_test_123',
        email: 'test@vigidrive.com',
        displayName: 'Test Driver',
        createdAt: DateTime(2026, 9, 21, 10, 0, 0),
      );

      final map = user.toFirestore();
      expect(map['email'], 'test@vigidrive.com');
      expect(map['displayName'], 'Test Driver');
      expect(map['createdAt'], isNotNull);
    });

    test('SystemModel converts to and from Firestore map payload with ownerUid and isOnline', () {
      const system = SystemModel(
        id: 'sys_001',
        name: 'Vehicle-01',
        isConnected: true,
        hasUnresolvedViolations: true,
        driverName: 'Lakshay',
        driverPhone: '+919876543210',
        ownerUid: 'uid_test_123',
      );

      final map = system.toFirestore();
      expect(map['name'], 'Vehicle-01');
      expect(map['isOnline'], true);
      expect(map['isConnected'], true);
      expect(map['connectionStatus'], 'ACTIVE');
      expect(map['hasUnresolvedViolations'], true);
      expect(map['driverName'], 'Lakshay');
      expect(map['driverPhone'], '+919876543210');
      expect(map['ownerUid'], 'uid_test_123');

      // Test deserialization from map
      final parsed = SystemModel.fromMap(map, id: 'sys_001');
      expect(parsed.id, 'sys_001');
      expect(parsed.name, 'Vehicle-01');
      expect(parsed.isConnected, true);
      expect(parsed.hasUnresolvedViolations, true);
      expect(parsed.driverName, 'Lakshay');
      expect(parsed.driverPhone, '+919876543210');
      expect(parsed.ownerUid, 'uid_test_123');
    });

    test('SystemModel handles missing optional fields safely', () {
      final minimalMap = <String, dynamic>{
        'name': 'MinimalSystem',
      };
      final parsed = SystemModel.fromMap(minimalMap, id: 'sys_min');
      expect(parsed.id, 'sys_min');
      expect(parsed.name, 'MinimalSystem');
      expect(parsed.isConnected, true);
      expect(parsed.hasUnresolvedViolations, false);
      expect(parsed.driverName, isNull);
      expect(parsed.driverPhone, isNull);
      expect(parsed.ownerUid, isNull);
    });

    test('ViolationModel converts to and from Firestore map with all conversions', () {
      final sampleDate = DateTime(2026, 9, 21, 12, 30, 0);
      final violation = ViolationModel(
        id: 'vio_test',
        systemId: 'sys_001',
        timestamp: sampleDate,
        type: 'drowsiness',
        durationSeconds: 4.5,
        confidence: 0.94,
        driverName: 'Lakshay',
        recordingPath: null,
        resolved: false,
      );

      final map = violation.toFirestore();
      expect(map['systemId'], 'sys_001');
      expect(map['type'], 'drowsiness');
      expect(map['durationSeconds'], 4.5);
      expect(map['confidence'], 0.94);
      expect(map['driverName'], 'Lakshay');
      expect(map['recordingPath'], isNull);
      expect(map['resolved'], false);

      // Parse back from map
      final parsed = ViolationModel.fromMap(map, id: 'vio_test');
      expect(parsed.id, 'vio_test');
      expect(parsed.systemId, 'sys_001');
      expect(parsed.timestamp, sampleDate);
      expect(parsed.type, 'drowsiness');
      expect(parsed.durationSeconds, 4.5);
      expect(parsed.confidence, 0.94);
      expect(parsed.driverName, 'Lakshay');
      expect(parsed.recordingPath, isNull);
      expect(parsed.resolved, false);
    });

    test('ViolationModel handles numeric and timestamp formats (Timestamp, int, ISO string, num)', () {
      // 1. Millisecond timestamp + integer duration & confidence
      final mapWithInts = <String, dynamic>{
        'systemId': 'sys_99',
        'timestamp': 1774358400000,
        'type': 'distraction',
        'durationSeconds': 5,
        'confidence': 1,
        'driverName': 'Arjun',
        'recordingPath': 'C:/VigiDrive/recordings/rec.mp4',
      };
      final parsedInts = ViolationModel.fromMap(mapWithInts, id: 'vio_int');
      expect(parsedInts.durationSeconds, 5.0);
      expect(parsedInts.confidence, 1.0);
      expect(parsedInts.type, 'distraction');
      expect(parsedInts.recordingPath, 'C:/VigiDrive/recordings/rec.mp4');

      // 2. ISO String timestamp
      final mapWithStringDate = <String, dynamic>{
        'timestamp': '2026-09-21T18:00:00.000Z',
        'type': 'phone_use',
      };
      final parsedIso = ViolationModel.fromMap(mapWithStringDate, id: 'vio_iso');
      expect(parsedIso.type, 'phone_use');
      expect(parsedIso.durationSeconds, 0.0);
      expect(parsedIso.confidence, isNull);
      expect(parsedIso.driverName, '');
      expect(parsedIso.recordingPath, isNull);
    });

    test('MockAuthService sign in and sign out lifecycle', () async {
      final auth = MockAuthService();
      expect(auth.isSignedIn, isFalse);

      await auth.signInWithEmailAndPassword(
        const AuthCredentials(email: 'test@driver.com', password: 'password123'),
      );
      expect(auth.isSignedIn, isTrue);
      expect(auth.currentUserEmail, 'test@driver.com');
      expect(auth.currentUserId, 'mock_user_123');

      await auth.signOut();
      expect(auth.isSignedIn, isFalse);
      expect(auth.currentUserId, isNull);
    });

    test('MockAuthService failed sign-in throws AuthException', () async {
      final auth = MockAuthService(
        shouldFailSignIn: true,
        signInErrorMessage: 'Invalid email address or password.',
      );

      expect(
        () => auth.signInWithEmailAndPassword(
          const AuthCredentials(email: 'bad@driver.com', password: 'wrong'),
        ),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Invalid email address or password.',
        )),
      );
    });

    test('MockAuthService password reset success and failure', () async {
      final auth = MockAuthService();
      await auth.sendPasswordResetEmail('driver@company.com');
      expect(auth.lastResetEmailSent, 'driver@company.com');

      auth.shouldFailReset = true;
      auth.resetErrorMessage = 'Network error.';
      expect(
        () => auth.sendPasswordResetEmail('driver@company.com'),
        throwsA(isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Network error.',
        )),
      );
    });

    test('MockSystemsRepository watch streams emit system data', () async {
      final repo = MockSystemsRepository();
      final systems = await repo.watchActiveSystems().first;
      expect(systems.length, 3);
      expect(systems.first.name, 'LakshaysPC');

      final system = await repo.watchSystemById('sys_lakshays_pc').first;
      expect(system, isNotNull);
      expect(system?.name, 'LakshaysPC');
    });

    test('MockViolationsRepository watch streams emit violation data', () async {
      final repo = MockViolationsRepository();
      final violations = await repo.watchViolationsForSystem('sys_lakshays_pc').first;
      expect(violations.length, 3);

      final recent = await repo.watchRecentViolations('sys_lakshays_pc', limit: 2).first;
      expect(recent.length, 2);
    });
  });

  // ── MainShell & Floating Navigation ────────────────────────────────────

  group('MainShell & Floating Navigation', () {
    testWidgets('floating navigation bar switches between all 4 destinations',
        (tester) async {
      final auth = MockAuthService(
        initialUserId: 'user_nav_1',
        initialUserEmail: 'lakshay@vigidrive.com',
      );
      final systemsRepo = MockSystemsRepository();
      final violationsRepo = MockViolationsRepository();

      await tester.pumpWidget(
        buildApp(
          MainShell(
            authService: auth,
            systemsRepository: systemsRepo,
            violationsRepository: violationsRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial destination is Home (index 0)
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text("Here\u2019s your monitoring overview."), findsOneWidget);

      // 2. Tap Notifications tab (index 1)
      await tester.tap(find.byKey(const Key('nav_tab_notifications')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);

      // 3. Tap My Systems tab (index 2)
      await tester.tap(find.byKey(const Key('nav_tab_systems')));
      await tester.pumpAndSettle();
      expect(find.byType(ActiveSystemsScreen), findsOneWidget);
      expect(find.text(AppStrings.mySystemsTitle), findsOneWidget);

      // 4. Tap Settings tab (index 3)
      await tester.tap(find.byKey(const Key('nav_tab_settings')));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text(AppStrings.settingsTitle), findsOneWidget);

      // 5. Tap Home tab (index 0) to return
      await tester.tap(find.byKey(const Key('nav_tab_home')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  // ── Home Screen & Dashboard ────────────────────────────────────────────

  group('Home Screen & Dashboard', () {
    testWidgets('displays greeting, monitoring card, stored recordings, and activity',
        (tester) async {
      final auth = MockAuthService(
        initialUserId: 'u_1',
        initialUserEmail: 'lakshay@example.com',
      );
      final systemsRepo = MockSystemsRepository();
      final violationsRepo = MockViolationsRepository();

      await tester.pumpWidget(
        buildApp(
          HomeScreen(
            authService: auth,
            systemsRepository: systemsRepo,
            violationsRepository: violationsRepo,
            onOpenRecordings: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Lakshay'), findsOneWidget);
      expect(find.text("Here\u2019s your monitoring overview."), findsOneWidget);
      expect(find.text(AppStrings.monitoringSection), findsOneWidget);
      expect(find.text(AppStrings.storedRecordings), findsOneWidget);
      expect(find.text(AppStrings.recentActivitySection), findsOneWidget);
    });

    testWidgets('displays offline monitoring state when systems are offline',
        (tester) async {
      final auth = MockAuthService();
      const offlineSystem = SystemModel(
        id: 'sys_offline',
        name: 'LakshaysPC',
        isConnected: false,
      );
      final systemsRepo = MockSystemsRepository(initialSystems: [offlineSystem]);

      await tester.pumpWidget(
        buildApp(
          HomeScreen(
            authService: auth,
            systemsRepository: systemsRepo,
            violationsRepository: MockViolationsRepository(),
            onOpenRecordings: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.monitoringOffline), findsOneWidget);
      expect(find.text(AppStrings.monitoringOfflineSubtext), findsOneWidget);
    });

    testWidgets('tapping Stored Recordings triggers callback',
        (tester) async {
      bool opened = false;
      await tester.pumpWidget(
        buildApp(
          HomeScreen(
            authService: MockAuthService(),
            systemsRepository: MockSystemsRepository(),
            violationsRepository: MockViolationsRepository(),
            onOpenRecordings: () {
              opened = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('recordings_tile')));
      await tester.pumpAndSettle();

      expect(opened, isTrue);
    });
  });

  // ── Recordings Screen ──────────────────────────────────────────────────

  group('Recordings Screen', () {
    testWidgets('displays honest empty state when no recordings exist',
        (tester) async {
      await tester.pumpWidget(
        buildApp(
          RecordingsScreen(
            systemsRepository: MockSystemsRepository(),
            violationsRepository: MockViolationsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.recordingsTitle), findsOneWidget);
      expect(find.text(AppStrings.noRecordingsAvailable), findsWidgets);
      expect(find.text(AppStrings.recordingsSubtext), findsOneWidget);
    });
  });

  // ── Notifications Screen ───────────────────────────────────────────────

  group('Notifications Screen', () {
    testWidgets('displays empty state when no systems exist',
        (tester) async {
      final emptyRepo = MockSystemsRepository(initialSystems: const []);

      await tester.pumpWidget(
        buildApp(
          NotificationsScreen(
            systemsRepository: emptyRepo,
            violationsRepository: MockViolationsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.notificationsTitle), findsOneWidget);
      expect(find.text(AppStrings.noNewNotifications), findsOneWidget);
      expect(find.text(AppStrings.noNewNotificationsSubtext), findsOneWidget);
    });
  });

  // ── My Systems Screen (ActiveSystemsScreen) ─────────────────────────────

  group('My Systems Screen additional states', () {
    testWidgets('displays empty state when no systems are registered',
        (tester) async {
      final emptyRepo = MockSystemsRepository(initialSystems: const []);

      await tester.pumpWidget(
        buildApp(
          ActiveSystemsScreen(
            repository: emptyRepo,
            authService: MockAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.noSystemsConnected), findsOneWidget);
      expect(find.text(AppStrings.noSystemsConnectedSubtext), findsOneWidget);
    });

    testWidgets('displays Offline label when system is not connected',
        (tester) async {
      const offlineSystem = SystemModel(
        id: 'sys_offline_1',
        name: 'Desk-PC',
        isConnected: false,
      );
      final repo = MockSystemsRepository(initialSystems: [offlineSystem]);

      await tester.pumpWidget(
        buildApp(
          ActiveSystemsScreen(
            repository: repo,
            authService: MockAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Desk-PC'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('status indicator shows "Systems offline" when all systems are offline',
        (tester) async {
      const offlineSystem1 = SystemModel(
        id: 'sys_off_1',
        name: 'PC-1',
        isConnected: false,
        hasUnresolvedViolations: false,
      );
      const offlineSystem2 = SystemModel(
        id: 'sys_off_2',
        name: 'PC-2',
        isConnected: false,
        hasUnresolvedViolations: false,
      );
      final repo = MockSystemsRepository(
        initialSystems: [offlineSystem1, offlineSystem2],
      );

      await tester.pumpWidget(
        buildApp(
          ActiveSystemsScreen(
            repository: repo,
            authService: MockAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.systemsOffline), findsOneWidget);
      expect(find.text(AppStrings.systemsNormal), findsNothing);
      expect(find.text(AppStrings.violationsDetected), findsNothing);
    });

    testWidgets('status indicator shows "Systems operating normally" when system is online without violations',
        (tester) async {
      const onlineSystem = SystemModel(
        id: 'sys_on_1',
        name: 'PC-1',
        isConnected: true,
        hasUnresolvedViolations: false,
      );
      final repo = MockSystemsRepository(
        initialSystems: [onlineSystem],
      );

      await tester.pumpWidget(
        buildApp(
          ActiveSystemsScreen(
            repository: repo,
            authService: MockAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.systemsNormal), findsOneWidget);
      expect(find.text(AppStrings.systemsOffline), findsNothing);
      expect(find.text(AppStrings.violationsDetected), findsNothing);
    });

    testWidgets('status indicator shows "Violations detected" when any system has violations',
        (tester) async {
      const violationSystem = SystemModel(
        id: 'sys_vio_1',
        name: 'PC-1',
        isConnected: true,
        hasUnresolvedViolations: true,
      );
      final repo = MockSystemsRepository(
        initialSystems: [violationSystem],
      );

      await tester.pumpWidget(
        buildApp(
          ActiveSystemsScreen(
            repository: repo,
            authService: MockAuthService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.violationsDetected), findsOneWidget);
      expect(find.text(AppStrings.systemsNormal), findsNothing);
      expect(find.text(AppStrings.systemsOffline), findsNothing);
    });

    testWidgets('Home greeting displays Welcome, Lakshay and never Welcome, Driver',
        (tester) async {
      final authWithDriverEmail = MockAuthService(
        initialUserId: 'u_driver',
        initialUserEmail: 'driver@organization.com',
      );
      const lakshaysPC = SystemModel(
        id: 'sys_lakshay',
        name: 'LakshaysPC',
        isConnected: false,
        driverName: 'Lakshay',
      );
      final systemsRepo = MockSystemsRepository(initialSystems: [lakshaysPC]);

      await tester.pumpWidget(
        buildApp(
          HomeScreen(
            authService: authWithDriverEmail,
            systemsRepository: systemsRepo,
            violationsRepository: MockViolationsRepository(),
            onOpenRecordings: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Lakshay'), findsOneWidget);
      expect(find.text('Welcome, Driver'), findsNothing);
    });
  });
}
