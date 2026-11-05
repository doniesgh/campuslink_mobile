import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/schedule_logic.dart';
import '../timetable_format.dart';

/// Row of day pills (MON 19, TUE 20...). The dot under a day tells whether it
/// has an exam (coral) or classes (purple).
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.today,
    required this.onSelected,
    this.markers,
  });

  final List<DateTime> days;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelected;

  /// One per day, or null while the week is loading.
  final List<DayMarker>? markers;

  @override
  Widget build(BuildContext context) {
    // The pills share the width: cap text scaling so they keep their shape.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Row(
        children: [
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _DayPill(
                day: days[i],
                selected: isSameDay(days[i], selected),
                isToday: isSameDay(days[i], today),
                marker: markers?[i] ?? DayMarker.none,
                onTap: () => onSelected(days[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.marker,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final DayMarker marker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(AppRadius.lg);

    final dotColor = switch (marker) {
      DayMarker.none => Colors.transparent,
      DayMarker.exam => scheme.secondary,
      DayMarker.classes => selected
          ? scheme.onPrimary.withValues(alpha: 0.6)
          : scheme.primary.withValues(alpha: 0.4),
    };

    return Semantics(
      button: true,
      selected: selected,
      label: [
        formatLongDate(day),
        if (isToday) 'today',
        if (marker == DayMarker.exam) 'exam',
      ].join(', '),
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainer,
          borderRadius: radius,
          border: isToday && !selected
              ? Border.all(color: scheme.primary.withValues(alpha: 0.5), width: 1.5)
              : null,
          boxShadow: selected ? AppShadows.card(scheme) : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  children: [
                    Text(
                      formatShortWeekday(day).toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: selected
                            ? scheme.onPrimary.withValues(alpha: 0.9)
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${day.day}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: selected ? scheme.onPrimary : scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
