import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/stat_tile.dart';
import '../../domain/entities/job.dart';
import 'job_logo.dart';

/// Featured header: logo, title, company and tags.
class JobHeaderCard extends StatelessWidget {
  const JobHeaderCard({super.key, required this.job});

  final Job job;

  static const _tones = [BadgeTone.accent, BadgeTone.primary, BadgeTone.success];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              JobLogo(initials: job.companyInitials),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (job.featuredLabel != null)
                      Text(
                        job.featuredLabel!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.secondary,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    Text(job.title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(Icons.apartment, size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            '${job.company} · ${job.location}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < job.tags.length; i++)
                AppBadge(job.tags[i], tone: _tones[i % _tones.length]),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stipend / duration / lab group tiles.
class JobStatsRow extends StatelessWidget {
  const JobStatsRow({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatTile(
            icon: Icons.payments_outlined,
            label: 'Stipend',
            value: formatThousands(job.stipendTnd),
            caption: 'TND/mo',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StatTile(
            icon: Icons.schedule,
            label: 'Duration',
            value: '${job.durationMonths} Months',
            caption: job.period,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StatTile(
            icon: Icons.groups_outlined,
            label: 'Lab Group',
            value: job.labGroup,
            caption: job.labGroupNote,
          ),
        ),
      ],
    );
  }
}

/// Workspace banner (gradient placeholder until real photos are provided).
class JobWorkspaceBanner extends StatelessWidget {
  const JobWorkspaceBanner({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: AppRadius.lgAll,
      child: Container(
        height: 170,
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.hero),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Stack(
          children: [
            const Center(child: Icon(Icons.groups, size: 64, color: Colors.white24)),
            Align(
              alignment: Alignment.topLeft,
              child: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  AppBadge(job.workspaceTitle, tone: BadgeTone.accent, solid: true),
                  const AppBadge('ESPRIT Partner Lab', tone: BadgeTone.neutral),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final b in job.workspaceBadges)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.md - 2, vertical: AppSpacing.xs + 1,
                        ),
                        child: Text(
                          b,
                          style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "About the Mission" section.
class JobMissionCard extends StatelessWidget {
  const JobMissionCard({super.key, required this.job});

  final Job job;

  static const _icons = [
    Icons.science_outlined,
    Icons.public,
    Icons.inventory_2_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('About the Mission', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(job.mission, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < job.missionItems.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Icon(_icons[i % _icons.length], size: 20, color: scheme.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(job.missionItems[i].title, style: theme.textTheme.titleSmall),
                          Text(
                            job.missionItems[i].description,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Candidate Fit & Criteria" section with match percentage and skills.
class JobFitCard extends StatelessWidget {
  const JobFitCard({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: scheme.secondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Candidate Fit & Criteria', style: theme.textTheme.titleMedium),
              ),
              AppBadge('${job.matchPercent}% Match', tone: BadgeTone.success),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final c in job.criteria)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 18, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(c, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in job.skills) AppBadge(s, tone: BadgeTone.neutral),
            ],
          ),
        ],
      ),
    );
  }
}
