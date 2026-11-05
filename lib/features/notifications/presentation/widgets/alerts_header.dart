import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../notification_routes.dart';
import 'pulsing_dot.dart';

/// "Campus Alerts" title, today's unread summary and the "Mark all read" pill.
class AlertsHeader extends StatelessWidget {
  const AlertsHeader({
    super.key,
    required this.unreadToday,
    required this.unreadTotal,
    required this.onMarkAllRead,
  });

  final int unreadToday;
  final int unreadTotal;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, shape: BoxShape.circle),
            child: Icon(Icons.notifications_active, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Campus Alerts',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    height: 32 / 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.36,
                  ),
                ),
                Row(
                  children: [
                    if (unreadToday > 0) ...[
                      PulsingDot(color: scheme.secondary),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        criticalUpdatesLabel(unreadToday),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Never more than half the row, so the title keeps room on small screens.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: _MarkAllButton(done: unreadTotal == 0, onTap: onMarkAllRead),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkAllButton extends StatelessWidget {
  const _MarkAllButton({required this.done, required this.onTap});

  /// Nothing left to mark: shows the "All Read" state.
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (bg, fg) =
        done ? (scheme.surfaceContainerHigh, scheme.onSurfaceVariant) : (scheme.secondary, scheme.onSecondary);
    return Material(
      color: bg,
      shape: const StadiumBorder(),
      elevation: done ? 0 : 1,
      shadowColor: scheme.secondary.withValues(alpha: 0.4),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: done ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(done ? Icons.check : Icons.done_all, size: 15, color: fg),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  done ? 'All Read' : 'Mark all read',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
