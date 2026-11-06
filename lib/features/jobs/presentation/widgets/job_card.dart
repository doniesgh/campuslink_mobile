import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/job.dart';
import 'job_logo.dart';

/// Offer card of the Jobs list.
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              JobLogo(initials: job.companyInitials, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.title, style: theme.textTheme.titleSmall),
                    Text(
                      '${job.company} · ${job.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              AppBadge('${job.matchPercent}% Match', tone: BadgeTone.success),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (job.hasApplied)
                const AppBadge('Applied', tone: BadgeTone.primary, icon: Icons.check, solid: true),
              for (final t in job.tags) AppBadge(t, tone: BadgeTone.neutral),
              AppBadge('${formatThousands(job.stipendTnd)} TND/mo', tone: BadgeTone.accent),
            ],
          ),
        ],
      ),
    );
  }
}
