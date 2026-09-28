import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/system_model.dart';

/// A simple, compact, and tappable tile for a monitoring system.
/// Adheres strictly to the white background and thin #8DD993 border design.
/// When offline, displays an understated status indicator and "Offline" label.
class SystemTile extends StatelessWidget {
  final SystemModel system;
  final VoidCallback onTap;

  const SystemTile({
    super.key,
    required this.system,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(
          color: AppColors.primary,
          width: 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Understated status indicator dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: system.isConnected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      system.name,
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (!system.isConnected) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'Offline',
                        style: AppTypography.caption,
                      ),
                    ],
                  ],
                ),
              ),
              if (system.hasUnresolvedViolations)
                Container(
                  key: Key('violation_indicator_${system.id}'),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
