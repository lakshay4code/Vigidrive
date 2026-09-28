import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../systems/models/system_model.dart';
import '../../systems/services/systems_repository.dart';
import '../../violations/models/violation_model.dart';
import '../../violations/presentation/violation_details_screen.dart';
import '../../violations/services/violations_repository.dart';

/// Recordings screen — full-screen pushed route accessible from Home.
///
/// Shows only violations where a real [ViolationModel.recordingPath] exists.
/// If none exist, displays an honest empty state. No fake thumbnails,
/// durations, or video players are ever generated.
/// Note: recordingPath contains a local PC file path, not a network URL.
class RecordingsScreen extends StatelessWidget {
  final SystemsRepository systemsRepository;
  final ViolationsRepository violationsRepository;

  const RecordingsScreen({
    super.key,
    required this.systemsRepository,
    required this.violationsRepository,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: AppColors.textPrimary, size: 22),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          AppStrings.appName,
          style: AppTypography.headingMedium,
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<SystemModel>>(
          stream: systemsRepository.watchActiveSystems(),
          builder: (context, systemsSnap) {
            final systems = systemsSnap.data ?? [];

            if (systems.isEmpty) {
              return _buildContent(context, recordings: [], systemMap: {});
            }

            // Collect violations with real recording URLs across all systems.
            // Use the first available system's stream; extend for multi-system later.
            final primarySystem = systems.first;

            return StreamBuilder<List<ViolationModel>>(
              stream: violationsRepository
                  .watchViolationsForSystem(primarySystem.id),
              builder: (context, violationsSnap) {
                if (violationsSnap.connectionState ==
                        ConnectionState.waiting &&
                    !violationsSnap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  );
                }

                final violations = violationsSnap.data ?? [];
                // Only violations that have a real, non-empty recording path.
                final recordings = violations
                    .where((v) =>
                        v.recordingPath != null &&
                        v.recordingPath!.isNotEmpty)
                    .toList();

                final systemMap = {
                  for (final s in systems) s.id: s.name,
                };

                return _buildContent(context,
                    recordings: recordings, systemMap: systemMap);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required List<ViolationModel> recordings,
    required Map<String, String> systemMap,
  }) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      children: [
        Text(
          AppStrings.recordingsTitle,
          style: AppTypography.headingLarge,
        ),
        const SizedBox(height: 4),
        Text(
          recordings.isEmpty
              ? AppStrings.noRecordingsAvailable
              : '${recordings.length} '
                '${recordings.length == 1 ? 'recording' : 'recordings'} available',
          style: AppTypography.bodySecondary,
        ),
        const SizedBox(height: 20),
        Container(height: 1, color: AppColors.borderSubtle),
        const SizedBox(height: 16),

        if (recordings.isEmpty)
          _EmptyRecordingsState()
        else
          ...recordings.map((v) {
            final systemName =
                systemMap[v.systemId] ?? v.systemId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecordingTile(
                violation: v,
                systemName: systemName,
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ViolationDetailsScreen(
                        violation: v,
                        systemName: systemName,
                      ),
                    ),
                  );
                },
              ),
            );
          }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyRecordingsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSubtle, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.noRecordingsAvailable,
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.recordingsSubtext,
              style: AppTypography.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual recording tile
// ---------------------------------------------------------------------------

class _RecordingTile extends StatelessWidget {
  final ViolationModel violation;
  final String systemName;
  final VoidCallback onTap;

  const _RecordingTile({
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
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $h:$m:$s';
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
            children: [
              // Video icon indicating a recording exists
              const Icon(
                Icons.videocam_outlined,
                color: AppColors.textSecondary,
                size: 22,
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
                color: AppColors.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
