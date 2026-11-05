import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/ride.dart';

/// 2x2 seat grid: driver, booked, free and selected states.
class SeatPicker extends StatelessWidget {
  const SeatPicker({
    super.key,
    required this.seats,
    required this.selected,
    required this.onToggle,
  });

  final List<Seat> seats;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Available Seats', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (selected.isNotEmpty)
                AppBadge('${selected.length} Seat${selected.length > 1 ? 's' : ''} Picked'),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tap an available seat to select',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.4,
            children: [
              for (final seat in seats)
                _SeatTile(
                  seat: seat,
                  selected: selected.contains(seat.id),
                  onTap: seat.status == SeatStatus.free ? () => onToggle(seat.id) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({required this.seat, required this.selected, required this.onTap});

  final Seat seat;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final Color bg;
    final Color fg;
    final Color border;
    final IconData icon;
    final String caption;

    if (selected) {
      bg = scheme.primary;
      fg = scheme.onPrimary;
      border = scheme.primary;
      icon = Icons.event_seat;
      caption = 'Selected';
    } else {
      switch (seat.status) {
        case SeatStatus.free:
          bg = scheme.surfaceContainerLowest;
          fg = scheme.onSurface;
          border = scheme.outlineVariant;
          icon = Icons.event_seat_outlined;
          caption = 'Free';
        case SeatStatus.driver:
          bg = scheme.primaryContainer.withValues(alpha: 0.5);
          fg = scheme.onSurfaceVariant;
          border = Colors.transparent;
          icon = Icons.flag_rounded;
          caption = 'Driver';
        case SeatStatus.booked:
          bg = scheme.primaryContainer.withValues(alpha: 0.5);
          fg = scheme.onSurfaceVariant;
          border = Colors.transparent;
          icon = Icons.person_outline;
          caption = 'Booked';
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg),
              const SizedBox(height: AppSpacing.xs),
              Text(
                seat.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(color: fg),
              ),
              Text(caption, style: theme.textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.8))),
            ],
          ),
        ),
      ),
    );
  }
}
