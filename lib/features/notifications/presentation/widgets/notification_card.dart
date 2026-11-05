import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/app_notification.dart';
import '../notification_routes.dart';
import 'notification_attachments.dart';
import 'rich_body_text.dart';

/// Feed item: accent bar, icon, category badge, time, unread dot, title, body
/// and an optional attachment. Coral when urgent, purple otherwise; the icon is
/// filled while the notification is unread.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.now,
    required this.onOpen,
  });

  final AppNotification notification;
  final DateTime now;
  final VoidCallback onOpen;

  static IconData iconFor(AppNotification n) => switch (n.category) {
        NotificationCategory.academic => n.isUrgent ? Icons.edit_calendar : Icons.school,
        NotificationCategory.covoiturage => Icons.directions_car,
        NotificationCategory.lostFound => Icons.search,
        NotificationCategory.career => Icons.work,
        NotificationCategory.community => Icons.forum,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = notification;
    final unread = !n.isRead;
    final tone = n.isUrgent ? BadgeTone.accent : BadgeTone.primary;
    final (toneColor, onTone) = toneColors(scheme, tone, solid: true);
    final (softBg, softFg) = toneColors(scheme, tone);
    final (Color circleBg, Color circleFg) = unread
        ? (toneColor, onTone)
        : n.isUrgent
            ? (softBg, softFg)
            : (scheme.surfaceContainerHigh, scheme.primary);
    final attachment = n.attachment;

    return Semantics(
      label: unread ? 'Unread' : null,
      child: AppCard(
        onTap: onOpen,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: AppRadius.lgAll,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg + 2, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: circleBg,
                        shape: BoxShape.circle,
                        boxShadow: unread
                            ? [
                                BoxShadow(
                                  color: toneColor.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(iconFor(n), size: 20, color: circleFg),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: AppSpacing.xs,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    AppBadge(
                                      n.label,
                                      tone: n.isUrgent
                                          ? BadgeTone.accent
                                          : unread
                                              ? BadgeTone.primary
                                              : BadgeTone.neutral,
                                    ),
                                    Text(
                                      notificationTimeLabel(n.receivedAt, now),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: scheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              if (unread) ...[
                                const SizedBox(width: AppSpacing.xs),
                                Padding(
                                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                                  child: _UnreadDot(color: toneColor, glow: n.isUrgent),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            n.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 17,
                              height: 24 / 17,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          RichBodyText(n.body),
                          if (attachment != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            NotificationAttachmentView(attachment: attachment, onOpen: onOpen),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: ColoredBox(color: toneColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.color, required this.glow});

  final Color color;
  final bool glow;

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: glow
              ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)]
              : null,
        ),
      );
}
