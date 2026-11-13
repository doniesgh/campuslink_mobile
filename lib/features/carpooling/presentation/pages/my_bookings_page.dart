import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/detail_top_bar.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../domain/entities/ride.dart';
import '../providers/carpool_providers.dart';
import '../widgets/ride_card.dart';

/// "My bookings": the rides where the student booked or asked for a seat,
/// with their state (pending / booked) and a way to cancel.
class MyBookingsPage extends ConsumerStatefulWidget {
  const MyBookingsPage({super.key});

  @override
  ConsumerState<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends ConsumerState<MyBookingsPage> {
  /// Rides whose cancellation is in progress.
  final _cancelling = <String>{};

  void _refresh(String rideId) {
    ref.invalidate(myBookingsProvider);
    ref.invalidate(ridesProvider);
    ref.invalidate(rideDetailProvider(rideId));
  }

  Future<void> _cancel(Ride ride) async {
    final count = ride.mySeats.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text(
          ride.hasMyPendingRequest
              ? 'Your request for ride ${ride.code} will be withdrawn.'
              : 'Your $count seat${count == 1 ? '' : 's'} in ride ${ride.code} '
                  'will be freed for other students.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 40),
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _cancelling.add(ride.id));
    final repo = ref.read(carpoolRepositoryProvider);
    String? error;
    for (final seat in ride.mySeats) {
      final result = await repo.cancelReservation(rideId: ride.id, seatId: seat.id);
      error = result.when(success: (_) => null, failure: (f) => f.message);
      if (error != null) break;
    }
    if (!mounted) return;
    setState(() => _cancelling.remove(ride.id));
    _refresh(ride.id);
    showAppSnack(context, error ?? 'Booking cancelled.');
  }

  Future<void> _open(Ride ride) async {
    await context.push(RoutePaths.ride(ride.id));
    if (!mounted) return;
    // The student may have cancelled from the detail.
    ref.invalidate(myBookingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookings = ref.watch(myBookingsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: bookings.when(
          skipLoadingOnReload: true,
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: failureMessage(e),
            onRetry: () => ref.invalidate(myBookingsProvider),
          ),
          data: (rides) => ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              const DetailTopBar(
                backLabel: 'Forum',
                fallbackPath: RoutePaths.forum,
                trailing: [
                  Flexible(
                    child: AppBadge(
                      'Covoiturage',
                      tone: BadgeTone.neutral,
                      icon: Icons.directions_car_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('My bookings', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Rides where you booked a seat or are waiting for the driver\'s answer.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (rides.isEmpty)
                const EmptyView(message: "You haven't booked any ride yet.")
              else
                for (final ride in rides)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RideCard(ride: ride, onTap: () => _open(ride)),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _cancelling.contains(ride.id) ? null : () => _cancel(ride),
                            icon: const Icon(Icons.close_rounded),
                            label: Text(
                              ride.hasMyPendingRequest ? 'Withdraw request' : 'Cancel booking',
                            ),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              foregroundColor: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
