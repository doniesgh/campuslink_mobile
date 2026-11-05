import 'package:flutter/material.dart';

/// Single source of truth for brand colors.
/// Change a value here and the whole app (light + dark) follows.
abstract final class AppColors {
  // Brand palette
  static const Color primary = Color(0xFF6949A8);
  static const Color secondary = Color(0xFFFF7A59);
  static const Color tertiary = Color(0xFF775600);
  static const Color neutral = Color(0xFF120E1F);

  // Text/icon color used on top of the coral secondary (matches the mockups).
  static const Color onSecondary = Colors.white;

  // Dark-mode variant of the tertiary: #775600 is too dark on a dark surface.
  static const Color tertiaryDark = Color(0xFFE9C16C);

  // Semantic colors
  static const Color success = Color(0xFF2E9E6B);
  static const Color warning = Color(0xFFE0A100);
  static const Color danger = Color(0xFFD64545);

  // Text colors used on soft (tinted) badges in light mode
  static const Color accentText = Color(0xFFA33B1F);
  static const Color successText = Color(0xFF14694A);

  // Map preview placeholder colors
  static const Color mapWater = Color(0xFFBEE3F2);
  static const Color mapWaterDark = Color(0xFF1C3A4A);

  // Gradients (hero header of the welcome/login screens)
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7B5BBE), primary, Color(0xFF4E3487)],
  );
}
