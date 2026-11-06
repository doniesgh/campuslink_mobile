import 'dart:convert';
import 'dart:typed_data';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'job_fixtures.dart';

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

(JobRepositoryImpl, _FakeApi) _repo((int, String) Function(RequestOptions) reply) {
  final api = _FakeApi(reply);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api'))..httpClientAdapter = api;
  return (JobRepositoryImpl(dio), api);
}

Failure _failureOf(Result<Object?> r) =>
    r.when(success: (_) => fail('expected a failure'), failure: (f) => f);

void main() {
  final firstJob = jsonEncode((jsonDecode(jobsJson) as List<dynamic>).first);

  test('getJobs reads GET /jobs', () async {
    final (repo, api) = _repo((_) => (200, jobsJson));

    final jobs = (await repo.getJobs()).unwrap();

    expect(api.requests.single.method, 'GET');
    expect(api.requests.single.path, '/jobs');
    expect(jobs, hasLength(3));
  });

  test('getJob reads GET /jobs/:id', () async {
    final (repo, api) = _repo((_) => (200, firstJob));

    final job = (await repo.getJob('instadeep-ml')).unwrap();

    expect(api.requests.single.path, '/jobs/instadeep-ml');
    expect(job.company, 'InstaDeep Ltd');
  });

  test('getJob turns a 404 into a failure with the server message', () async {
    final (repo, _) = _repo((_) => (404, '{"message":"Job not found."}'));

    final failure = _failureOf(await repo.getJob('nope'));

    expect(failure, isA<ServerFailure>());
    expect(failure.message, 'Job not found.');
  });

  test('apply posts to /jobs/:id/applications', () async {
    final (repo, api) = _repo(
      (_) => (201, '{"jobId":"instadeep-ml","appliedAt":"2026-11-06T10:00:00.000Z"}'),
    );

    final result = await repo.apply('instadeep-ml');

    expect(result, isA<Success<void>>());
    expect(api.requests.single.method, 'POST');
    expect(api.requests.single.path, '/jobs/instadeep-ml/applications');
  });

  test('apply shows the 409 message as-is', () async {
    final (repo, _) = _repo((_) => (409, '{"message":"You already applied to this offer."}'));

    final failure = _failureOf(await repo.apply('instadeep-ml'));

    expect(failure.message, 'You already applied to this offer.');
  });

  test('an unexpected body becomes a failure, not a crash', () async {
    final (repo, _) = _repo((_) => (200, '{"unexpected":true}'));

    expect(_failureOf(await repo.getJobs()), isA<UnknownFailure>());
  });
}
