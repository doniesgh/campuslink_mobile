import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/carpool_impact.dart';

/// "1,420 kg CO2 saved" card with the monthly goal progress.
class ImpactCard extends StatelessWidget {
  const ImpactCard({super.key, required this.impact});

  final CarpoolImpact impact;

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
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.18),
                  borderRadius: AppRadius.mdAll,
                ),
                child: const Icon(Icons.eco, color: AppColors.success),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${formatThousands(impact.savedKg)} kg ',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: 'CO₂ Saved', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Text(
                      'Achieved this month by ESPRIT carpoolers',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text(
                'Campus Monthly Goal: ${formatThousands(impact.goalKg)} kg',
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text('${impact.percent}%', style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: impact.progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: scheme.primaryContainer,
          ),
        ],
      ),
    );
  }
}
