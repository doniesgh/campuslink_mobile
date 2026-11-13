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
import '../widgets/booking_requests_card.dart';
import '../widgets/ride_card.dart';

/// "Booking requests": every upcoming ride the student drives that received
/// seat requests, with Accept / Refuse on each, and who is already confirmed.
class BookingRequestsPage extends ConsumerStatefulWidget {
  const BookingRequestsPage({super.key});

  @override
  ConsumerState<BookingRequestsPage> createState() => _BookingRequestsPageState();
}

class _BookingRequestsPageState extends ConsumerState<BookingRequestsPage> {
  /// An answer is being sent: the buttons are disabled.
  bool _busy = false;

  Future<void> _answer(Ride ride, Seat seat, {required bool accept}) async {
    setState(() => _busy = true);
    final repo = ref.read(carpoolRepositoryProvider);
    final result = accept
        ? await repo.acceptReservation(rideId: ride.id, seatId: seat.id)
        : await repo.refuseReservation(rideId: ride.id, seatId: seat.id);
    if (!mounted) return;
    setState(() => _busy = false);

    // Success or not (it may have been answered meanwhile), show the real state.
    ref.invalidate(myRideRequestsProvider);
    ref.invalidate(ridesProvider);
    ref.invalidate(rideDetailProvider(ride.id));
    result.when(
      success: (_) => showAppSnack(
        context,
        accept ? '${seat.label} is confirmed.' : 'Request refused. The seat is free again.',
      ),
      failure: (f) => showAppSnack(context, f.message),
    );
  }

  Future<void> _open(Ride ride) async {
    await context.push(RoutePaths.ride(ride.id));
    if (!mounted) return;
    ref.invalidate(myRideRequestsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final requests = ref.watch(myRideRequestsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: requests.when(
          skipLoadingOnReload: true,
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: failureMessage(e),
            onRetry: () => ref.invalidate(myRideRequestsProvider),
          ),
          data: (all) {
            // Rides waiting for an answer first (the list is soonest-first already).
            final rides = [
              ...all.where((r) => r.pendingSeats.isNotEmpty),
              ...all.where((r) => r.pendingSeats.isEmpty),
            ];
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(myRideRequestsProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                  Text('Booking requests', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Students who asked for a seat in the rides you published.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (rides.isEmpty)
                    const EmptyView(
                      message: 'No requests yet. When a student asks for a seat in one of '
                          'your upcoming rides, it shows up here.',
                    )
                  else
                    for (final ride in rides)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            RideCard(ride: ride, onTap: () => _open(ride)),
                            if (ride.pendingSeats.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              BookingRequestsCard(
                                requests: ride.pendingSeats,
                                busy: _busy,
                                onAccept: (seat) => _answer(ride, seat, accept: true),
                                onRefuse: (seat) => _answer(ride, seat, accept: false),
                              ),
                            ],
                            _ConfirmedPassengers(
                              passengers: [
                                for (final s in ride.seats)
                                  if (s.status == SeatStatus.booked) s,
                              ],
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// "Confirmed: Name, Name" under a ride (nothing when nobody is confirmed yet).
class _ConfirmedPassengers extends StatelessWidget {
  const _ConfirmedPassengers({required this.passengers});

  final List<Seat> passengers;

  @override
  Widget build(BuildContext context) {
    if (passengers.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Confirmed:',
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          for (final seat in passengers)
            AppBadge(seat.label, tone: BadgeTone.success, icon: Icons.check),
        ],
      ),
    );
  }
}
