import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../domain/entities/notification_feed.dart';
import 'pulsing_dot.dart';

/// Horizontally scrolling filter chips: All · Academic · Covoiturage · Urgent Alerts.
class NotificationFilterBar extends StatelessWidget {
  const NotificationFilterBar({
    super.key,
    required this.selected,
    required this.totalCount,
    required this.hasUnreadUrgent,
    required this.onSelected,
  });

  final NotificationFilter selected;

  /// Shown in the "All" chip.
  final int totalCount;

  /// Shows the live dot on the "Urgent Alerts" chip.
  final bool hasUnreadUrgent;
  final ValueChanged<NotificationFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget chip(
      NotificationFilter filter,
      String label, {
      IconData? icon,
      int? count,
      Widget? leading,
      bool urgent = false,
    }) =>
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: _FilterChip(
            label: label,
            icon: icon,
            count: count,
            leading: leading,
            urgent: urgent,
            selected: selected == filter,
            onTap: () => onSelected(filter),
          ),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.xs),
      child: Row(
        children: [
          chip(NotificationFilter.all, 'All', count: totalCount),
          chip(NotificationFilter.academic, 'Academic', icon: Icons.school_outlined),
          chip(NotificationFilter.covoiturage, 'Covoiturage', icon: Icons.directions_car_outlined),
          chip(
            NotificationFilter.urgent,
            'Urgent Alerts',
            icon: Icons.warning_amber_rounded,
            urgent: true,
            leading: hasUnreadUrgent ? PulsingDot(color: scheme.secondary) : null,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.count,
    this.leading,
    this.urgent = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;
  final Widget? leading;

  /// Coral tint when not selected.
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (accentBg, accentFg) = toneColors(scheme, BadgeTone.accent);
    final (Color bg, Color fg, Color iconColor) = selected
        ? (scheme.primary, scheme.onPrimary, scheme.onPrimary)
        : urgent
            ? (accentBg, scheme.onSurface, accentFg)
            : (scheme.surfaceContainer, scheme.onSurfaceVariant, scheme.onSurfaceVariant);
    final count = this.count;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        elevation: selected ? 1 : 0,
        shadowColor: scheme.primary.withValues(alpha: 0.4),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 6)],
                if (icon != null) ...[
                  Icon(icon, size: 15, color: iconColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w600),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.onPrimary.withValues(alpha: 0.2)
                          : scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: selected ? scheme.onPrimary : scheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
