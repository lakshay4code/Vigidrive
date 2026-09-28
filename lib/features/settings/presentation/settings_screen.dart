import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/firebase/firebase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/services/auth_service.dart';

/// Settings screen — rendered as the Settings tab body inside [MainShell].
/// Does NOT contain its own AppBar or back button.
class SettingsScreen extends StatelessWidget {
  final AuthService? authService;

  const SettingsScreen({
    super.key,
    this.authService,
  });

  Future<void> _handleSignOut(BuildContext context) async {
    final auth = authService ?? FirebaseService.resolveAuthService();
    try {
      await auth.signOut();
    } catch (_) {
      // Allow navigation back to login even if network call fails
    }

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(authService: auth),
      ),
      (route) => false,
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(
              color: AppColors.borderSubtle,
              width: 1.0,
            ),
          ),
          title: const Text(
            AppStrings.appName,
            style: AppTypography.headingMedium,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.driverSafetyMonitoring,
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.appVersion,
                style: AppTypography.bodySecondary,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppStrings.close,
                style: AppTypography.label.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeAuth = authService ?? FirebaseService.resolveAuthService();
    final displayedEmail =
        activeAuth.currentUserEmail ?? AppStrings.defaultAccountEmail;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        children: [
          // Page Title
          const Text(
            AppStrings.settingsTitle,
            style: AppTypography.headingLarge,
          ),
          const SizedBox(height: 24),
          Container(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 20),

          // ── Account Section ──────────────────────────────────────────
          const Text(
            AppStrings.accountSection,
            style: AppTypography.headingMedium,
          ),
          const SizedBox(height: 16),

          // Account Information card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.borderSubtle,
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.accountInformation,
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 6),
                Text(
                  displayedEmail,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sign Out Action
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('sign_out_button'),
              onPressed: () => _handleSignOut(context),
              icon: const Icon(
                Icons.logout,
                size: 18,
                color: AppColors.error,
              ),
              label: Text(
                AppStrings.signOut,
                style: AppTypography.label.copyWith(
                  color: AppColors.error,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),

          const SizedBox(height: 28),
          Container(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 20),

          // ── Application Section ──────────────────────────────────────
          const Text(
            AppStrings.applicationSection,
            style: AppTypography.headingMedium,
          ),
          const SizedBox(height: 16),

          // Notifications Status (clearly marked unavailable)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.borderSubtle,
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.notifications,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.notificationsUnavailable,
                  style: AppTypography.bodySecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // About VigiDrive tile
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(
                color: AppColors.borderSubtle,
                width: 1.0,
              ),
            ),
            child: InkWell(
              key: const Key('about_vigidrive_tile'),
              onTap: () => _showAboutDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.aboutApp,
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
