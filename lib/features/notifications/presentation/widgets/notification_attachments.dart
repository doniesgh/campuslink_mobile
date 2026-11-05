import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../domain/entities/app_notification.dart';

/// Block under a notification body: place, ride, schedule actions or pickup status.
class NotificationAttachmentView extends StatelessWidget {
  const NotificationAttachmentView({
    super.key,
    required this.attachment,
    required this.onOpen,
  });

  final NotificationAttachment attachment;

  /// Opens the notification target (used by "View Trip Details").
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => switch (attachment) {
        PlaceAttachment(:final place) => _PlaceSnippet(place: place),
        final RideAttachment ride => _RideSnippet(ride: ride, onViewTrip: onOpen),
        ScheduleAttachment() => const _ScheduleActions(),
        final PickupAttachment pickup => _PickupSnippet(pickup: pickup),
      };
}

class _Snippet extends StatelessWidget {
  const _Snippet({required this.child, this.padding = AppSpacing.sm});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: AppRadius.smAll,
        ),
        child: child,
      );
}

class _PlaceSnippet extends StatelessWidget {
  const _PlaceSnippet({required this.place});

  final String place;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (_, accent) = toneColors(scheme, BadgeTone.accent);
    return _Snippet(
      child: Row(
        children: [
          Icon(Icons.explore_outlined, size: 16, color: accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              place,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _InlineLink(
            label: 'Map pin',
            trailingIcon: Icons.arrow_forward,
            color: scheme.primary,
            // TODO: open the campus map on this room once it exists.
            onTap: () => showAppSnack(context, 'Campus map is coming soon.'),
          ),
        ],
      ),
    );
  }
}

class _RideSnippet extends StatelessWidget {
  const _RideSnippet({required this.ride, required this.onViewTrip});

  final RideAttachment ride;
  final VoidCallback onViewTrip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (_, success) = toneColors(scheme, BadgeTone.success);

    final driver = Row(
      children: [
        UserAvatar(name: ride.driverName, radius: 16),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ride.carLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (ride.isDriverVerified)
                Row(
                  children: [
                    Icon(Icons.verified, size: 12, color: success),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        'Verified Student Driver',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(color: success),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
    final button = Material(
      color: scheme.primary,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        borderRadius: AppRadius.smAll,
        onTap: onViewTrip,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 7),
          child: Text(
            'View Trip Details',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );

    return _Snippet(
      padding: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Side by side only when the car details keep a readable width.
          final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
          if (constraints.maxWidth >= 300 * scale) {
            return Row(
              children: [
                Expanded(child: driver),
                const SizedBox(width: AppSpacing.sm),
                button,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [driver, const SizedBox(height: AppSpacing.sm), button],
          );
        },
      ),
    );
  }
}

class _ScheduleActions extends StatelessWidget {
  const _ScheduleActions();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _ActionPill(
          icon: Icons.picture_as_pdf_outlined,
          label: 'Download Schedule',
          background: scheme.surfaceContainer,
          foreground: scheme.primary,
          // TODO: download the convocation PDF once the registrar API exists.
          onTap: () => showAppSnack(context, 'Schedule download is coming soon.'),
        ),
        _ActionPill(
          icon: Icons.event_note_outlined,
          label: 'Add to Calendar',
          background: Colors.transparent,
          foreground: scheme.onSurfaceVariant,
          // TODO: export the exam dates to the device calendar.
          onTap: () => showAppSnack(context, 'Calendar sync is coming soon.'),
        ),
      ],
    );
  }
}

class _PickupSnippet extends StatelessWidget {
  const _PickupSnippet({required this.pickup});

  final PickupAttachment pickup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (_, success) = toneColors(scheme, BadgeTone.success);
    final (_, accent) = toneColors(scheme, BadgeTone.accent);
    return _Snippet(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 15, color: success),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  pickup.availability,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          _InlineLink(
            label: 'Claim ticket #${pickup.ticket}',
            color: accent,
            // TODO: start the claim flow once lost & found has an API.
            onTap: () => showAppSnack(context, 'Claiming items is coming soon.'),
          ),
        ],
      ),
    );
  }
}

/// Text-only action ("Map pin →", "Claim ticket #492").
class _InlineLink extends StatelessWidget {
  const _InlineLink({
    required this.label,
    required this.color,
    required this.onTap,
    this.trailingIcon,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: color, fontWeight: FontWeight.w700);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
            if (trailingIcon != null) ...[
              const SizedBox(width: 2),
              Icon(trailingIcon, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: background,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        borderRadius: AppRadius.smAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
