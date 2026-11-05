import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/entities/ride.dart';

/// Departure card of the carpooling list.
class RideCard extends StatelessWidget {
  const RideCard({super.key, required this.ride, required this.onTap});

  final Ride ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final urgent = ride.isAlmostFull;
    final accent = urgent ? scheme.secondary : scheme.primary;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: AppRadius.lgAll,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(ride: ride, accent: accent, urgent: urgent),
                      const SizedBox(height: AppSpacing.md),
                      _RouteLines(ride: ride),
                      const Divider(height: AppSpacing.xl),
                      _DriverRow(ride: ride, urgent: urgent, onJoin: onTap),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.ride, required this.accent, required this.urgent});
  final Ride ride;
  final Color accent;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(urgent ? Icons.bolt : Icons.schedule, size: 16, color: accent),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(
          child: Text(
            formatDepartureLabel(ride.departure),
            style: theme.textTheme.labelLarge?.copyWith(color: accent),
          ),
        ),
        AppBadge(
          '${ride.pricePerSeat.toStringAsFixed(1)} TND / pers',
          tone: BadgeTone.accent,
          solid: true,
        ),
      ],
    );
  }
}

class _RouteLines extends StatelessWidget {
  const _RouteLines({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);

    Widget dot(Color c) => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs + 2),
          child: Column(
            children: [
              dot(scheme.primary),
              Container(width: 2, height: 34, color: scheme.outlineVariant),
              dot(scheme.secondary),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pickup', style: muted),
              Text(ride.pickup, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.sm),
              Text('Dropoff', style: muted),
              Text(ride.dropoff, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({required this.ride, required this.urgent, required this.onJoin});
  final Ride ride;
  final bool urgent;
  final VoidCallback onJoin;

  String get _seatsLabel {
    final n = ride.freeSeatCount;
    if (n == 0) return 'Complet';
    return n == 1 ? '1 place restante' : '$n places';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = ride.driver;
    return Row(
      children: [
        UserAvatar(name: d.name, radius: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
                  Text(d.rating.toStringAsFixed(1), style: theme.textTheme.labelSmall),
                ],
              ),
              Text(
                '${d.carModel} ${d.carColor}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: AppBadge(_seatsLabel, tone: urgent ? BadgeTone.accent : BadgeTone.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        // minimumSize overridden: the global button theme is full-width.
        FilledButton(
          onPressed: ride.freeSeatCount == 0 ? null : onJoin,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 38),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          child: const Text('Rejoindre →'),
        ),
      ],
    );
  }
}
