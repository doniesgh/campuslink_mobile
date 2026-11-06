import 'dart:async';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/core/providers/clock_provider.dart';
import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/auth/presentation/providers/auth_controller.dart';
import 'package:campuspulse/features/forum/domain/entities/forum_post.dart';
import 'package:campuspulse/features/forum/domain/repositories/forum_repository.dart';
import 'package:campuspulse/features/forum/presentation/providers/forum_providers.dart';
import 'package:campuspulse/features/forum/presentation/widgets/idea_card.dart';
import 'package:campuspulse/features/forum/presentation/widgets/idea_composer_sheet.dart';
import 'package:campuspulse/features/forum/presentation/widgets/ideas_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 6, 14);

ForumPost _idea(
  String id,
  String body, {
  int upvotes = 0,
  int comments = 0,
  String? status,
  String tag = 'Proposition',
  Duration age = const Duration(hours: 1),
}) =>
    ForumPost(
      id: id,
      authorName: 'Amina T.',
      authorInfo: '4A - Data Science',
      category: PostCategory.idea,
      body: body,
      postedAt: _now.subtract(age),
      tag: tag,
      upvotes: upvotes,
      comments: comments,
      status: status,
    );

final _seeded = [
  _idea(
    'post-3',
    'Installation de bornes de recharge rapide près de la bibliothèque centrale ? 💡',
    upvotes: 42,
    comments: 8,
    status: 'En examen BDE',
  ),
  _idea('idea-2', 'Un distributeur de boissons chaudes au Bloc E', tag: 'Vie de campus'),
];

/// Ideas from memory; the upvote and publish answers can be held back.
class _FakeForumRepository implements ForumRepository {
  _FakeForumRepository([List<ForumPost>? ideas]) : ideas = [...ideas ?? _seeded];

  final List<ForumPost> ideas;
  final upvoteCalls = <String>[];
  final published = <({String body, String? tag})>[];

  /// When set, the next upvote waits for it.
  Completer<Result<IdeaUpvote>>? upvoteReply;

  /// When set, publishing answers with it.
  Result<ForumPost>? publishReply;

  @override
  Future<Result<List<ForumPost>>> getIdeas() async => Success([...ideas]);

  @override
  Future<Result<IdeaUpvote>> toggleIdeaUpvote(String id) {
    upvoteCalls.add(id);
    final reply = upvoteReply;
    if (reply != null) return reply.future;
    final idea = ideas.firstWhere((i) => i.id == id);
    return Future.value(Success((upvotes: idea.upvotes + 1, isUpvotedByMe: true)));
  }

  @override
  Future<Result<ForumPost>> publishIdea({required String body, String? tag}) async {
    published.add((body: body, tag: tag));
    return publishReply ??
        Success(_idea('idea-new', body, tag: tag ?? 'Proposition', age: Duration.zero));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Same colors and button sizing as AppTheme, without Google Fonts.
ThemeData _theme(Brightness brightness) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: brightness)
          .copyWith(secondary: AppColors.secondary, onSecondary: AppColors.onSecondary),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
    );

/// The section with a "Proposer une idée" button, as the forum page shows it.
Future<void> _pump(
  WidgetTester tester,
  _FakeForumRepository repo, {
  String query = '',
  VoidCallback? onClearSearch,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size size = const Size(360, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        forumRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue('student-1'),
        clockProvider.overrideWith((ref) => Stream.value(_now)),
      ],
      child: MaterialApp(
        theme: _theme(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: IdeasSection(query: query, onClearSearch: onClearSearch ?? () {}),
          floatingActionButton: Builder(
            builder: (context) => FloatingActionButton.extended(
              onPressed: () => showIdeaComposerSheet(context),
              label: const Text('Proposer une idée'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Finder _upvoteOf(String ideaId) => find.descendant(
      of: find.byKey(ValueKey(ideaId)),
      matching: find.byType(IdeaUpvoteButton),
    );

IdeaUpvote _shownUpvote(WidgetTester tester, String ideaId) =>
    tester.widget<IdeaUpvoteButton>(_upvoteOf(ideaId)).upvote;

Future<void> _openComposer(WidgetTester tester) async {
  await tester.tap(find.text('Proposer une idée').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists the ideas with their votes, comments and status', (tester) async {
    await _pump(tester, _FakeForumRepository());

    expect(find.text('Idées du campus'), findsOneWidget);
    expect(find.text('2 idées'), findsOneWidget);
    expect(find.textContaining('bornes de recharge'), findsOneWidget);
    expect(find.text('Un distributeur de boissons chaudes au Bloc E'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('8 commentaires'), findsOneWidget);
    expect(find.text('Aucun commentaire'), findsOneWidget);
    expect(find.text('En examen BDE'), findsOneWidget);
    expect(find.text('Vie de campus'), findsOneWidget);
    expect(find.text('4A - Data Science · Aujourd\'hui, 13h'), findsNWidgets(2));
  });

  testWidgets('the forum search filters the ideas', (tester) async {
    await _pump(tester, _FakeForumRepository(), query: 'BOISSONS');

    expect(find.text('Un distributeur de boissons chaudes au Bloc E'), findsOneWidget);
    expect(find.textContaining('bornes de recharge'), findsNothing);
  });

  testWidgets('a search without result offers to reset it', (tester) async {
    var cleared = 0;
    await _pump(tester, _FakeForumRepository(), query: 'parapluie', onClearSearch: () => cleared++);

    expect(find.text('Aucune idée correspondante'), findsOneWidget);
    await tester.tap(find.text('Réinitialiser la recherche'));
    expect(cleared, 1);
  });

  testWidgets('invites to propose the first idea when there is none', (tester) async {
    await _pump(tester, _FakeForumRepository(const []));
    expect(find.text("Aucune idée pour l'instant"), findsOneWidget);
    expect(find.text('0 idées'), findsOneWidget);
  });

  testWidgets('an upvote shows at once, then takes the API value', (tester) async {
    final repo = _FakeForumRepository()..upvoteReply = Completer();
    await _pump(tester, repo);

    await tester.tap(_upvoteOf('post-3'));
    await tester.pump();
    expect(_shownUpvote(tester, 'post-3'), (upvotes: 43, isUpvotedByMe: true));
    expect(find.text('43'), findsOneWidget);

    // A second tap while the first one is being sent is ignored.
    await tester.tap(_upvoteOf('post-3'));
    await tester.pump();
    expect(repo.upvoteCalls, ['post-3']);

    // Another student voted meanwhile: the API's count wins.
    repo.upvoteReply!.complete(const Success((upvotes: 44, isUpvotedByMe: true)));
    await tester.pump();
    expect(_shownUpvote(tester, 'post-3'), (upvotes: 44, isUpvotedByMe: true));
    expect(
      tester.getSemantics(_upvoteOf('post-3')),
      matchesSemantics(
        label: 'Retirer mon vote, 44 votes',
        isButton: true,
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
      ),
    );

    // Taking the vote back.
    repo.upvoteReply = Completer();
    await tester.tap(_upvoteOf('post-3'));
    await tester.pump();
    expect(_shownUpvote(tester, 'post-3'), (upvotes: 43, isUpvotedByMe: false));
    repo.upvoteReply!.complete(const Success((upvotes: 43, isUpvotedByMe: false)));
    await tester.pump();
    expect(_shownUpvote(tester, 'post-3'), (upvotes: 43, isUpvotedByMe: false));
  });

  testWidgets('a refused upvote goes back and shows why', (tester) async {
    final repo = _FakeForumRepository()..upvoteReply = Completer();
    await _pump(tester, repo);

    await tester.tap(_upvoteOf('idea-2'));
    await tester.pump();
    expect(_shownUpvote(tester, 'idea-2'), (upvotes: 1, isUpvotedByMe: true));

    repo.upvoteReply!.complete(const Err(ServerFailure("Cette idée n'existe plus.")));
    await tester.pump();
    expect(_shownUpvote(tester, 'idea-2'), (upvotes: 0, isUpvotedByMe: false));
    expect(find.text("Cette idée n'existe plus."), findsOneWidget);

    // The student can try again.
    repo.upvoteReply = null;
    await tester.tap(_upvoteOf('idea-2'));
    await tester.pump();
    await tester.pump();
    expect(_shownUpvote(tester, 'idea-2'), (upvotes: 1, isUpvotedByMe: true));
  });

  group('the "Proposer une idée" sheet', () {
    testWidgets('publishes the idea with its theme and adds it first', (tester) async {
      final repo = _FakeForumRepository();
      await _pump(tester, repo);
      await _openComposer(tester);

      final publish = find.text('Publier mon idée');
      expect(tester.widget<FilledButton>(find.ancestor(
        of: publish,
        matching: find.byType(FilledButton),
      )).onPressed, isNull); // nothing typed yet

      await tester.tap(find.text('Pédagogie'));
      await tester.enterText(find.byType(TextField), '  Des annales corrigées sur le Drive  ');
      await tester.pump();
      await tester.tap(publish);
      await tester.pumpAndSettle();

      expect(repo.published.single, (body: 'Des annales corrigées sur le Drive', tag: 'Pédagogie'));
      expect(find.text('Publier mon idée'), findsNothing); // closed
      expect(find.text('3 idées'), findsOneWidget);
      final cards = tester.widgetList<IdeaCard>(find.byType(IdeaCard)).toList();
      expect(cards.first.idea.id, 'idea-new');
      expect(find.text('Pédagogie'), findsOneWidget);
    });

    testWidgets('checks the length before sending', (tester) async {
      final repo = _FakeForumRepository();
      await _pump(tester, repo);
      await _openComposer(tester);

      await tester.enterText(find.byType(TextField), 'Wifi ?');
      await tester.pump();
      await tester.tap(find.text('Publier mon idée'));
      await tester.pump();

      expect(find.text('Votre idée est trop courte : 10 caractères minimum.'), findsOneWidget);
      expect(repo.published, isEmpty);
    });

    testWidgets("shows the API's message and stays open", (tester) async {
      final repo = _FakeForumRepository()
        ..publishReply = const Err(ValidationFailure('Votre idée ne doit pas dépasser 500 caractères.'));
      await _pump(tester, repo);
      await _openComposer(tester);

      await tester.enterText(find.byType(TextField), 'Une idée assez longue pour passer');
      await tester.pump();
      await tester.tap(find.text('Publier mon idée'));
      await tester.pumpAndSettle();

      expect(find.text('Votre idée ne doit pas dépasser 500 caractères.'), findsOneWidget);
      expect(find.text('Publier mon idée'), findsOneWidget);
      expect(find.text('2 idées'), findsOneWidget);
    });
  });

  for (final brightness in Brightness.values) {
    testWidgets('fits 360 dp at 1.3x text without overflow ($brightness)', (tester) async {
      await _pump(
        tester,
        _FakeForumRepository([
          ..._seeded,
          _idea(
            'idea-long',
            'Une très longue proposition ' * 12,
            upvotes: 1234,
            comments: 56,
            status: 'Acceptée par la direction des études',
            tag: 'Vie de campus et associations',
          ),
        ]),
        brightness: brightness,
        textScale: 1.3,
        size: const Size(360, 3000),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(IdeaCard), findsNWidgets(3));

      await _openComposer(tester);
      expect(find.text('Thème'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Wifi ?');
      await tester.pump();
      await tester.tap(find.text('Publier mon idée'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
