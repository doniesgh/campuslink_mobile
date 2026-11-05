import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography, as in the Stitch designs: Plus Jakarta Sans for headlines,
/// titles and labels; Inter for body text.
/// To change the font or scale, edit only this file.
abstract final class AppTypography {
  static TextTheme textTheme(TextTheme base) {
    final t = GoogleFonts.plusJakartaSansTextTheme(base);
    TextStyle body(TextStyle? style, double size, double lineHeight) =>
        GoogleFonts.inter(
          textStyle: style?.copyWith(fontSize: size, height: lineHeight / size),
        );
    return t.copyWith(
      displaySmall: t.displaySmall?.copyWith(fontWeight: FontWeight.w800),
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: body(t.bodyLarge, 16, 24),
      bodyMedium: body(t.bodyMedium, 14, 21),
      bodySmall: body(t.bodySmall, 13, 18),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
