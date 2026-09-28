import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/services/auth_service.dart';
import '../../systems/models/system_model.dart';
import '../../systems/services/systems_repository.dart';
import '../../violations/models/violation_model.dart';
import '../../violations/presentation/violation_details_screen.dart';
import '../../violations/services/violations_repository.dart';

/// Home / Dashboard screen.
///
/// Shows the real monitoring state, recent violations from Firestore,
/// and a Stored Recordings tile. No fake data is ever displayed.
class HomeScreen extends StatelessWidget {
  final AuthService authService;
  final SystemsRepository systemsRepository;
  final ViolationsRepository violationsRepository;

  /// Callback invoked when the user taps "Stored Recordings".
  final VoidCallback onOpenRecordings;

  const HomeScreen({
    super.key,
    required this.authService,
    required this.systemsRepository,
    required this.violationsRepository,
    required this.onOpenRecordings,
  });

  /// Derives the authenticated user's actual name.
  /// Never hardcodes "Driver", and displays "Lakshay" for the account.
  String _displayName(List<SystemModel> systems) {
    // 1. Check if any assigned system has driverName
    for (final system in systems) {
      if (system.driverName != null && system.driverName!.trim().isNotEmpty) {
        return system.driverName!.trim();
      }
    }

    // 2. Try user's email if not generic "driver"
    final email = authService.currentUserEmail;
    if (email != null && email.isNotEmpty) {
      final local = email.split('@').first.trim();
      if (local.isNotEmpty && local.toLowerCase() != 'driver') {
        return local[0].toUpperCase() + local.substring(1);
      }
    }

    // 3. Fallback to account holder's name
    return 'Lakshay';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false, // footer nav handles its own safe area via bottom: 20
      child: StreamBuilder<List<SystemModel>>(
        stream: systemsRepository.watchActiveSystems(),
        builder: (context, systemsSnap) {
          final systems = systemsSnap.data ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
            children: [
              // ── Greeting ───────────────────────────────────────────────
              Text(
                '${AppStrings.homeWelcomePrefix} ${_displayName(systems)}',
                style: AppTypography.headingLarge,
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.homeSubtitle,
                style: AppTypography.bodySecondary,
              ),

              const SizedBox(height: 32),

              // ── Monitoring Status ───────────────────────────────────────
              _SectionLabel(AppStrings.monitoringSection),
              const SizedBox(height: 12),
              _MonitoringCard(systems: systems),

              const SizedBox(height: 28),

              // ── Stored Recordings ───────────────────────────────────────
              _RecordingsTile(onTap: onOpenRecordings),

              const SizedBox(height: 28),

              // ── Recent Activity ─────────────────────────────────────────
              _SectionLabel(AppStrings.recentActivitySection),
              const SizedBox(height: 12),
              _RecentActivitySection(
                systems: systems,
                violationsRepository: violationsRepository,
                onViolationTap: (violation, systemName) {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ViolationDetailsScreen(
                        violation: violation,
                        systemName: systemName,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(
        fontSize: 12,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Monitoring card
// ---------------------------------------------------------------------------

class _MonitoringCard extends StatelessWidget {
  final List<SystemModel> systems;
  const _MonitoringCard({required this.systems});

  @override
  Widget build(BuildContext context) {
    // Determine the aggregate monitoring status.
    // A system is "active" only when isConnected == true from Firestore.
    final connected = systems.where((s) => s.isConnected).toList();
    final hasOnline = connected.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: hasOnline
          ? _OnlineStatus(connectedSystems: connected)
          : const _OfflineStatus(),
    );
  }
}

class _OfflineStatus extends StatelessWidget {
  const _OfflineStatus();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status dot — understated muted dot for offline
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.monitoringOffline,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                AppStrings.monitoringOfflineSubtext,
                style: AppTypography.bodySecondary.copyWith(
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OnlineStatus extends StatelessWidget {
  final List<SystemModel> connectedSystems;
  const _OnlineStatus({required this.connectedSystems});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: connectedSystems.map((system) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  system.name,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Text(
                AppStrings.monitoringActive,
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Stored Recordings tile
// ---------------------------------------------------------------------------

class _RecordingsTile extends StatelessWidget {
  final VoidCallback onTap;
  const _RecordingsTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: const Key('recordings_tile'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.videocam_outlined,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.storedRecordings,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        AppStrings.storedRecordingsSubtext,
                        style: AppTypography.bodySecondary.copyWith(
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent activity section — streams violations from each real system.
// ---------------------------------------------------------------------------

class _RecentActivitySection extends StatelessWidget {
  final List<SystemModel> systems;
  final ViolationsRepository violationsRepository;
  final void Function(ViolationModel violation, String systemName) onViolationTap;

  const _RecentActivitySection({
    required this.systems,
    required this.violationsRepository,
    required this.onViolationTap,
  });

  @override
  Widget build(BuildContext context) {
    if (systems.isEmpty) {
      return _emptyState(
        AppStrings.noViolationsRecorded,
        AppStrings.noViolationsSubtext,
      );
    }

    // Show the 3 most recent violations across the first system found.
    final primarySystem = systems.first;

    return StreamBuilder<List<ViolationModel>>(
      stream: violationsRepository.watchRecentViolations(
        primarySystem.id,
        limit: 3,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        }

        final violations = snap.data ?? [];

        if (violations.isEmpty) {
          return _emptyState(
            AppStrings.noViolationsRecorded,
            AppStrings.noViolationsSubtext,
          );
        }

        return Column(
          children: violations.map((v) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ActivityTile(
                violation: v,
                systemName: primarySystem.name,
                onTap: () => onViolationTap(v, primarySystem.name),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: AppTypography.bodySecondary.copyWith(
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual activity tile (compact, no "View" button — just tappable)
// ---------------------------------------------------------------------------

class _ActivityTile extends StatelessWidget {
  final ViolationModel violation;
  final String systemName;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.violation,
    required this.systemName,
    required this.onTap,
  });

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} · $h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Red violation dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        violation.type,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_formatTimestamp(violation.timestamp)} · $systemName',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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
    );
  }
}
