import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// "Today's Schedule  [3 courses]            View all →"
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.badge,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget? badge;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.secondary;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (badge != null) ...[const SizedBox(width: AppSpacing.sm), badge!],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: accent, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward, size: 16, color: accent),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
