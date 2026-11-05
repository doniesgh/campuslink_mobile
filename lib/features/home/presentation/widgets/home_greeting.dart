import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/user_avatar.dart';

/// "Good morning, Dony 👋 / Monday, 19 May · Week 12" + search and notifications.
class HomeGreeting extends StatelessWidget {
  const HomeGreeting({
    super.key,
    required this.name,
    required this.now,
    required this.onSearch,
    required this.onNotifications,
    this.semesterWeek,
    this.hasUnreadNotifications = false,
  });

  final String name;
  final DateTime now;
  final int? semesterWeek;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;

  /// Shows the coral dot on the bell.
  final bool hasUnreadNotifications;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final firstName = name.trim().split(RegExp(r'\s+')).first;
    final greeting =
        firstName.isEmpty ? formatGreeting(now) : '${formatGreeting(now)}, $firstName';
    final week = semesterWeek;
    final caption =
        week == null ? formatLongDate(now) : '${formatLongDate(now)} · Week $week';

    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(name: name, radius: 24),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _RoundIconButton(icon: Icons.search, tooltip: 'Search', onTap: onSearch),
        const SizedBox(width: AppSpacing.xs),
        _RoundIconButton(
          icon: Icons.notifications_outlined,
          tooltip: 'Notifications',
          onTap: onNotifications,
          showDot: hasUnreadNotifications,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Coral "unread" dot.
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surfaceContainer,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                if (showDot)
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: scheme.secondary, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
