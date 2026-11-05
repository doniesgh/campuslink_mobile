import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/stat_tile.dart';
import '../../domain/entities/ride.dart';

/// Route title, price and the departure / arrival / distance tiles.
class RideSummaryCard extends StatelessWidget {
  const RideSummaryCard({super.key, required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                        Flexible(
                          child: Text(ride.pickup, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                          child: Icon(Icons.arrow_forward, size: 16),
                        ),
                        Flexible(
                          child: Text(ride.dropoff, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(Icons.school_outlined, size: 14, color: muted),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(ride.dropoffNote, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppBadge('${ride.pricePerSeat.toStringAsFixed(3)} TND', tone: BadgeTone.accent, solid: true),
                  const SizedBox(height: AppSpacing.xs),
                  Text('per seat', style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Departure',
                  value: formatHm(ride.departure),
                  caption: formatDayCaption(ride.departure),
                  centered: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatTile(
                  label: 'Est. Arrival',
                  value: formatHm(ride.arrival),
                  caption: 'On Time',
                  centered: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatTile(
                  label: 'Distance',
                  value: ride.distanceKm.toStringAsFixed(1),
                  caption: 'km total',
                  centered: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
