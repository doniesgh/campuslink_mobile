import 'dart:async';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/jobs/domain/entities/job_summary.dart';
import 'package:campuspulse/features/jobs/presentation/providers/job_providers.dart';
import 'package:campuspulse/features/jobs/presentation/widgets/job_summary_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_job_repository.dart';

/// A button that opens the summary sheet of [sampleJob], as the detail page does.
Future<void> _openSheet(WidgetTester tester, FakeJobRepository repository) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [jobRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showJobSummarySheet(context, sampleJob),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
}

void main() {
  testWidgets('shows a loader, then the summary, key points, skills and "ideal for"',
      (tester) async {
    final repository = FakeJobRepository();
    final answer = Completer<Result<JobSummary>>();
    repository.summaryAnswer = () => answer.future;

    await _openSheet(tester, repository);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('AI summary'), findsOneWidget);
    expect(find.text('Summarising the offer…'), findsOneWidget);

    answer.complete(
      const Success(
        JobSummary(
          summary: 'A 6-month Flutter internship at Medina Soft.',
          keyPoints: ['Build the booking app', 'Lac 1, Tunis'],
          skills: ['Flutter', 'Dart'],
          idealFor: 'A 4th-year student who likes mobile apps.',
          model: 'test/model-a',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Summarising the offer…'), findsNothing);
    expect(find.text('A 6-month Flutter internship at Medina Soft.'), findsOneWidget);
    expect(find.text('Key points'), findsOneWidget);
    expect(find.text('Build the booking app'), findsOneWidget);
    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('Ideal for'), findsOneWidget);
    expect(find.text('A 4th-year student who likes mobile apps.'), findsOneWidget);
    expect(find.text('AI-generated: check the full offer. · test/model-a'), findsOneWidget);
    expect(repository.summaryCalls, 1);
  });

  testWidgets('explains that AI is not set up on the server, without a Retry', (tester) async {
    final repository = FakeJobRepository()
      ..summaryAnswer = () async => const Err(
            ServerFailure('AI features are not available on this server.', 'AI_UNAVAILABLE'),
          );

    await _openSheet(tester, repository);
    await tester.pumpAndSettle();

    expect(find.textContaining('AI summaries are not set up on this server yet'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('explains the hourly limit and retries on demand', (tester) async {
    final repository = FakeJobRepository()
      ..summaryAnswer = () async => const Err(
            TooManyRequestsFailure(
              'Too many summaries. Try again later.',
              'TOO_MANY_REQUESTS',
              Duration(seconds: 540),
            ),
          );

    await _openSheet(tester, repository);
    await tester.pumpAndSettle();

    expect(
      find.text('You asked for too many summaries. Try again in 9 minutes.'),
      findsOneWidget,
    );
    repository.summaryAnswer = () async => const Success(JobSummary(summary: 'Second try.'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Second try.'), findsOneWidget);
    expect(repository.summaryCalls, 2);
  });

  test('jobSummaryErrorText explains each AI code', () {
    expect(
      jobSummaryErrorText(const ServerFailure('x', 'AI_BUSY')),
      'The AI service is busy right now. Try again in a few minutes.',
    );
    expect(
      jobSummaryErrorText(const ServerFailure('x', 'AI_NO_CREDITS')),
      'The AI service has no credits left for now. Try again later.',
    );
    expect(
      jobSummaryErrorText(const TooManyRequestsFailure('x', 'TOO_MANY_REQUESTS')),
      'You asked for too many summaries. Try again later.',
    );
    expect(jobSummaryErrorText(const ServerFailure('Job not found.')), 'Job not found.');
  });
}
