import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/violation_model.dart';

/// Full-detail screen for a single violation event.
class ViolationDetailsScreen extends StatelessWidget {
  final ViolationModel violation;
  final String systemName;

  const ViolationDetailsScreen({
    super.key,
    required this.violation,
    required this.systemName,
  });

  String _formatDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatDuration(double seconds) {
    final whole = seconds.truncate();
    final frac = ((seconds - whole) * 10).round();
    return '${whole.toString().padLeft(2, '0')}.$frac seconds';
  }

  String _formatConfidence(double? value) {
    if (value == null) return 'N/A';
    return '${(value * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 22,
          ),
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
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            // Heading
            const Text(
              AppStrings.drowsinessDetected,
              style: AppTypography.headingLarge,
            ),
            const SizedBox(height: 8),

            // Detection confirmed indicator
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppStrings.detectionConfirmed,
                  style: AppTypography.bodySecondary,
                ),
              ],
            ),

            const SizedBox(height: 24),
            Container(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 20),

            // Detail rows
            _DetailRow(label: AppStrings.date, value: _formatDate(violation.timestamp)),
            _DetailRow(label: AppStrings.time, value: _formatTime(violation.timestamp)),
            _DetailRow(label: AppStrings.duration, value: _formatDuration(violation.durationSeconds)),
            _DetailRow(label: AppStrings.system, value: systemName),
            _DetailRow(label: AppStrings.driver, value: violation.driverName),
            _DetailRow(label: AppStrings.detectionResult, value: AppStrings.sleepy),
            _DetailRow(label: AppStrings.confidence, value: _formatConfidence(violation.confidence)),

            const SizedBox(height: 24),
            Container(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 20),

            // Recording section
            Text(
              AppStrings.recording,
              style: AppTypography.label,
            ),
            const SizedBox(height: 12),
            Container(
              key: const Key('recording_status'),
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
                  Row(
                    children: [
                      Icon(
                        violation.recordingPath != null && violation.recordingPath!.isNotEmpty
                            ? Icons.videocam_outlined
                            : Icons.videocam_off_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          violation.recordingPath != null && violation.recordingPath!.isNotEmpty
                              ? AppStrings.recordingStoredOnPC
                              : AppStrings.noRecordingAvailable,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    violation.recordingPath != null && violation.recordingPath!.isNotEmpty
                        ? AppStrings.recordingStoredOnPCSubtext
                        : AppStrings.noRecordingAvailableSubtext,
                    style: AppTypography.bodySecondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple label–value row used in the violation details layout.
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption),
          const SizedBox(height: 4),
          Text(value, style: AppTypography.bodyLarge),
        ],
      ),
    );
  }
}
