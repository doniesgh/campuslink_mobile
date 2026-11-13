import 'dart:async';
import 'dart:convert';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/core/providers/clock_provider.dart';
import 'package:campuspulse/core/router/route_names.dart';
import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/carpooling/data/models/carpool_models.dart';
import 'package:campuspulse/features/carpooling/domain/entities/new_ride.dart';
import 'package:campuspulse/features/carpooling/domain/entities/ride.dart';
import 'package:campuspulse/features/carpooling/domain/repositories/carpool_repository.dart';
import 'package:campuspulse/features/carpooling/presentation/pages/new_ride_page.dart';
import 'package:campuspulse/features/carpooling/presentation/providers/carpool_providers.dart';
import 'package:campuspulse/shared/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'carpool_fixtures.dart';

/// Friday 6 November 2026, 10:00: "Demain" is Saturday 7.
final _now = DateTime(2026, 11, 6, 10);

/// Records what the page publishes. [hold] keeps the request pending, to see
/// the loading state; [answer] is the server's reply.
class _FakeCarpoolRepository implements CarpoolRepository {
  final published = <NewRide>[];
  Completer<void>? hold;
  Result<Ride> Function(NewRide ride) answer = (_) => Success(
      RideModel.fromJson(jsonDecode(createdRideJson) as Map<String, dynamic>));
  int getRidesCalls = 0;

  @override
  Future<Result<Ride>> createRide(NewRide ride) async {
    published.add(ride);
    await hold?.future;
    return answer(ride);
  }

  @override
  Future<Result<List<Ride>>> getRides() async {
    getRidesCalls++;
    return const Success([]);
  }

  @override
  Future<Result<List<Ride>>> getMyRideRequests() async => const Success([]);

  @override
  Future<Result<List<Ride>>> getMyBookings() async => const Success([]);

  @override
  Future<Result<Ride>> acceptReservation({
    required String rideId,
    required String seatId,
  }) async =>
      const Err(ServerFailure('Not implemented'));

  @override
  Future<Result<Ride>> refuseReservation({
    required String rideId,
    required String seatId,
  }) async =>
      const Err(ServerFailure('Not implemented'));

  @override
  Future<Result<Ride>> getRide(String id) async =>
      const Err(ServerFailure('Ride not found.'));

  @override
  Future<Result<Ride>> reserveSeats({
    required String rideId,
    required List<String> seatIds,
  }) async =>
      const Err(ServerFailure('Not implemented'));

  @override
  Future<Result<Ride>> updateRide(String rideId, NewRide ride) async =>
      const Err(ServerFailure('Not implemented'));

  @override
  Future<Result<void>> deleteRide(String rideId) async => const Success(null);

  @override
  Future<Result<Ride>> cancelReservation(
          {required String rideId, required String seatId}) async =>
      const Err(ServerFailure('Not implemented'));
}

/// Opens the form above a stand-in Forum (which lists the rides, so the
/// refresh after publishing shows) at [width] dp with [textScale] text.
Future<(GoRouter, _FakeCarpoolRepository)> _openForm(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  double width = 360,
  double textScale = 1.3,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(width, 800) * 3;
  addTearDown(tester.view.reset);

  final repo = _FakeCarpoolRepository();
  final router = GoRouter(
    initialLocation: RoutePaths.forum,
    routes: [
      GoRoute(
        path: RoutePaths.forum,
        builder: (_, __) => Consumer(
          builder: (_, ref, __) {
            ref.watch(ridesProvider);
            return const Scaffold(body: Center(child: Text('Forum screen')));
          },
        ),
        routes: [
          GoRoute(path: 'rides/new', builder: (_, __) => const NewRidePage()),
          GoRoute(
            path: 'rides/:rideId',
            builder: (_, state) => Scaffold(
                body: Center(
                    child: Text('Ride ${state.pathParameters['rideId']}'))),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        carpoolRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWith((ref) => Stream.value(_now)),
      ],
      child: MaterialApp.router(
        // Plain theme: the app theme pulls Google Fonts from the network.
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary, brightness: brightness),
        ),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(router.push(RoutePaths.newRide));
  await tester.pumpAndSettle();
  return (router, repo);
}

Finder _field(String label) => find.descendant(
      of: find.widgetWithText(AppTextField, label),
      matching: find.byType(TextFormField),
    );

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(_field(label));
  await tester.enterText(_field(label), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Fills every input with a valid ride leaving tomorrow at 11:00.
Future<void> _fillForm(WidgetTester tester) async {
  await _type(tester, 'Départ', '  Lac 2 (Tunis City) ');
  await _type(tester, 'Repère du départ', 'Lac 2');
  await _type(tester, 'Destination', 'ESPRIT Ghazela (Bloc E)');
  await _type(tester, 'Repère de la destination', 'ESPRIT Bloc E');

  await _tap(tester, find.text('Demain'));
  // The picker suggests about an hour from now, on the quarter: 11:00.
  await _tap(tester, find.text('Choisir une heure'));
  expect(find.text('Heure de départ'), findsWidgets); // picker title
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  expect(find.text('11:00'), findsOneWidget);
  expect(find.text('Demain · 11h00'), findsOneWidget);
  await _tap(tester, find.byTooltip('Allonger')); // 35 min

  await _tap(tester, find.byTooltip('Une place de moins')); // 2 seats
  await _tap(tester, find.byTooltip('Augmenter le prix')); // 2.5 TND

  await _type(tester, 'Modèle', 'Volkswagen Polo');
  await _type(tester, 'Couleur', 'Blue');
  await _type(tester, 'Plaque', '231 TN 1187');
  await _tap(tester, find.text('Climatisé'));
  await _type(tester, 'Note pour le dépôt', 'Dépôt devant le Bloc E');
  await _type(tester, 'Distance (km)', '12,4');
}

const _requiredErrors = [
  'Indiquez le point de départ.',
  'Ajoutez un repère court pour le départ.',
  'Indiquez la destination.',
  'Ajoutez un repère court pour la destination.',
  "Choisissez l'heure de départ.",
  'Indiquez le modèle de la voiture.',
  'Indiquez la couleur de la voiture.',
  "Indiquez la plaque d'immatriculation.",
];

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'fills, validates and publishes a ride (360 dp, text x1.3, ${brightness.name})',
      (tester) async {
        final (router, repo) = await _openForm(tester, brightness: brightness);

        expect(find.text('Proposer un trajet'), findsOneWidget);
        expect(find.text('Forum'), findsOneWidget); // back pill
        expect(find.text('3 places proposées'), findsOneWidget);
        expect(find.text('2.0 TND'), findsWidgets);

        // Empty form: every required field says what is missing, nothing is sent.
        await tester.tap(find.text('Publier'));
        await tester.pumpAndSettle();
        for (final message in _requiredErrors) {
          expect(find.text(message), findsOneWidget, reason: message);
        }
        expect(repo.published, isEmpty);

        // Optional fields are checked too.
        await _type(tester, 'Distance (km)', 'loin');
        expect(find.text('La distance doit être entre 0,1 et 1000 km.'),
            findsOneWidget);

        await _fillForm(tester);
        // Errors follow the edits once the student has tried to publish.
        for (final message in [
          ..._requiredErrors,
          'La distance doit être entre 0,1 et 1000 km.'
        ]) {
          expect(find.text(message), findsNothing, reason: message);
        }
        expect(find.text('2 places proposées'), findsOneWidget);
        expect(find.text('2.5 TND'), findsWidgets);
        expect(find.text('Arrivée estimée : 11:35'), findsOneWidget);

        repo.hold = Completer<void>();
        await tester.tap(find.text('Publier'));
        await tester.pump();

        // Loading on the button while the request runs.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        final sent = repo.published.single;
        expect(sent.pickup, 'Lac 2 (Tunis City)');
        expect(sent.pickupTag, 'Lac 2');
        expect(sent.dropoff, 'ESPRIT Ghazela (Bloc E)');
        expect(sent.dropoffTag, 'ESPRIT Bloc E');
        expect(sent.departure, DateTime(2026, 11, 7, 11));
        expect(sent.arrival, DateTime(2026, 11, 7, 11, 35));
        expect(sent.seatCount, 2);
        expect(sent.pricePerSeat, 2.5);
        expect((sent.carModel, sent.carColor, sent.plate),
            ('Volkswagen Polo', 'Blue', '231 TN 1187'));
        expect(sent.amenities, [RideAmenity.airConditioned]);
        expect(sent.dropoffNote, 'Dépôt devant le Bloc E');
        expect(sent.distanceKm, 12.4);

        final listLoads = repo.getRidesCalls;
        repo.hold!.complete();
        await tester.pumpAndSettle();

        // The new ride's detail replaces the form; back leads to the Forum.
        expect(find.text('Ride es-4094'), findsOneWidget);
        expect(
          find.text(
              'Trajet publié ! Les étudiants peuvent réserver vos places.'),
          findsOneWidget,
        );
        expect(repo.getRidesCalls, listLoads + 1,
            reason: 'the ride list is refreshed');
        router.pop();
        await tester.pumpAndSettle();
        expect(find.text('Forum screen'), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
      'shows the server message when publishing fails, and stays on the form',
      (tester) async {
    final (_, repo) = await _openForm(tester);
    repo.answer = (_) =>
        const Err(ValidationFailure('Le départ doit être dans le futur.'));

    await _fillForm(tester);
    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();

    expect(repo.published, hasLength(1));
    expect(find.text('Le départ doit être dans le futur.'), findsOneWidget);
    expect(find.text('Proposer un trajet'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      '"Aujourd\'hui" with the suggested time leaves in an hour, and steppers stop at '
      'their limits', (tester) async {
    final (_, repo) = await _openForm(tester);

    await _tap(tester, find.text('Choisir une heure'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text("Aujourd'hui · 11h00"), findsOneWidget);

    for (var i = 0; i < 6; i++) {
      await _tap(tester, find.byTooltip('Une place de plus'));
    }
    expect(find.text('4 places proposées'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await _tap(tester, find.byTooltip('Baisser le prix'));
    }
    expect(find.text('Gratuit'), findsWidgets);

    await _tap(tester, find.text('Publier'));
    // Still incomplete (no places, no car): nothing is sent.
    expect(repo.published, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolls down to the end without overflow at 320 dp',
      (tester) async {
    await _openForm(tester, width: 320, textScale: 1);
    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(find.text('Ce que voient les passagers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
