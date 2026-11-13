import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/bottom_action_bar.dart';
import '../../../../shared/widgets/detail_top_bar.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/ride.dart';
import '../providers/carpool_providers.dart';
import '../widgets/driver_card.dart';
import '../widgets/ride_summary_card.dart';
import '../widgets/route_map_preview.dart';
import '../widgets/seat_picker.dart';

/// "Ride Detail & Booking" screen.
class RideDetailPage extends ConsumerStatefulWidget {
  const RideDetailPage({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<RideDetailPage> createState() => _RideDetailPageState();
}

class _RideDetailPageState extends ConsumerState<RideDetailPage> {
  /// null = user has not touched the seats yet -> first free seat is preselected.
  Set<String>? _picked;
  bool _reserving = false;

  Set<String> _selection(Ride ride) {
    // The driver can't book a seat in their own ride.
    if (ride.isMine) return const {};
    final free = ride.freeSeats.map((s) => s.id).toSet();
    final base = _picked ?? (free.isEmpty ? <String>{} : {free.first});
    return base.where(free.contains).toSet();
  }

  void _toggle(Ride ride, String seatId) {
    final current = {..._selection(ride)};
    if (current.contains(seatId)) {
      current.remove(seatId);
    } else {
      current.add(seatId);
    }
    setState(() => _picked = current);
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _reserve(Ride ride) async {
    final seatIds = _selection(ride).toList();
    setState(() => _reserving = true);
    final result = await ref
        .read(carpoolRepositoryProvider)
        .reserveSeats(rideId: ride.id, seatIds: seatIds);
    if (!mounted) return;
    setState(() => _reserving = false);

    result.when(
      success: (_) {
        setState(() => _picked = <String>{});
        ref.invalidate(rideDetailProvider(ride.id));
        ref.invalidate(ridesProvider);
        _snack('Seat reserved. See you on board!');
      },
      failure: (f) => _snack(f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rideDetailProvider(widget.rideId));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: async.when(
          skipLoadingOnReload: true,
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: failureMessage(e),
            onRetry: () => ref.invalidate(rideDetailProvider(widget.rideId)),
          ),
          data: _buildContent,
        ),
      ),
    );
  }

  Widget _buildContent(Ride ride) {
    final selected = _selection(ride);
    final count = selected.length;
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              // Without the booking bar, keep clear of the system bar.
              AppSpacing.lg + (ride.isMine ? MediaQuery.paddingOf(context).bottom : 0),
            ),
            children: [
              DetailTopBar(
                backLabel: 'Back to Forum',
                fallbackPath: RoutePaths.forum,
                trailing: [
                  // Flexible: ellipsized rather than overflowing with large text.
                  Flexible(child: AppBadge('RIDE #${ride.code}', tone: BadgeTone.neutral)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              RouteMapPreview(ride: ride),
              const SizedBox(height: AppSpacing.md),
              RideSummaryCard(ride: ride),
              const SizedBox(height: AppSpacing.md),
              DriverCard(driver: ride.driver, amenities: ride.amenities),
              const SizedBox(height: AppSpacing.md),
              if (ride.isMine) ...[
                const InfoBanner(
                  icon: Icons.drive_eta_outlined,
                  tone: BadgeTone.success,
                  title: "You're driving this ride",
                  message: 'Students book your free seats from here. Their names '
                      'appear on the seats they take.',
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              SeatPicker(
                seats: ride.seats,
                selected: selected,
                enabled: !ride.isMine,
                onToggle: (id) => _toggle(ride, id),
              ),
             
            ],
          ),
        ),
        if (!ride.isMine)
          BottomActionBar(
            leading: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TOTAL BOOKING',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(
                  '${ride.totalFor(count).toStringAsFixed(3)} TND',
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  '$count seat${count == 1 ? '' : 's'} selected',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            action: AppButton(
              label: 'Reserve Seat',
              icon: Icons.bolt,
              variant: AppButtonVariant.accent,
              isLoading: _reserving,
              onPressed: count == 0 ? null : () => _reserve(ride),
            ),
          ),
      ],
    );
  }
}
