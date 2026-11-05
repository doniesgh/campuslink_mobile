import 'package:flutter/material.dart';

/// Reusable shadows. Pass the scheme so shadows adapt to light/dark.
abstract final class AppShadows {
  static List<BoxShadow> card(ColorScheme scheme) => [
        BoxShadow(
          color: scheme.primary.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> elevated(ColorScheme scheme) => [
        BoxShadow(
          color: scheme.primary.withValues(alpha: 0.18),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}
