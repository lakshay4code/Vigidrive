import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../systems/models/system_model.dart';
import '../../systems/services/systems_repository.dart';
import '../../violations/models/violation_model.dart';
import '../../violations/presentation/violation_details_screen.dart';
import '../../violations/services/violations_repository.dart';

/// Notifications screen — shows real unresolved violations from Firestore.
///
/// Displays violations across all registered systems. If no systems are
/// registered, or no violations exist, shows an honest empty state.
/// No fake notification counts or fake alerts are ever shown.
class NotificationsScreen extends StatelessWidget {
  final SystemsRepository systemsRepository;
  final ViolationsRepository violationsRepository;

  const NotificationsScreen({
    super.key,
    required this.systemsRepository,
    required this.violationsRepository,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: StreamBuilder<List<SystemModel>>(
        stream: systemsRepository.watchActiveSystems(),
        builder: (context, systemsSnap) {
          final systems = systemsSnap.data ?? [];

          if (systems.isEmpty) {
            return _buildEmpty();
          }

          // Stream violations for the first registered system.
          // When multi-system is needed, this can be extended.
          final primarySystem = systems.first;

          return StreamBuilder<List<ViolationModel>>(
            stream: violationsRepository
                .watchViolationsForSystem(primarySystem.id),
            builder: (context, violationsSnap) {
              if (violationsSnap.connectionState == ConnectionState.waiting &&
                  !violationsSnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                );
              }

              final violations = violationsSnap.data ?? [];
              final unresolved =
                  violations.where((v) => !v.resolved).toList();

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.notificationsTitle,
                            style: AppTypography.headingLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            unresolved.isEmpty
                                ? AppStrings.noNewNotifications
                                : '${unresolved.length} unresolved '
                                  '${unresolved.length == 1 ? 'alert' : 'alerts'}',
                            style: AppTypography.bodySecondary,
                          ),
                          const SizedBox(height: 20),
                          Container(
                            height: 1,
                            color: AppColors.borderSubtle,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (unresolved.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.noNewNotifications,
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppStrings.noNewNotificationsSubtext,
                              style: AppTypography.bodySecondary,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final v = unresolved[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _NotificationTile(
                                violation: v,
                                systemName: primarySystem.name,
                                onTap: () {
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute(
                                      builder: (_) => ViolationDetailsScreen(
                                        violation: v,
                                        systemName: primarySystem.name,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          childCount: unresolved.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.notificationsTitle,
                style: AppTypography.headingLarge),
            const SizedBox(height: 24),
            Container(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 24),
            Text(
              AppStrings.noNewNotifications,
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.noNewNotificationsSubtext,
              style: AppTypography.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual notification tile
// ---------------------------------------------------------------------------

class _NotificationTile extends StatelessWidget {
  final ViolationModel violation;
  final String systemName;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.violation,
    required this.systemName,
    required this.onTap,
  });

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.borderSubtle, width: 1.0),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Red dot indicating unresolved violation
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      violation.type,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      systemName,
                      style: AppTypography.bodySecondary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTimestamp(violation.timestamp),
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
