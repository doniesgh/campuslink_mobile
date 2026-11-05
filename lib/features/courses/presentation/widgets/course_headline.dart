import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../domain/entities/course.dart';

/// Course title with the attendance badge, then term and track.
class CourseHeadline extends StatelessWidget {
  const CourseHeadline({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Text(
      course.title,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.36,
      ),
    );
    final badge = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: course.isPresent
          ? const AppBadge(
              'Present',
              key: ValueKey('present'),
              tone: BadgeTone.accent,
              icon: Icons.check_circle,
            )
          : const AppBadge(
              'Absent',
              key: ValueKey('absent'),
              tone: BadgeTone.neutral,
              icon: Icons.radio_button_unchecked,
            ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Large fonts / narrow screens: the badge would squeeze the title.
        final stacked = constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stacked) ...[
              title,
              const SizedBox(height: AppSpacing.xs),
              badge,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  const SizedBox(width: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: badge,
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${course.term} • ${course.track}',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}
