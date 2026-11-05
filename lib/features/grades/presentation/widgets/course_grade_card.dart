import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/grading.dart';
import '../grade_format.dart';

/// One course of the "Module Breakdown": coefficient, status pill,
/// continuous / exam / final average and a progress bar out of 20.
class CourseGradeCard extends StatelessWidget {
  const CourseGradeCard({super.key, required this.result, required this.accent});

  final CourseResult result;

  /// Leading bar, dot and progress color (alternates purple / coral).
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final course = result.course;
    final average = result.average;
    final belowPass = average != null && !isPassing(average);
    final (finalLabelColor, finalValueColor) = _finalColors(scheme, average);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Container(
              width: 6,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg + AppSpacing.sm, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                  formatCoefficientLine(course.coefficient, course.code),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            course.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Clamped so the pill never squeezes the title out.
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: _StatusPill(result: result),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow.withValues(alpha: 0.6),
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _MarkCell(label: 'Continuous', value: formatMark(course.continuous)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _MarkCell(label: 'Exam', value: formatMark(course.exam)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _MarkCell(
                          label: 'Final Average',
                          value: formatAverage(average),
                          labelColor: finalLabelColor,
                          valueColor: finalValueColor,
                          emphasized: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: LinearProgressIndicator(
                    value: result.progress,
                    minHeight: 6,
                    color: belowPass ? scheme.error : accent,
                    backgroundColor: scheme.surfaceContainerHigh,
                    semanticsLabel: '${course.title} final average',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Coral for ≥ 16/20, purple for a pass, red below 10/20.
  static (Color label, Color value) _finalColors(ColorScheme scheme, double? average) {
    if (average == null) return (scheme.onSurfaceVariant, scheme.onSurfaceVariant);
    if (!isPassing(average)) return (scheme.error, scheme.error);
    if (average >= Mention.tresBien.minAverage) {
      final dark = scheme.brightness == Brightness.dark;
      return (dark ? scheme.secondary : AppColors.accentText, scheme.secondary);
    }
    return (scheme.primary, scheme.primary);
  }
}

/// "CONTINUOUS / 17.5/20"
class _MarkCell extends StatelessWidget {
  const _MarkCell({
    required this.label,
    required this.value,
    this.labelColor,
    this.valueColor,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color? labelColor;
  final Color? valueColor;

  /// Right-aligned, extra bold (the final average).
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final alignment = emphasized ? Alignment.centerRight : Alignment.centerLeft;
    return Column(
      crossAxisAlignment: emphasized ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Single line: shrinks instead of breaking words on narrow screens.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              letterSpacing: 0.5,
              color: labelColor ?? scheme.onSurfaceVariant,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    color: valueColor ?? scheme.onSurface,
                    fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: '/20',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

/// "✓✓ Validé (A+)" / "Compensé (D)" / "Non validé (F)" / "En attente".
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.result});

  final CourseResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final letter = result.letter;
    final strong = (result.average ?? 0) >= Mention.tresBien.minAverage;
    final (accentBg, accentFg) = toneColors(scheme, BadgeTone.accent);
    final (IconData icon, String label, Color bg, Color fg) = switch (result.status) {
      CourseStatus.validated when strong =>
        (Icons.done_all, 'Validé ($letter)', scheme.surfaceContainerHigh, scheme.primary),
      CourseStatus.validated =>
        (Icons.check, 'Validé ($letter)', scheme.surfaceContainer, scheme.onSurfaceVariant),
      CourseStatus.compensated => (Icons.balance, 'Compensé ($letter)', accentBg, accentFg),
      CourseStatus.failed =>
        (Icons.close, 'Non validé ($letter)', scheme.errorContainer, scheme.onErrorContainer),
      CourseStatus.pending =>
        (Icons.hourglass_empty, 'En attente', scheme.surfaceContainer, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
