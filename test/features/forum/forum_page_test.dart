import 'package:campuspulse/core/providers/clock_provider.dart';
import 'package:campuspulse/core/router/route_names.dart';
import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/auth/domain/entities/user.dart';
import 'package:campuspulse/features/auth/presentation/providers/auth_controller.dart';
import 'package:campuspulse/features/carpooling/domain/entities/ride.dart';
import 'package:campuspulse/features/carpooling/presentation/providers/carpool_providers.dart';
import 'package:campuspulse/features/forum/data/repositories/mock_forum_repository.dart';
import 'package:campuspulse/features/forum/presentation/pages/forum_page.dart';
import 'package:campuspulse/features/forum/presentation/providers/forum_providers.dart';
import 'package:campuspulse/features/forum/presentation/widgets/idea_card.dart';
import 'package:campuspulse/features/forum/presentation/widgets/lost_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _SignedIn extends AuthController {
  @override
  Future<User?> build() async =>
      const User(id: 'u1', email: 'dony@esprit.tn', displayName: 'Dony Mansour');
}

ThemeData _theme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary)
          .copyWith(secondary: AppColors.secondary, onSecondary: AppColors.onSecondary),
    );

/// The forum tab on [section], with the in-memory demo data, and a stub for
/// the "Proposer un trajet" page. The Covoiturage section (another feature,
/// tested on its own) gets no rides.
Future<void> _pumpForum(WidgetTester tester, ForumSection section) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: RoutePaths.forum,
    routes: [
      GoRoute(path: RoutePaths.forum, builder: (_, __) => const ForumPage()),
      GoRoute(
        path: RoutePaths.newRide,
        builder: (_, __) => const Scaffold(body: Text('New ride page')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_SignedIn.new),
        clockProvider.overrideWith((ref) => Stream.value(DateTime.now())),
        forumRepositoryProvider.overrideWith((ref) => MockForumRepository()),
        forumSectionProvider.overrideWith((ref) => section),
        ridesProvider.overrideWith((ref) async => const <Ride>[]),
      ],
      child: MaterialApp.router(theme: _theme(), routerConfig: router),
    ),
  );
  await _waitForMock(tester);
}

/// Lets the mock repositories (450-500 ms) answer.
Future<void> _waitForMock(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

/// Lets the snackbar time out.
Future<void> _dismissSnack(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
      matching: find.byType(TextField),
    );

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets('"Proposer un trajet +" opens the new ride form', (tester) async {
    await _pumpForum(tester, ForumSection.carpooling);

    await tester.tap(find.text('Proposer un trajet +'));
    await tester.pumpAndSettle();

    expect(find.text('New ride page'), findsOneWidget);
  });

  testWidgets('"Publier une annonce" publishes a notice first on the board', (tester) async {
    await _pumpForum(tester, ForumSection.lostFound);
    expect(find.byType(LostItemCard), findsWidgets);

    await tester.tap(find.text('Publier une annonce'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Objet'), 'AirPods Pro (boîtier blanc)');
    await _tap(tester, find.text('Audio'));
    await tester.enterText(_field('Zone'), 'Bloc E');
    await tester.enterText(_field('Lieu précis'), 'Salle E204 (Charguia)');
    await _tap(tester, find.text('Salle de cours'));
    await _tap(tester, find.text("Publier l'annonce"));
    await _waitForMock(tester); // publish
    await tester.pumpAndSettle(); // sheet closes
    await _waitForMock(tester); // the board reloads

    expect(find.text('Annonce publiée : la communauté ESPRIT est prévenue !'), findsOneWidget);
    final first = tester.widget<LostItemCard>(find.byType(LostItemCard).first);
    expect(first.item.title, 'AirPods Pro (boîtier blanc)');
    expect(first.item.reference, 'LF-412');
    await _dismissSnack(tester);
  });

  testWidgets('Ideas lists the ideas and "Proposer une idée" adds one', (tester) async {
    await _pumpForum(tester, ForumSection.ideas);

    expect(find.text('Idées du campus'), findsOneWidget);
    expect(find.byType(IdeaCard), findsOneWidget);

    await tester.tap(find.text('Proposer une idée'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Des annales corrigées sur le Drive');
    await tester.pump();
    await _tap(tester, find.text('Publier mon idée'));
    await _waitForMock(tester);
    await tester.pumpAndSettle();

    expect(find.text('Idée publiée ! Les étudiants peuvent maintenant voter.'), findsOneWidget);
    final cards = tester.widgetList<IdeaCard>(find.byType(IdeaCard)).toList();
    expect([for (final c in cards) c.idea.body].first, 'Des annales corrigées sur le Drive');
    expect(cards.first.idea.authorName, 'Dony Mansour');
    await _dismissSnack(tester);
  });

  testWidgets('Experiences is still coming soon, without a button', (tester) async {
    await _pumpForum(tester, ForumSection.experiences);

    expect(find.text('Experiences is coming soon.'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
