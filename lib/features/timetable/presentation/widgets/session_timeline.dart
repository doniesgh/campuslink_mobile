import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../domain/entities/class_session.dart';
import '../../domain/schedule_logic.dart';
import 'session_card.dart';

/// The day's sessions and free periods, with their times on the left.
class SessionTimeline extends StatelessWidget {
  const SessionTimeline({
    super.key,
    required this.entries,
    required this.now,
    required this.onOpenSession,
    required this.onFindSeat,
  });

  final List<TimelineEntry> entries;
  final DateTime now;
  final ValueChanged<ClassSession> onOpenSession;
  final ValueChanged<ClassSession> onFindSeat;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          switch (entries[i]) {
            TimelineSession(:final session, :final status) => _TimelineRow(
                times: _Times(session: session, status: status),
                child: SessionCard(
                  session: session,
                  status: status,
                  now: now,
                  onTap: () => onOpenSession(session),
                  onFindSeat: () => onFindSeat(session),
                ),
              ),
            final TimelineBreak entry => _TimelineRow(
                times: _Times.forBreak(entry),
                child: BreakCard(entry: entry),
              ),
          },
        ],
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.times, required this.child});

  final Widget times;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            // Shrinks the times instead of overflowing with large fonts.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topRight,
              child: times,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: child),
      ],
    );
  }
}

/// "10:15 / 12:15 / NOW"
class _Times extends StatelessWidget {
  _Times({required ClassSession session, required SessionStatus status})
      : start = session.start,
        end = session.end,
        _status = status,
        _exam = session.kind == SessionKind.exam;

  _Times.forBreak(TimelineBreak entry)
      : start = entry.start,
        end = entry.end,
        _status = null,
        _exam = false;

  final DateTime start;
  final DateTime end;

  /// Null for a free period.
  final SessionStatus? _status;
  final bool _exam;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ongoing = _status == SessionStatus.ongoing;
    final upcomingExam = _exam && _status != SessionStatus.done;
    final (softBg, softFg) = toneColors(scheme, BadgeTone.accent);

    final (Color startColor, FontWeight startWeight) = _status == null
        ? (scheme.onSurfaceVariant, FontWeight.w600)
        : ongoing
            ? (softFg, FontWeight.w800)
            : upcomingExam
                ? (scheme.error, FontWeight.w800)
                : (scheme.onSurface, FontWeight.w700);
    final endColor = ongoing || upcomingExam ? scheme.onSurfaceVariant : scheme.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatHm(start),
          style: theme.textTheme.labelMedium?.copyWith(color: startColor, fontWeight: startWeight),
        ),
        Text(
          formatHm(end),
          style: theme.textTheme.labelSmall?.copyWith(color: endColor),
        ),
        if (ongoing) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: softBg, borderRadius: BorderRadius.circular(6)),
            child: Text(
              'NOW',
              style: theme.textTheme.labelSmall?.copyWith(
                color: softFg,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
