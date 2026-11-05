import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../grade_format.dart';

/// Horizontal strip: student ID, "Official Record", "Top 5% Cohort".
class RecordChips extends StatelessWidget {
  const RecordChips({
    super.key,
    required this.studentId,
    required this.isOfficial,
    this.topPercent,
  });

  final String studentId;
  final bool isOfficial;

  /// Shown only for the top half of the cohort.
  final int? topPercent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = topPercent;
    final chips = [
      _InfoChip(
        leading: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
        ),
        label: 'ID: $studentId',
        color: scheme.onSurfaceVariant,
      ),
      if (isOfficial)
        _InfoChip(
          leading: Icon(Icons.verified, size: 14, color: scheme.primary),
          label: 'Official Record',
          color: scheme.primary,
          bold: true,
        ),
      if (top != null && top <= 50)
        _InfoChip(
          leading: Icon(Icons.military_tech, size: 14, color: scheme.secondary),
          label: 'Top $top% Cohort',
          color: scheme.onSurface,
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            chips[i],
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.leading,
    required this.label,
    required this.color,
    this.bold = false,
  });

  final Widget leading;
  final String label;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Module Breakdown" title, subtitle and course count.
class ModuleBreakdownHeader extends StatelessWidget {
  const ModuleBreakdownHeader({super.key, required this.courseCount});

  final int courseCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Module Breakdown',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Continuous assessments & final evaluations',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppBadge(formatCourseCount(courseCount)),
      ],
    );
  }
}

/// "Academic Board · Signed by Dean …" with the digital signature check.
class SignatureCard extends StatelessWidget {
  const SignatureCard({super.key, required this.signedBy});

  final String signedBy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final (successBg, successFg) = toneColors(scheme, BadgeTone.success);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: AppRadius.lgAll),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(Icons.approval, size: 26, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACADEMIC BOARD',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.55,
                  ),
                ),
                Text(
                  'Signed by $signedBy',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
                Text(
                  'Digital Signature SHA-256 Validated',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: dark ? AppColors.success : AppColors.successText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: successBg, shape: BoxShape.circle),
            child: Icon(Icons.verified_user, size: 18, color: successFg),
          ),
        ],
      ),
    );
  }
}

/// "Official University Document" card with the coral download button.
class TranscriptDownloadCard extends StatelessWidget {
  const TranscriptDownloadCard({super.key, required this.onDownload, this.sizeMb});

  final VoidCallback onDownload;
  final double? sizeMb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final size = sizeMb;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.picture_as_pdf, size: 20, color: scheme.secondary),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      'Official University Document',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (size != null)
                Text(
                  formatDocumentSize(size),
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onDownload,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.secondary,
              foregroundColor: scheme.onSecondary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download, size: 20),
                SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    'Télécharger le Relevé de Notes Officiel (PDF Signé)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Certifié conforme pour candidatures de stages, bourses et masters internationaux.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Félicitations ! Vous êtes éligible au tableau d'honneur…"
class HonorRollTile extends StatelessWidget {
  const HonorRollTile({super.key, required this.semesterNumber});

  final int semesterNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
            child: Icon(Icons.celebration, size: 16, color: scheme.onPrimary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              "Félicitations ! Vous êtes éligible au tableau d'honneur "
              'du semestre $semesterNumber.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
