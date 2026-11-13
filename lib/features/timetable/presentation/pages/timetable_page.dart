import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/providers/clock_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/campus_header.dart';
import '../../domain/entities/class_session.dart';
import '../../domain/entities/timetable_week.dart';
import '../../domain/schedule_logic.dart';
import '../providers/timetable_providers.dart';
import '../timetable_format.dart';
import '../widgets/day_strip.dart';
import '../widgets/day_summary_banner.dart';
import '../widgets/session_timeline.dart';
import '../widgets/timetable_title.dart';
import '../widgets/week_navigator.dart';

const _page = EdgeInsets.symmetric(horizontal: AppSpacing.page);

/// Monday to Saturday in the day strip.
const _stripDays = 6;

/// Stitch "03. Timetable & Schedule".
class TimetablePage extends ConsumerStatefulWidget {
  const TimetablePage({super.key});

  @override
  ConsumerState<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends ConsumerState<TimetablePage> {
  /// Day picked by the user; null follows today.
  DateTime? _picked;

  Future<void> _refresh(DateTime monday) async {
    ref.invalidate(timetableWeekProvider(monday));
    try {
      await ref.read(timetableWeekProvider(monday).future);
    } catch (_) {
      // Shown by the error view.
    }
  }

  void _openCourse(ClassSession session) =>
      context.push(RoutePaths.coursesFor(session.course));

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final selected = _picked ?? defaultTimetableDay(now);
    final monday = weekStart(selected);
    final weekAsync = ref.watch(timetableWeekProvider(monday));
    final week = weekAsync.valueOrNull;
    final days = daysFrom(monday, _stripDays);
    final isCurrentWeek = isSameDay(monday, weekStart(defaultTimetableDay(now)));
    final classGroup = week?.classGroup;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const CampusHeader(section: 'Timetable'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _refresh(monday),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xxl),
                  children: [
                    Padding(
                      padding: _page,
                      child: TimetableTitle(
                        subtitle: classGroup == null
                            ? 'ESPRIT Engineering'
                            : 'ESPRIT Engineering · $classGroup',
                        // TODO: export the timetable to the device calendar.
                        onSync: () => showAppSnack(context, 'Calendar sync is coming soon.'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: _page,
                      child: WeekNavigator(
                        label: week == null
                            ? formatWeekRange(monday)
                            : formatWeekLabel(monday, semester: week.semester),
                        onPrevious: () => setState(() => _picked = addWeeks(selected, -1)),
                        onNext: () => setState(() => _picked = addWeeks(selected, 1)),
                        onBackToToday:
                            isCurrentWeek ? null : () => setState(() => _picked = null),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: _page,
                      child: DayStrip(
                        days: days,
                        selected: selected,
                        today: now,
                        markers: week == null
                            ? null
                            : [for (final d in days) dayMarker(week.dayOf(d).sessions)],
                        onSelected: (d) => setState(() => _picked = d),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    weekAsync.when(
                      skipLoadingOnReload: true,
                      loading: () => const SizedBox(
                        height: 240,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                      ),
                      error: (e, _) => Padding(
                        padding: _page,
                        child: _SectionError(
                          message: failureMessage(e),
                          onRetry: () => ref.invalidate(timetableWeekProvider(monday)),
                        ),
                      ),
                      data: (week) => _DaySchedule(
                        week: week,
                        day: selected,
                        now: now,
                        onOpenSession: _openCourse,
                        // TODO: show the seat map once the exam API exposes seat plans.
                        onFindSeat: (_) => showAppSnack(context, 'Seat finder is coming soon.'),
                        // TODO: show the student barcode once the ENT API exposes it.
                       
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Summary banner, timeline and student pass of the selected day.
class _DaySchedule extends StatelessWidget {
  const _DaySchedule({
    required this.week,
    required this.day,
    required this.now,
    required this.onOpenSession,
    required this.onFindSeat,
  });

  final TimetableWeek week;
  final DateTime day;
  final DateTime now;
  final ValueChanged<ClassSession> onOpenSession;
  final ValueChanged<ClassSession> onFindSeat;

  @override
  Widget build(BuildContext context) {
    final sessions = week.dayOf(day).sessions;
    final statuses = dayStatuses(sessions, day, now);
    String? examRoom;
    for (var i = 0; i < sessions.length; i++) {
      if (sessions[i].kind == SessionKind.exam && statuses[i] != SessionStatus.done) {
        examRoom = sessions[i].room;
        break;
      }
    }

    return Padding(
      padding: _page,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DaySummaryBanner(summary: summarizeDay(sessions), isToday: isSameDay(day, now)),
          const SizedBox(height: AppSpacing.lg),
          if (sessions.isEmpty)
            const _FreeDay()
          else
            SessionTimeline(
              entries: buildTimeline(sessions, statuses),
              now: now,
              onOpenSession: onOpenSession,
              onFindSeat: onFindSeat,
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _FreeDay extends StatelessWidget {
  const _FreeDay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      child: Row(
        children: [
          Icon(Icons.event_available, color: scheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No classes this day', style: theme.textTheme.titleSmall),
                Text(
                  'Enjoy your free day, or catch up on your revisions.',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact error with a retry link, used inside the scrolling page.
class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.error),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
