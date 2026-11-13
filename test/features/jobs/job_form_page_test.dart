import 'package:campuspulse/core/router/route_names.dart';
import 'package:campuspulse/features/jobs/presentation/pages/job_form_page.dart';
import 'package:campuspulse/features/jobs/presentation/providers/job_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_job_repository.dart';

/// The form at [location], with the offer detail as a placeholder page.
Future<FakeJobRepository> _pumpForm(WidgetTester tester, String location) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = FakeJobRepository();
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: RoutePaths.jobs,
        builder: (_, __) => const Text('jobs list'),
        routes: [
          GoRoute(path: 'new', builder: (_, __) => const JobFormPage()),
          GoRoute(
            path: ':jobId',
            builder: (_, state) => Scaffold(body: Text('detail ${state.pathParameters['jobId']}')),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, state) => JobFormPage(jobId: state.pathParameters['jobId']),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [jobRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Finder _field(String name) => find.byKey(ValueKey('job-form-$name'));

void main() {
  testWidgets('refuses an empty or invalid offer without calling the API', (tester) async {
    final repository = await _pumpForm(tester, RoutePaths.newJob);
    expect(find.text('New offer'), findsOneWidget);

    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a title.'), findsOneWidget);
    expect(find.text('The company name needs at least 2 characters.'), findsOneWidget);
    expect(find.text('Enter a description.'), findsOneWidget);
    expect(find.text('Check the highlighted fields.'), findsOneWidget);
    // Let the snackbar go: it covers the Publish button.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.enterText(_field('title'), 'Flutter Mobile Intern');
    await tester.enterText(_field('company'), 'Medina Soft');
    await tester.enterText(_field('description'), 'Too short.');
    await tester.enterText(_field('duration'), '50');
    await tester.enterText(_field('stipend'), 'a lot');
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a title.'), findsNothing);
    expect(find.text('The description needs at least 20 characters.'), findsOneWidget);
    expect(find.text('The duration is a whole number of months, from 1 to 36.'), findsOneWidget);
    expect(find.text('The stipend is a whole number of TND, from 0 to 100000.'), findsOneWidget);
    expect(repository.created, isEmpty);
  });

  testWidgets('publishes a valid offer, then opens it', (tester) async {
    final repository = await _pumpForm(tester, RoutePaths.newJob);

    await tester.enterText(_field('title'), ' Flutter Mobile Intern ');
    await tester.enterText(_field('company'), 'Medina Soft');
    await tester.enterText(_field('description'), 'Build the Flutter app our clients use every day.');
    await tester.enterText(_field('duration'), '6');
    await tester.enterText(_field('skills'), 'Flutter, Dart, , Flutter');
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    final draft = repository.created.single;
    expect(draft.title, 'Flutter Mobile Intern');
    expect(draft.company, 'Medina Soft');
    expect(draft.durationMonths, 6);
    expect(draft.stipendTnd, isNull);
    expect(draft.skills, ['Flutter', 'Dart']);
    expect(draft.tags, isEmpty);
    expect(find.text('detail new-offer'), findsOneWidget);
    expect(find.text('Offer published. Students can see it now.'), findsOneWidget);
  });

  testWidgets('edits an offer: prefilled, saved, back to the detail', (tester) async {
    final repository = await _pumpForm(tester, RoutePaths.editJob(sampleJob.id));

    expect(find.text('Edit offer'), findsOneWidget);
    expect(find.text('Flutter Mobile Intern'), findsOneWidget);
    expect(find.text('Flutter, Dart'), findsOneWidget);

    await tester.enterText(_field('title'), 'Senior Flutter Intern');
    await tester.enterText(_field('duration'), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final (id, draft) = repository.updated.single;
    expect(id, sampleJob.id);
    expect(draft.title, 'Senior Flutter Intern');
    expect(draft.durationMonths, isNull);
    expect(draft.location, 'Lac 1, Tunis');
    expect(find.text('detail offer-1'), findsOneWidget);
  });
}
