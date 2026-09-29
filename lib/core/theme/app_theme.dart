import 'package:flutter/material.dart';

import 'app_fonts.dart';
import 'cyber_colors.dart';

/// Builds the Material theme for cyber dark / white (light) modes.
class AppTheme {
  static ThemeData get dark => _build(CyberColors.dark, Brightness.dark);
  static ThemeData get light => _build(CyberColors.light, Brightness.light);

  static ThemeData _build(CyberColors c, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: c.positive,
      brightness: brightness,
      surface: c.surface,
    );

    final baseText = ThemeData(brightness: brightness)
        .textTheme
        .apply(fontFamily: AppFonts.display);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      colorScheme: scheme.copyWith(surface: c.surface),
      splashFactory: InkSparkle.splashFactory,
      extensions: [c],
      fontFamily: AppFonts.display,
      textTheme: baseText.copyWith(
        displaySmall: baseText.displaySmall?.copyWith(
          fontFamily: AppFonts.mono,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(color: c.textSecondary),
        bodySmall: baseText.bodySmall?.copyWith(color: c.textMuted),
        labelSmall: baseText.labelSmall?.copyWith(color: c.textMuted),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(backgroundColor: c.surface),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(c.textPrimary),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.positive : c.border,
        ),
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}