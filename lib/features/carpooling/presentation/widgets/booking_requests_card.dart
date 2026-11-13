import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/entities/ride.dart';

/// The driver's pending requests: one row per seat a student asked for,
/// with Accept and Refuse.
class BookingRequestsCard extends StatelessWidget {
  const BookingRequestsCard({
    super.key,
    required this.requests,
    required this.busy,
    required this.onAccept,
    required this.onRefuse,
  });

  final List<Seat> requests;

  /// An answer is being sent: the buttons are disabled.
  final bool busy;
  final ValueChanged<Seat> onAccept;
  final ValueChanged<Seat> onRefuse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The global button theme is full-width.
    const compact = Size(0, 38);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Booking requests', style: theme.textTheme.titleMedium)),
              Flexible(child: AppBadge('${requests.length}', tone: BadgeTone.accent, solid: true)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Students are waiting for your answer.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final seat in requests)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  UserAvatar(name: seat.label, radius: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      seat.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: busy ? null : () => onRefuse(seat),
                    style: OutlinedButton.styleFrom(
                      minimumSize: compact,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: const Text('Refuse'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: busy ? null : () => onAccept(seat),
                    style: FilledButton.styleFrom(
                      minimumSize: compact,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    ),
                    child: const Text('Accept'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
