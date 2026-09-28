import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/firebase/firebase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/services/auth_service.dart';
import '../../violations/services/violations_repository.dart';
import '../models/system_model.dart';
import '../services/systems_repository.dart';
import '../widgets/system_tile.dart';
import 'system_details_screen.dart';

/// Displays all monitoring systems registered to this account.
/// Rendered as the "My Systems" tab body inside [MainShell].
/// Does NOT contain its own Scaffold or AppBar — the shell provides the
/// top-level Scaffold. A [SafeArea] ensures content avoids the status bar.
class ActiveSystemsScreen extends StatefulWidget {
  final SystemsRepository repository;
  final ViolationsRepository? violationsRepository;
  final AuthService? authService;

  const ActiveSystemsScreen({
    super.key,
    required this.repository,
    this.violationsRepository,
    this.authService,
  });

  @override
  State<ActiveSystemsScreen> createState() => _ActiveSystemsScreenState();
}

class _ActiveSystemsScreenState extends State<ActiveSystemsScreen> {
  void _openSystemDetails(BuildContext context, SystemModel system) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SystemDetailsScreen(
          system: system,
          violationsRepository: widget.violationsRepository ??
              FirebaseService.resolveViolationsRepository(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: StreamBuilder<List<SystemModel>>(
        stream: widget.repository.watchActiveSystems(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load systems. Please try again.',
                  style: AppTypography.bodySecondary,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final systems = snapshot.data ?? [];
          final hasAnyViolations =
              systems.any((s) => s.hasUnresolvedViolations);
          final hasOnlineSystem =
              systems.any((s) => s.isConnected);

          return ListView(
            padding:
                const EdgeInsets.fromLTRB(24, 24, 24, 100),
            children: [
              // Page heading
              Text(
                AppStrings.mySystemsTitle,
                style: AppTypography.headingLarge,
              ),
              const SizedBox(height: 10),

              // Status indicator row
              _StatusIndicator(
                hasViolations: hasAnyViolations,
                hasOnlineSystem: hasOnlineSystem,
              ),

              const SizedBox(height: 24),

              // Divider
              Container(
                height: 1,
                color: AppColors.borderSubtle,
              ),
              const SizedBox(height: 20),

              // System tiles or empty state
              if (systems.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.noSystemsConnected,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.noSystemsConnectedSubtext,
                        style: AppTypography.bodySecondary,
                      ),
                    ],
                  ),
                )
              else
                ...systems.map(
                  (system) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SystemTile(
                      system: system,
                      onTap: () => _openSystemDetails(context, system),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Small status indicator showing aggregate system health.
class _StatusIndicator extends StatelessWidget {
  final bool hasViolations;
  final bool hasOnlineSystem;

  const _StatusIndicator({
    required this.hasViolations,
    required this.hasOnlineSystem,
  });

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    final String label;

    if (hasViolations) {
      dotColor = AppColors.error;
      label = AppStrings.violationsDetected;
    } else if (hasOnlineSystem) {
      dotColor = AppColors.primary;
      label = AppStrings.systemsNormal;
    } else {
      dotColor = AppColors.textSecondary;
      label = AppStrings.systemsOffline;
    }

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.bodySecondary,
        ),
      ],
    );
  }
}
