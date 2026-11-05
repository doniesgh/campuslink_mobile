import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../domain/course_logic.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_module.dart';
import '../utils/course_formatters.dart';

/// Bottom sheet with the course syllabus: upcoming modules (next one
/// highlighted), then the completed ones.
Future<void> showModulesSheet(BuildContext context, Course course) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ModulesSheet(course: course),
    );

class _ModulesSheet extends StatelessWidget {
  const _ModulesSheet({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final (_, accentFg) = toneColors(scheme, BadgeTone.accent);
    final split = splitModules(course.modules);
    final next = nextModule(course.modules);
    final hours = masteryHours(course.modules);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl,
        ),
        children: [
          Text('Course Mastery', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(course.title, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${course.completedModules} / ${course.modules.length} modules',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                '${course.masteryPercent}% passed',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: accentFg, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            child: LinearProgressIndicator(
              value: course.mastery,
              minHeight: 8,
              color: scheme.secondary,
              backgroundColor: scheme.surfaceContainerHigh,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${hours.done} of ${hours.total} teaching hours covered • ${paceLabel(course.pace)}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          if (split.upcoming.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            _GroupTitle(title: 'Upcoming', count: split.upcoming.length),
            for (final m in split.upcoming) _ModuleRow(module: m, isNext: m == next),
          ],
          if (split.completed.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            _GroupTitle(title: 'Completed', count: split.completed.length),
            for (final m in split.completed) _ModuleRow(module: m),
          ],
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Flexible(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          const SizedBox(width: AppSpacing.sm),
          AppBadge('$count', tone: BadgeTone.neutral),
        ],
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.module, this.isNext = false});

  final CourseModule module;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (bg, fg) = module.isCompleted
        ? toneColors(scheme, BadgeTone.success)
        : toneColors(scheme, isNext ? BadgeTone.accent : BadgeTone.neutral, solid: isNext);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Fixed-size bubble: cap text scaling so the number stays inside.
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: module.isCompleted
                  ? Icon(Icons.check, size: 18, color: fg)
                  : Text(
                      '${module.number}',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: fg, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              module.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: isNext ? FontWeight.w700 : null),
            ),
          ),
          if (isNext) ...[
            const SizedBox(width: AppSpacing.sm),
            const AppBadge('Up next', tone: BadgeTone.accent),
          ],
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${module.hours}h',
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
