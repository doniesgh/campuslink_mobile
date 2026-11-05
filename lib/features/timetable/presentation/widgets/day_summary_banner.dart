import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../domain/schedule_logic.dart';
import '../timetable_format.dart';

/// "⚡ 4 Sessions Scheduled        1 Exam Today · 7h 30m Total"
class DaySummaryBanner extends StatelessWidget {
  const DaySummaryBanner({super.key, required this.summary, required this.isToday});

  final DaySummary summary;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    final accent = toneColors(scheme, BadgeTone.accent).$2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      // Wraps the totals under the count when they don't fit on one line.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt, size: 20, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  formatSessionCount(summary.sessions),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (summary.sessions > 0)
            Text.rich(
              TextSpan(
                children: [
                  if (summary.exams > 0) ...[
                    TextSpan(
                      text: formatExamCount(summary.exams, today: isToday),
                      style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: '  •  ',
                      style: TextStyle(color: scheme.outlineVariant),
                    ),
                  ],
                  TextSpan(text: '${formatCompactDuration(summary.total)} Total'),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: small,
            ),
        ],
      ),
    );
  }
}
