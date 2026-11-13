import 'dart:convert';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/carpooling/data/models/carpool_models.dart';
import 'package:campuspulse/features/carpooling/domain/entities/new_ride.dart';
import 'package:campuspulse/features/carpooling/domain/entities/ride.dart';
import 'package:campuspulse/features/carpooling/domain/repositories/carpool_repository.dart';
import 'package:campuspulse/features/carpooling/presentation/pages/ride_detail_page.dart';
import 'package:campuspulse/features/carpooling/presentation/providers/carpool_providers.dart';
import 'package:campuspulse/features/carpooling/presentation/widgets/driver_card.dart';
import 'package:campuspulse/features/carpooling/presentation/widgets/ride_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'carpool_fixtures.dart';

/// The detail page's list (the seat grid inside it is a Scrollable too).
final _pageList = find.byType(Scrollable).first;

Ride _parse(String json) =>
    RideModel.fromJson(jsonDecode(json) as Map<String, dynamic>);

/// Serves one ride to the detail page.
class _OneRideRepository implements CarpoolRepository {
  _OneRideRepository(this.ride);
  final Ride ride;

  @override
  Future<Result<Ride>> getRide(String id) async => id == ride.id
      ? Success(ride)
      : const Err(ServerFailure('Ride not found.'));
  @override
  Future<Result<List<Ride>>> getMyBookings() async => const Success([]);
  @override
  Future<Result<List<Ride>>> getRides() async => Success([ride]);

  @override
  Future<Result<Ride>> reserveSeats({
    required String rideId,
    required List<String> seatIds,
  }) async =>
      const Err(ServerFailure('Not implemented'));

  @override
  Future<Result<Ride>> createRide(NewRide ride) async => Success(this.ride);

  @override
  Future<Result<Ride>> updateRide(String rideId, NewRide ride) async =>
      Success(this.ride);
  @override
  Future<Result<Ride>> refuseReservation({
    required String rideId,
    required String seatId,
  }) async =>
      const Err(ServerFailure('Not implemented'));

  @override
  Future<Result<void>> deleteRide(String rideId) async => const Success(null);
  @override
  Future<Result<Ride>> acceptReservation({
    required String rideId,
    required String seatId,
  }) async =>
      const Err(ServerFailure('Not implemented'));

  @override
  Future<Result<Ride>> cancelReservation(
          {required String rideId, required String seatId}) async =>
      Success(this.ride);
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Ride? ride,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(360, 800) * 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (ride != null)
          carpoolRepositoryProvider.overrideWithValue(_OneRideRepository(ride)),
      ],
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary, brightness: brightness),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final created = _parse(createdRideJson);
  final rated = _parse(rideJson);

  testWidgets('DriverCard shows "New driver" instead of a 0.0 star rating',
      (tester) async {
    await _pump(
      tester,
      Scaffold(
          body:
              DriverCard(driver: created.driver, amenities: created.amenities)),
    );
    expect(find.text('New driver'), findsOneWidget);
    expect(find.text('0.0'), findsNothing);
    expect(find.textContaining('campus rides completed'), findsNothing);
    expect(find.text('Verified Auto'), findsNothing);
    expect(find.text('4th Year Software Engineering student'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DriverCard keeps the rating of a rated driver', (tester) async {
    await _pump(
      tester,
      Scaffold(
          body: DriverCard(driver: rated.driver, amenities: rated.amenities)),
    );
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('21 campus rides completed'), findsOneWidget);
    expect(find.text('New driver'), findsNothing);
  });

  testWidgets('RideCard shows "New driver" in the list', (tester) async {
    await _pump(tester, Scaffold(body: RideCard(ride: created, onTap: () {})));
    expect(find.text('New driver'), findsOneWidget);
    expect(find.text('0.0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        "the driver sees their own ride but can't book in it (${brightness.name})",
        (tester) async {
      await _pump(
        tester,
        RideDetailPage(rideId: created.id),
        ride: created,
        brightness: brightness,
      );

      // No booking bar for the driver.
      expect(find.text('Reserve Seat'), findsNothing);
      expect(find.text('RIDE #ES-4094'), findsOneWidget);

      // The list is lazy: scroll to each part in turn.
      // No note and no distance were given.
      await tester.scrollUntilVisible(find.text('not given'), 200,
          scrollable: _pageList);
      expect(find.text('—'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('New driver'), 200,
          scrollable: _pageList);
      await tester.scrollUntilVisible(
          find.text("You're driving this ride"), 200,
          scrollable: _pageList);
      await tester.scrollUntilVisible(
          find.text('Students book your free seats here'), 200,
          scrollable: _pageList);

      await tester.scrollUntilVisible(find.text('Seat #2'), 200,
          scrollable: _pageList);
      await tester.tap(find.text('Seat #2'));
      await tester.pumpAndSettle();
      expect(find.text('Selected'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('another student can still book in a ride', (tester) async {
    await _pump(tester, RideDetailPage(rideId: rated.id), ride: rated);
    expect(find.text('Reserve Seat'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Tap an available seat to select'), 200,
        scrollable: _pageList);
    expect(find.text("You're driving this ride"), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
