import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import 'pulsing_dot.dart';

/// "My Timetable •" + class group, and the calendar sync button.
class TimetableTitle extends StatelessWidget {
  const TimetableTitle({super.key, required this.subtitle, required this.onSync});

  final String subtitle;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'My Timetable',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: scheme.primary,
                        fontSize: 24,
                        height: 32 / 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.36,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  PulsingDot(color: scheme.secondary),
                ],
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Tooltip(
          message: 'Sync with Apple / Google Calendar',
          child: Material(
            color: scheme.surfaceContainerHigh,
            borderRadius: AppRadius.mdAll,
            child: InkWell(
              borderRadius: AppRadius.mdAll,
              onTap: onSync,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.event, size: 20, color: scheme.primary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
