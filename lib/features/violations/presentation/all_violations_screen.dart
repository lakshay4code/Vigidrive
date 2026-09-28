import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/violation_model.dart';
import '../services/violations_repository.dart';
import '../widgets/violation_tile.dart';
import 'violation_details_screen.dart';

/// Displays the complete violation history for a specific monitoring system.
class AllViolationsScreen extends StatefulWidget {
  final String systemId;
  final String systemName;
  final ViolationsRepository violationsRepository;

  const AllViolationsScreen({
    super.key,
    required this.systemId,
    required this.systemName,
    required this.violationsRepository,
  });

  @override
  State<AllViolationsScreen> createState() => _AllViolationsScreenState();
}

class _AllViolationsScreenState extends State<AllViolationsScreen> {
  void _openViolationDetails(ViolationModel violation) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ViolationDetailsScreen(
          violation: violation,
          systemName: widget.systemName,
        ),
      ),
    );
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
        child: StreamBuilder<List<ViolationModel>>(
          stream:
              widget.violationsRepository.watchViolationsForSystem(widget.systemId),
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

            final violations = snapshot.data ?? [];

            return ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                // System name
                Text(
                  widget.systemName,
                  style: AppTypography.headingLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.viewAllViolations,
                  style: AppTypography.bodySecondary,
                ),
                const SizedBox(height: 20),
                Container(height: 1, color: AppColors.borderSubtle),
                const SizedBox(height: 16),

                if (violations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Text(
                      AppStrings.noViolationsRecorded,
                      style: AppTypography.bodySecondary,
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ...violations.map(
                    (violation) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ViolationTile(
                        violation: violation,
                        onView: () => _openViolationDetails(violation),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
