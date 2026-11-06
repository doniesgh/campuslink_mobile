import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/entities/ride.dart';

/// Driver profile, vehicle and ride rules. A new driver (no rating yet)
/// gets a "New driver" badge instead of stars.
class DriverCard extends StatelessWidget {
  const DriverCard({super.key, required this.driver, required this.amenities});

  final Driver driver;
  final List<RideAmenity> amenities;

  (String, IconData) _amenity(RideAmenity a) => switch (a) {
        RideAmenity.nonSmoking => ('Non-smoking', Icons.smoke_free),
        RideAmenity.airConditioned => ('Air-conditioned', Icons.ac_unit),
        RideAmenity.musicOk => ('Music OK', Icons.music_note),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(name: driver.name, radius: 26),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.name, style: theme.textTheme.titleMedium),
                    Text(driver.profile, style: muted),
                    const SizedBox(height: AppSpacing.xs),
                    if (driver.isNewDriver)
                      const AppBadge('New driver', icon: Icons.new_releases_outlined)
                    else
                      Row(
                        children: [
                          Icon(Icons.directions_car_outlined, size: 14, color: scheme.primary),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              '${driver.ridesCompleted} campus rides completed',
                              style: muted,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (!driver.isNewDriver)
                AppBadge(
                  driver.rating.toStringAsFixed(1),
                  tone: BadgeTone.accent,
                  icon: Icons.star_rounded,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: AppRadius.mdAll,
            ),
            child: Row(
              children: [
                Icon(Icons.directions_car_filled_outlined, color: scheme.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${driver.carModel} · ${driver.carColor}', style: theme.textTheme.titleSmall),
                      Text(driver.plate, style: muted),
                    ],
                  ),
                ),
                if (driver.isCarVerified)
                  const Flexible(
                    child: AppBadge('Verified Auto', icon: Icons.verified_outlined),
                  ),
              ],
            ),
          ),
          if (amenities.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final a in amenities)
                  AppBadge(_amenity(a).$1, tone: BadgeTone.neutral, icon: _amenity(a).$2),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
