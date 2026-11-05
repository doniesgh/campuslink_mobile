import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../domain/entities/course.dart';

/// "GLA-401 • Block 2B" pill of the top bar. Opens the course picker when
/// [onTap] is set.
class CourseSwitcherChip extends StatelessWidget {
  const CourseSwitcherChip({super.key, required this.course, this.onTap});

  final Course course;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = scheme.onSurfaceVariant;
    final chip = Material(
      color: scheme.surfaceContainerHigh,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.xs + 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${course.code} • ${course.location}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                Icon(Icons.unfold_more, size: 14, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
    return onTap == null ? chip : Tooltip(message: 'Switch course', child: chip);
  }
}

/// Bottom sheet listing the student's courses. Returns the picked course id.
Future<String?> showCoursePickerSheet(
  BuildContext context, {
  required List<Course> courses,
  required String selectedId,
}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page, 0, AppSpacing.page, AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your courses', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            for (final c in courses)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _CourseOption(
                  course: c,
                  selected: c.id == selectedId,
                  onTap: () => Navigator.of(context).pop(c.id),
                ),
              ),
          ],
        ),
      ),
    );

class _CourseOption extends StatelessWidget {
  const _CourseOption({required this.course, required this.selected, required this.onTap});

  final Course course;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (tint, _) = toneColors(scheme, BadgeTone.primary);
    return Material(
      color: selected ? tint : scheme.surfaceContainerLow,
      borderRadius: AppRadius.lgAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(Icons.menu_book_outlined, color: scheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${course.code} • ${course.professor.displayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.xs),
                      child: LinearProgressIndicator(
                        value: course.mastery,
                        minHeight: 6,
                        color: scheme.secondary,
                        backgroundColor: scheme.surfaceContainerHigh,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${course.masteryPercent}%',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
                  ),
                  if (selected) Icon(Icons.check_circle, size: 18, color: scheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
