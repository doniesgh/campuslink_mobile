import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography. To change the font or scale, edit only this file.
abstract final class AppTypography {
  static TextTheme textTheme(TextTheme base) {
    final t = GoogleFonts.plusJakartaSansTextTheme(base);
    return t.copyWith(
      displaySmall: t.displaySmall?.copyWith(fontWeight: FontWeight.w800),
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 16),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: 14),
      bodySmall: t.bodySmall?.copyWith(fontSize: 12),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
