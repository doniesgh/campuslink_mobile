import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// "‹  📅 May 19–23 · Semester 2  ›"
class WeekNavigator extends StatelessWidget {
  const WeekNavigator({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    this.onBackToToday,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Set when another week is shown: tapping the label comes back to today.
  final VoidCallback? onBackToToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final center = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.date_range, size: 18, color: scheme.primary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.mdAll,
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _NavButton(icon: Icons.chevron_left, tooltip: 'Previous week', onTap: onPrevious),
          Expanded(
            child: onBackToToday == null
                ? center
                : Tooltip(
                    message: 'Back to this week',
                    child: InkWell(
                      borderRadius: AppRadius.smAll,
                      onTap: onBackToToday,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: center,
                      ),
                    ),
                  ),
          ),
          _NavButton(icon: Icons.chevron_right, tooltip: 'Next week', onTap: onNext),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
    );
  }
}
