import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/constants/app_strings.dart';
import 'core/firebase/firebase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'features/shell/main_shell.dart';
import 'features/systems/services/systems_repository.dart';
import 'features/violations/services/violations_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase cleanly; falls back to mock mode if not yet configured
  await FirebaseService.initialize();

  // Set system navigation and status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const VigiDriveApp());
}

/// Root widget for the VigiDrive application.
class VigiDriveApp extends StatelessWidget {
  final AuthService? authService;
  final SystemsRepository? systemsRepository;
  final ViolationsRepository? violationsRepository;

  const VigiDriveApp({
    super.key,
    this.authService,
    this.systemsRepository,
    this.violationsRepository,
  });

  @override
  Widget build(BuildContext context) {
    final activeAuth = FirebaseService.resolveAuthService(custom: authService);
    final activeSystems = FirebaseService.resolveSystemsRepository(
      custom: systemsRepository,
    );
    final activeViolations = FirebaseService.resolveViolationsRepository(
      custom: violationsRepository,
    );

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: activeAuth.isSignedIn
          ? MainShell(
              authService: activeAuth,
              systemsRepository: activeSystems,
              violationsRepository: activeViolations,
            )
          : LoginScreen(
              authService: activeAuth,
              systemsRepository: activeSystems,
              violationsRepository: activeViolations,
            ),
    );
  }
}
