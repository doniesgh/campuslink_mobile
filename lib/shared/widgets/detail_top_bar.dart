import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';

/// Top bar of detail screens: "← Back to X" pill + trailing actions.
class DetailTopBar extends StatelessWidget {
  const DetailTopBar({
    super.key,
    required this.backLabel,
    required this.fallbackPath,
    this.trailing = const [],
  });

  final String backLabel;

  /// Where to go if there is nothing to pop (deep link).
  final String fallbackPath;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Material(
          color: scheme.surfaceContainerLowest,
          shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => context.canPop() ? context.pop() : context.go(fallbackPath),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 16, color: scheme.primary),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Text(
                    backLabel,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
        ...trailing,
      ],
    );
  }
}
