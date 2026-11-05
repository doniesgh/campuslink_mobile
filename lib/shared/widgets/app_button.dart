import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

enum AppButtonVariant { primary, accent, outlined }

/// Reusable button: primary (purple), accent (coral) or outlined.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !isLoading;
    final VoidCallback? tap = enabled ? onPressed : null;

    final child = isLoading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: AppSpacing.sm)],
              Text(label),
            ],
          );

    return switch (variant) {
      AppButtonVariant.primary => FilledButton(onPressed: tap, child: child),
      AppButtonVariant.accent => FilledButton(
          onPressed: tap,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.secondary,
            foregroundColor: scheme.onSecondary,
          ),
          child: child,
        ),
      AppButtonVariant.outlined => OutlinedButton(onPressed: tap, child: child),
    };
  }
}
