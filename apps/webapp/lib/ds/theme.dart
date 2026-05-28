import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

// DDR-001: profissional × light — esquema pré-login (verde-sage).
// ColorScheme.fromSeed + override dos neutros conforme §3.1 e nota de implementação.
ThemeData buildLightTheme() {
  final cs =
      ColorScheme.fromSeed(
        seedColor: TurniColors.accentLight,
        brightness: Brightness.light,
      ).copyWith(
        primary: TurniColors.accentLight,
        onPrimary: Colors.white,
        surface: TurniColors.surfaceLight,
        onSurface: TurniColors.textStrongLight,
        onSurfaceVariant: TurniColors.textMutedLight,
        outlineVariant: TurniColors.borderSubtleLight,
      );

  return ThemeData(
    colorScheme: cs,
    scaffoldBackgroundColor: TurniColors.surfacePageLight,
    useMaterial3: true,
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
    cardTheme: const CardThemeData(
      color: TurniColors.surfaceLight,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(TurniRadius.lg),
      ),
    ),
  );
}

// DDR-001: profissional × dark.
ThemeData buildDarkTheme() {
  final cs =
      ColorScheme.fromSeed(
        seedColor: TurniColors.accentDark,
        brightness: Brightness.dark,
      ).copyWith(
        primary: TurniColors.accentDark,
        onPrimary: TurniColors.surfacePageDark,
        surface: TurniColors.surfaceDark,
        onSurface: TurniColors.textStrongDark,
        onSurfaceVariant: TurniColors.textMutedDark,
        outlineVariant: TurniColors.borderSubtleDark,
      );

  return ThemeData(
    colorScheme: cs,
    scaffoldBackgroundColor: TurniColors.surfacePageDark,
    useMaterial3: true,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    cardTheme: const CardThemeData(
      color: TurniColors.surfaceDark,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(TurniRadius.lg),
      ),
    ),
  );
}
