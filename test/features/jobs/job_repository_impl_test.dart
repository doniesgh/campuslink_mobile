import 'dart:convert';
import 'dart:typed_data';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/jobs/data/repositories/job_repository_impl.dart';
import 'package:campuspulse/features/jobs/domain/entities/job_draft.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'job_fixtures.dart';

/// Answers every request with [reply] and records what was sent.
class _FakeApi implements HttpClientAdapter {
  _FakeApi(this.reply);

  final (int, String) Function(RequestOptions request) reply;
  final requests = <RequestOptions>[];

  /// The JSON bodies sent, in order.
  List<Object?> get bodies => [for (final r in requests) r.data];

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
        if (status == 429) 'retry-after': ['600'],
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

  group('posting, editing and deleting offers', () {
    const draft = JobDraft(
      title: ' Flutter Mobile Intern ',
      company: 'Medina Soft',
      description: 'Build the Flutter app our clients use to book appointments every day.',
      location: 'Lac 1, Tunis',
      period: 'Feb – Jul 2026',
      durationMonths: 6,
      skills: ['Flutter', 'Dart'],
      tags: ['PFE 2026'],
    );

    test('createJob posts every field of the form to /jobs and reads the offer back', () async {
      final (repo, api) = _repo((_) => (201, postedJobJson));

      final job = (await repo.createJob(draft)).unwrap();

      expect(api.requests.single.method, 'POST');
      expect(api.requests.single.path, '/jobs');
      expect(api.bodies.single, {
        'title': 'Flutter Mobile Intern',
        'company': 'Medina Soft',
        'description': 'Build the Flutter app our clients use to book appointments every day.',
        'location': 'Lac 1, Tunis',
        'period': 'Feb – Jul 2026',
        'durationMonths': 6,
        'stipendTnd': null,
        'skills': ['Flutter', 'Dart'],
        'tags': ['PFE 2026'],
      });
      expect(job.id, '6af7380cf0f064d239616440');
      expect(job.canEdit, isTrue);
      expect(job.authorId, isNotNull);
      expect(job.stipendTnd, isNull);
      expect(job.matchPercent, isNull);
      expect(job.labGroup, isNull);
      expect(job.workspaceTitle, isNull);
      expect(job.mission, startsWith('Build the Flutter app'));
    });

    test("createJob shows the server's 403 and 422 messages", () async {
      final (forbidden, _) = _repo((_) => (403, postForbiddenJson));
      final refused = _failureOf(await forbidden.createJob(draft));
      expect(refused, isA<ServerFailure>());
      expect(refused.message, 'Only companies and administrators can post offers.');

      final (invalid, _) = _repo((_) => (422, postInvalidJson));
      final failure = _failureOf(await invalid.createJob(draft));
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'The title needs at least 3 characters.');
      expect(failure.code, 'VALIDATION_ERROR');
    });

    test('updateJob patches /jobs/:id', () async {
      final (repo, api) = _repo((_) => (200, postedJobJson));

      await repo.updateJob('6af7380cf0f064d239616440', draft);

      expect(api.requests.single.method, 'PATCH');
      expect(api.requests.single.path, '/jobs/6af7380cf0f064d239616440');
      expect((api.bodies.single! as Map<String, dynamic>)['durationMonths'], 6);
    });

    test('deleteJob sends DELETE /jobs/:id and accepts the empty 204', () async {
      final (repo, api) = _repo((_) => (204, ''));

      expect(await repo.deleteJob('offer-1'), isA<Success<void>>());
      expect(api.requests.single.method, 'DELETE');
      expect(api.requests.single.path, '/jobs/offer-1');
    });
  });

  group('summarize', () {
    test('posts to /jobs/:id/summary and reads the summary', () async {
      final (repo, api) = _repo((_) => (200, jobSummaryJson));

      final summary = (await repo.summarize('instadeep-ml')).unwrap();

      expect(api.requests.single.method, 'POST');
      expect(api.requests.single.path, '/jobs/instadeep-ml/summary');
      expect(summary.summary, startsWith('A 6-month research internship'));
      expect(summary.keyPoints, hasLength(4));
      expect(summary.skills, ['PyTorch', 'JAX', 'Reinforcement Learning']);
      expect(summary.idealFor, 'A 5th-year student who enjoys research and Python.');
      expect(summary.model, 'anthropic/claude-haiku-5.5');
      expect(summary.cached, isFalse);
    });

    test('a server without AI fails with the AI_UNAVAILABLE code', () async {
      final (repo, _) = _repo((_) => (503, aiUnavailableJson));

      final failure = _failureOf(await repo.summarize('instadeep-ml'));

      expect(failure.code, 'AI_UNAVAILABLE');
      expect(failure.message, 'AI features are not available on this server.');
    });

    test('the hourly limit fails with TOO_MANY_REQUESTS and the wait', () async {
      final (repo, _) = _repo(
        (_) => (
          429,
          '{"message":"Too many summaries. Try again later.","code":"TOO_MANY_REQUESTS","retryAfter":600}',
        ),
      );

      final failure = _failureOf(await repo.summarize('instadeep-ml'));

      expect(failure, isA<TooManyRequestsFailure>());
      expect(failure.code, 'TOO_MANY_REQUESTS');
      expect((failure as TooManyRequestsFailure).retryAfter, const Duration(minutes: 10));
    });
  });
}
