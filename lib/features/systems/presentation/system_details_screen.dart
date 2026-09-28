import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../violations/models/violation_model.dart';
import '../../violations/presentation/all_violations_screen.dart';
import '../../violations/presentation/violation_details_screen.dart';
import '../../violations/services/violations_repository.dart';
import '../../violations/widgets/violation_tile.dart';
import '../models/system_model.dart';

/// Detailed view for a single monitoring system showing status, driver info,
/// contact action, and recent violations.
class SystemDetailsScreen extends StatefulWidget {
  final SystemModel system;
  final ViolationsRepository violationsRepository;

  const SystemDetailsScreen({
    super.key,
    required this.system,
    required this.violationsRepository,
  });

  @override
  State<SystemDetailsScreen> createState() => _SystemDetailsScreenState();
}

class _SystemDetailsScreenState extends State<SystemDetailsScreen> {
  Future<void> _contactDriver() async {
    final phone = widget.system.driverPhone;
    if (phone == null || phone.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.dialerError,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.errorLight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _openAllViolations() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AllViolationsScreen(
          systemId: widget.system.id,
          systemName: widget.system.name,
          violationsRepository: widget.violationsRepository,
        ),
      ),
    );
  }

  void _openViolationDetails(ViolationModel violation) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ViolationDetailsScreen(
          violation: violation,
          systemName: widget.system.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final system = widget.system;

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
            // System name
            Text(
              system.name,
              style: AppTypography.headingLarge,
            ),
            const SizedBox(height: 10),

            // Violation status indicator (only when violations exist)
            if (system.hasUnresolvedViolations)
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
                    AppStrings.violationsDetected,
                    style: AppTypography.bodySecondary.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 24),
            Container(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 20),

            // ── System Information ───────────────────────────────────────
            _buildInfoSection(system),

            const SizedBox(height: 24),
            Container(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 20),

            // ── Recent Violations ────────────────────────────────────────
            _buildRecentViolations(),
          ],
        ),
      ),
    );
  }

  /// System status, driver, and contact action.
  Widget _buildInfoSection(SystemModel system) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // System Status
        Text(
          AppStrings.systemStatus,
          style: AppTypography.caption,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: system.isConnected ? AppColors.primary : AppColors.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              system.isConnected ? AppStrings.active : 'OFFLINE',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Driver
        Text(
          AppStrings.driver,
          style: AppTypography.caption,
        ),
        const SizedBox(height: 6),
        Text(
          system.driverName ?? '—',
          style: AppTypography.bodyLarge,
        ),
        const SizedBox(height: 16),

        // Contact Driver
        if (system.driverPhone != null && system.driverPhone!.isNotEmpty)
          TextButton.icon(
            onPressed: _contactDriver,
            icon: const Icon(
              Icons.phone_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            label: Text(
              AppStrings.contactDriver,
              style: AppTypography.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  /// Recent violations list with View All action.
  Widget _buildRecentViolations() {
    return StreamBuilder<List<ViolationModel>>(
      stream: widget.violationsRepository
          .watchRecentViolations(widget.system.id, limit: 3),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          );
        }

        final violations = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.recentViolations,
              style: AppTypography.headingMedium,
            ),
            const SizedBox(height: 16),

            if (violations.isEmpty)
              Text(
                AppStrings.noViolationsRecorded,
                style: AppTypography.bodySecondary,
              )
            else ...[
              ...violations.map(
                (violation) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ViolationTile(
                    violation: violation,
                    onView: () => _openViolationDetails(violation),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _openAllViolations,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    AppStrings.viewAllViolations,
                    style: AppTypography.label.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
