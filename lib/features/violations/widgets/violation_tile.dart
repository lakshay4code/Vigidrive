import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/violation_model.dart';

/// Compact tile representing a single violation event.
/// Reused on both the System Details and All Violations screens.
class ViolationTile extends StatelessWidget {
  final ViolationModel violation;
  final VoidCallback onView;

  const ViolationTile({
    super.key,
    required this.violation,
    required this.onView,
  });

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Red violation dot
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

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTime(violation.timestamp),
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  violation.type,
                  style: AppTypography.bodySecondary,
                ),
                const SizedBox(height: 2),
                Text(
                  'Duration ${_formatDuration(violation.durationSeconds)}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),

          // View action
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: TextButton(
              onPressed: onView,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                AppStrings.view,
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
