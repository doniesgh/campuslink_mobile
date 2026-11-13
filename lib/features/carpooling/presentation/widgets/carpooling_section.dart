import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/state_views.dart';
import '../pages/my_bookings_page.dart';
import '../providers/carpool_providers.dart';
import 'ride_card.dart';

/// Content of the "Covoiturage" tab of the forum.
class CarpoolingSection extends ConsumerWidget {
  const CarpoolingSection({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rides = ref.watch(ridesProvider);

    return rides.when(
      skipLoadingOnReload: true,
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: failureMessage(e),
        onRetry: () => ref.invalidate(ridesProvider),
      ),
      data: (all) {
        final list = all.where((r) => r.matches(query)).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page, AppSpacing.sm, AppSpacing.page, 96, // room for the FAB
          ),
          children: [
           
            Row(
              children: [
                Expanded(
                  child: Text('Available Departures', style: theme.textTheme.titleMedium),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(builder: (_) => const MyBookingsPage()),
                    );
                    // A booking may have been cancelled: refresh the free seats.
                    ref.invalidate(ridesProvider);
                  },
                  icon: const Icon(Icons.confirmation_number_outlined, size: 18),
                  label: const Text('My bookings'),
                  // The global button theme is full-width.
                  style: TextButton.styleFrom(minimumSize: const Size(0, 38)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (list.isEmpty)
              const EmptyView(message: 'No rides match your search.')
            else
              for (final ride in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: RideCard(
                    ride: ride,
                    onTap: () => context.push(RoutePaths.ride(ride.id)),
                  ),
                ),
          
          ],
        );
      },
    );
  }
}
