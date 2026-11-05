import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/academic_transcript.dart';
import '../../domain/grading.dart';
import '../grade_format.dart';

/// "🎓 2024–2025 · Sem 8 ⌄" pill that opens the semester picker.
class SemesterPickerPill extends StatelessWidget {
  const SemesterPickerPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tooltip(
      message: 'Change semester',
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_outlined, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.expand_more, size: 16, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing the published semesters. Returns the picked id, or
/// null when dismissed.
Future<String?> showSemesterPicker(
  BuildContext context, {
  required List<SemesterRecord> semesters,
  required String selectedId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.md,
              ),
              child: Text('Academic period', style: theme.textTheme.titleMedium),
            ),
            for (final s in semesters)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: ListTile(
                  selected: s.id == selectedId,
                  selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                  leading: const Icon(Icons.school_outlined),
                  title: Text(s.label),
                  subtitle: Text(_summary(s)),
                  trailing: s.id == selectedId
                      ? Icon(Icons.check_circle, color: scheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(s.id),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// "16.57 / 20 · Très Bien"
String _summary(SemesterRecord semester) {
  final average = semesterAverage(semester);
  if (average == null) return 'No grades yet';
  return '${formatAverage(average)} / 20 · ${mentionFor(average).label}';
}
