import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../timetable/domain/entities/class_session.dart';

/// Horizontal strip of today's classes: done, now/next, later.
class TodaySchedule extends StatelessWidget {
  const TodaySchedule({super.key, required this.sessions, required this.now});

  /// Sorted by start time.
  final List<ClassSession> sessions;
  final DateTime now;

  static const _height = 150.0;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: AppCard(
          child: Row(
            children: [
              Icon(Icons.event_available, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('No classes today.', style: theme.textTheme.bodyMedium),
              ),
            ],
          ),
        ),
      );
    }

    final statuses = sessionStatuses(sessions, now);
    return SizedBox(
      height: _height,
      // The cards have a fixed height: cap text scaling so large accessibility
      // font sizes can't overflow them.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          // Vertical padding keeps the card shadows from being clipped.
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.xs),
          itemCount: sessions.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (_, i) => _SessionCard(session: sessions[i], status: statuses[i], now: now),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.status, required this.now});

  final ClassSession session;
  final SessionStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = session;
    final highlighted = status == SessionStatus.ongoing || status == SessionStatus.next;
    final strong = highlighted ? scheme.primary : scheme.onSurfaceVariant;

    final (Color bg, Color stripe, double stripeWidth) = switch (status) {
      SessionStatus.done => (scheme.surfaceContainerLow, scheme.outlineVariant, 4.0),
      SessionStatus.ongoing || SessionStatus.next =>
        (scheme.surfaceContainerHigh, scheme.primary, 6.0),
      SessionStatus.later =>
        (scheme.surfaceContainerLowest, AppColors.secondary.withValues(alpha: 0.35), 4.0),
    };

    final Widget badge = switch (status) {
      SessionStatus.done => const AppBadge('Done', tone: BadgeTone.success, icon: Icons.done),
      SessionStatus.ongoing => const AppBadge('Active now', tone: BadgeTone.accent, solid: true),
      SessionStatus.next => const AppBadge('Next', tone: BadgeTone.accent, solid: true),
      SessionStatus.later => const AppBadge('Later', tone: BadgeTone.neutral),
    };

    final (String footer, IconData footerIcon, Color footerColor) = switch (status) {
      SessionStatus.done => ('Completed', Icons.check_circle, AppColors.success),
      SessionStatus.ongoing => ('Ends at ${formatHm(s.end)}', Icons.alarm, scheme.secondary),
      SessionStatus.next => (
          'Starts in ${formatShortDuration(s.start.difference(now))}',
          Icons.alarm,
          scheme.secondary,
        ),
      SessionStatus.later => ('Later today', Icons.schedule, scheme.onSurfaceVariant),
    };

    final card = Container(
      width: highlighted ? 240 : 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: highlighted ? AppShadows.card(scheme) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: stripeWidth, color: stripe),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatTimeRange(s.start, s.end),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: strong,
                            fontWeight: highlighted ? FontWeight.w800 : null,
                          ),
                        ),
                      ),
                      badge,
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.course,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.room} · ${s.teacher}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          footer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: strong,
                            fontWeight: highlighted ? FontWeight.w700 : null,
                          ),
                        ),
                      ),
                      Icon(footerIcon, size: 16, color: footerColor),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return status == SessionStatus.done ? Opacity(opacity: 0.75, child: card) : card;
  }
}
