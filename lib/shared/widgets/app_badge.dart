import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

enum BadgeTone { primary, accent, success, neutral }

/// Background/foreground colors for a tone. Shared by badges and banners.
(Color, Color) toneColors(ColorScheme scheme, BadgeTone tone, {bool solid = false}) {
  final dark = scheme.brightness == Brightness.dark;
  switch (tone) {
    case BadgeTone.primary:
      return solid
          ? (scheme.primary, scheme.onPrimary)
          : (scheme.primaryContainer.withValues(alpha: dark ? 0.35 : 0.7), scheme.primary);
    case BadgeTone.accent:
      return solid
          ? (scheme.secondary, scheme.onSecondary)
          : (scheme.secondary.withValues(alpha: 0.16), dark ? scheme.secondary : AppColors.accentText);
    case BadgeTone.success:
      return solid
          ? (AppColors.success, Colors.white)
          : (AppColors.success.withValues(alpha: 0.15), dark ? AppColors.success : AppColors.successText);
    case BadgeTone.neutral:
      return (scheme.surfaceContainerHigh, scheme.onSurfaceVariant);
  }
}

/// Small rounded label (price, seats left, tags...).
class AppBadge extends StatelessWidget {
  const AppBadge(
    this.label, {
    super.key,
    this.tone = BadgeTone.primary,
    this.icon,
    this.solid = false,
  });

  final String label;
  final BadgeTone tone;
  final IconData? icon;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = toneColors(theme.colorScheme, tone, solid: solid);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md - 2,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
