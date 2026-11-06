import 'dart:convert';
import 'dart:typed_data';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/carpooling/data/repositories/carpool_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'carpool_fixtures.dart';

/// Answers every request with [reply] and records what was sent.
class _FakeApi implements HttpClientAdapter {
  _FakeApi(this.reply);

  final (int, String) Function(RequestOptions request) reply;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = reply(options);
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(CarpoolRepositoryImpl, _FakeApi) _repo((int, String) Function(RequestOptions) reply) {
  final api = _FakeApi(reply);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api'))..httpClientAdapter = api;
  return (CarpoolRepositoryImpl(dio), api);
}

Failure _failureOf(Result<Object?> r) =>
    r.when(success: (_) => fail('expected a failure'), failure: (f) => f);

void main() {
  test('getRides reads GET /carpool/rides', () async {
    final (repo, api) = _repo((_) => (200, '[$rideJson]'));

    final rides = (await repo.getRides()).unwrap();

    expect(api.requests.single.method, 'GET');
    expect(api.requests.single.path, '/carpool/rides');
    expect(rides.single.id, 'es-4092');
    expect(rides.single.seats[2].label, 'You');
  });

  test('getRide reads GET /carpool/rides/:id', () async {
    final (repo, api) = _repo((_) => (200, rideJson));

    final ride = (await repo.getRide('es-4092')).unwrap();

    expect(api.requests.single.path, '/carpool/rides/es-4092');
    expect(ride.code, 'ES-4092');
  });

  test('getRide turns a 404 into a failure with the server message', () async {
    final (repo, _) = _repo((_) => (404, '{"message":"Ride not found."}'));

    final failure = _failureOf(await repo.getRide('nope'));

    expect(failure, isA<ServerFailure>());
    expect(failure.message, 'Ride not found.');
  });

  test('reserveSeats posts the seat ids', () async {
    final (repo, api) = _repo((_) => (201, rideJson));

    final result = await repo.reserveSeats(rideId: 'es-4092', seatIds: ['s3', 's4']);

    expect(result, isA<Success<void>>());
    final request = api.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/carpool/rides/es-4092/reservations');
    expect(jsonDecode(jsonEncode(request.data)), {
      'seatIds': ['s3', 's4'],
    });
  });

  test('reserveSeats shows the 409 message as-is', () async {
    final (repo, _) = _repo((_) => (409, '{"message":"This seat is no longer available."}'));

    final failure = _failureOf(await repo.reserveSeats(rideId: 'es-4091', seatIds: ['s2']));

    expect(failure.message, 'This seat is no longer available.');
  });

  test('getMonthlyImpact reads GET /carpool/impact', () async {
    final (repo, api) = _repo((_) => (200, impactJson));

    final impact = (await repo.getMonthlyImpact()).unwrap();

    expect(api.requests.single.path, '/carpool/impact');
    expect(impact.savedKg, 1420);
    expect(impact.goalKg, 2000);
  });

  test('an unexpected body becomes a failure, not a crash', () async {
    final (repo, _) = _repo((_) => (200, '{"unexpected":true}'));

    expect(_failureOf(await repo.getRides()), isA<UnknownFailure>());
  });
}
