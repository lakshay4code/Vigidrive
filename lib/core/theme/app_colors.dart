import 'package:flutter/material.dart';

/// Centralized color palette for the VigiDrive application.
/// Strictly follows minimal, professional, and institutional design standards.
abstract final class AppColors {
  /// Soft pista green - primary brand accent.
  static const Color primary = Color(0xFF8DD993);

  /// Slightly deepened pista green for active/pressed interactions.
  static const Color primaryDark = Color(0xFF74C77B);

  /// Very light pista tint for subtle highlights or badge backgrounds.
  static const Color primaryLight = Color(0xFFF0FAF1);

  /// Primary pure white background.
  static const Color background = Color(0xFFFFFFFF);

  /// Clean surface background for input cards and dialogs.
  static const Color surface = Color(0xFFFFFFFF);

  /// Primary dark charcoal text color for high legibility.
  static const Color textPrimary = Color(0xFF1E2421);

  /// Subtle muted grey for secondary descriptions, hints, and helper text.
  static const Color textSecondary = Color(0xFF6B7280);

  /// Neutral border color for resting input fields and dividers.
  static const Color borderSubtle = Color(0xFFE2E8E3);

  /// Thin pista green border for focused and highlighted components.
  static const Color borderFocused = Color(0xFF8DD993);

  /// Validation error color.
  static const Color error = Color(0xFFD32F2F);

  /// Light error tint for error banners or field backgrounds.
  static const Color errorLight = Color(0xFFFDE8E8);
}
