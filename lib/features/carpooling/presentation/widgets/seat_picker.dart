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
    this.enabled = true,
    this.onManageTap,
    this.isManageable,
  });

  final List<Seat> seats;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  /// False for the driver of the ride: they see the seats but can't book.
  final bool enabled;

  /// Tapping a taken seat that [isManageable] accepts (the driver's booked
  /// seats, the student's own seats) offers to cancel its booking.
  final ValueChanged<Seat>? onManageTap;
  final bool Function(Seat seat)? isManageable;

  bool _manageable(Seat seat) =>
      onManageTap != null &&
      (seat.status == SeatStatus.booked || seat.status == SeatStatus.pending) &&
      (isManageable?.call(seat) ?? false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flexible parts: wraps / ellipsizes instead of overflowing with large text.
          Row(
            children: [
              Expanded(child: Text('Available Seats', style: theme.textTheme.titleMedium)),
              if (selected.isNotEmpty)
                Flexible(
                  child: AppBadge('${selected.length} Seat${selected.length > 1 ? 's' : ''} Picked'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            enabled
                ? 'Tap an available seat to select'
                : onManageTap != null
                    ? 'Tap a booked seat to cancel its booking'
                    : 'Students book your free seats here',
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
                  cancellable: _manageable(seat),
                  onTap: enabled && seat.status == SeatStatus.free
                      ? () => onToggle(seat.id)
                      : _manageable(seat)
                          ? () => onManageTap!(seat)
                          : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({
    required this.seat,
    required this.selected,
    required this.onTap,
    this.cancellable = false,
  });

  final Seat seat;
  final bool selected;
  final bool cancellable;
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
        case SeatStatus.pending:
          bg = scheme.tertiaryContainer.withValues(alpha: 0.6);
          fg = scheme.onSurfaceVariant;
          border = Colors.transparent;
          icon = Icons.hourglass_top_rounded;
          caption = cancellable ? 'Tap to cancel' : 'Pending';
        case SeatStatus.booked:
          bg = scheme.primaryContainer.withValues(alpha: 0.5);
          fg = scheme.onSurfaceVariant;
          border = Colors.transparent;
          icon = Icons.person_outline;
          caption = cancellable ? 'Tap to cancel' : 'Booked';
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
