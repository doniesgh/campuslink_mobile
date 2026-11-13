import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/forum_post.dart';
import '../../domain/entities/lost_item.dart';
import '../../domain/entities/lost_item_draft.dart';
import '../../domain/forum_rules.dart';
import '../../domain/repositories/forum_repository.dart';

/// In-memory demo data, used when USE_MOCK=true (the same content as the
/// backend seed). What the student publishes and upvotes is kept in memory
/// for the life of this object, and checked with the API's rules.
class MockForumRepository implements ForumRepository {
  static const _latency = Duration(milliseconds: 450);

  /// The demo student (MockAuthRemoteDataSource signs in as Dony Mansour,
  /// whose seeded profile is 4BI - Software Eng.).
  static const _studentName = 'Dony Mansour';
  static const _studentInfo = '4BI - Software Eng.';

  static const _ideaGone = "Cette idée n'existe plus.";

  /// Published during this session, newest first.
  final _publishedItems = <LostItem>[];
  final _publishedIdeas = <ForumPost>[];

  /// Ideas the student upvoted (one vote each, on top of the seeded count).
  final _upvotedIdeaIds = <String>{};
  var _nextReference = 412;
  var _nextId = 1;

  @override
  Future<Result<List<ForumPost>>> getHighlights() async {
    await Future<void>.delayed(_latency);
    final posts = [..._publishedIdeas, ..._seedPosts(DateTime.now())]
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return Success([for (final post in posts) _withMyVote(post)]);
  }

  @override
  Future<Result<List<ForumPost>>> getIdeas() async {
    await Future<void>.delayed(_latency);
    final ideas = [for (final idea in _allIdeas(DateTime.now())) _withMyVote(idea)]
      ..sort((a, b) {
        final byVotes = b.upvotes.compareTo(a.upvotes);
        return byVotes != 0 ? byVotes : b.postedAt.compareTo(a.postedAt);
      });
    return Success(ideas);
  }

  @override
  Future<Result<ForumPost>> publishIdea({required String body, String? tag}) async {
    await Future<void>.delayed(_latency);
    final error = ideaBodyError(body) ?? ideaTagError(tag);
    if (error != null) return Err(ValidationFailure(error));

    final theme = tag?.trim() ?? '';
    final idea = ForumPost(
      id: 'idea-mock-${_nextId++}',
      authorName: _studentName,
      authorInfo: _studentInfo,
      category: PostCategory.idea,
      tag: theme.isEmpty ? defaultIdeaTag : theme,
      body: body.trim(),
      postedAt: DateTime.now(),
      isMine: true,
    );
    _publishedIdeas.insert(0, idea);
    return Success(idea);
  }

  @override
  Future<Result<IdeaUpvote>> toggleIdeaUpvote(String id) async {
    await Future<void>.delayed(_latency);
    final ideas = _allIdeas(DateTime.now()).where((idea) => idea.id == id);
    if (ideas.isEmpty) return const Err(ServerFailure(_ideaGone));
    if (!_upvotedIdeaIds.remove(id)) _upvotedIdeaIds.add(id);
    return Success(_withMyVote(ideas.first).upvote);
  }

  List<ForumPost> _allIdeas(DateTime now) => [
        ..._publishedIdeas,
        ..._seedPosts(now).where((post) => post.category == PostCategory.idea),
      ];

  /// [post] with the student's vote added to its count.
  ForumPost _withMyVote(ForumPost post) {
    if (!_upvotedIdeaIds.contains(post.id)) return post;
    return post.withUpvote((upvotes: post.upvotes + 1, isUpvotedByMe: true));
  }

  static List<ForumPost> _seedPosts(DateTime now) => [
      ForumPost(
        id: 'post-1',
        authorName: 'Sarra K.',
        authorInfo: '5A - Informatique',
        category: PostCategory.carpool,
        tag: '2 places',
        body: 'Départ à 13h15 : Passage → ESPRIT Ghazela. Reste 2 places libres, '
            'contactez-moi en privé si intéressé(e) ! 🚗✨',
        place: 'Passage → Ghazela',
        postedAt: now.subtract(const Duration(minutes: 12)),
      ),
      ForumPost(
        id: 'post-2',
        authorName: 'Youssef M.',
        authorInfo: '3B - Télécom',
        category: PostCategory.lostFound,
        tag: 'Trouvé',
        body: 'Calculatrice graphique TI-84 Plus oubliée sur une table au Bloc C '
            "(salle C12). Déposée à l'accueil du bloc !",
        place: 'Bloc C · Accueil',
        postedAt: now.subtract(const Duration(minutes: 45)),
      ),
      ForumPost(
        id: 'post-3',
        authorName: 'Amina T.',
        authorInfo: '4A - Data Science',
        category: PostCategory.idea,
        tag: 'Proposition',
        body: 'Installation de bornes de recharge rapide supplémentaires près des '
            'espaces calmes de la bibliothèque centrale ? 💡',
        upvotes: 42,
        comments: 8,
        status: 'En examen BDE',
        postedAt: now.subtract(const Duration(hours: 2)),
      ),
    ];

  @override
  Future<Result<List<LostItem>>> getLostItems() async {
    await Future<void>.delayed(_latency);
    return Success(List<LostItem>.unmodifiable(_allLostItems(DateTime.now())));
  }

  List<LostItem> _allLostItems(DateTime now) =>
      [..._publishedItems, ..._seedLostItems(now)]
        ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));

  @override
  Future<Result<LostItem>> publishLostItem(LostItemDraft draft) async {
    await Future<void>.delayed(_latency);
    final error = lostItemDraftError(draft);
    if (error != null) return Err(ValidationFailure(error));

    String? text(String? value) {
      final trimmed = value?.trim() ?? '';
      return trimmed.isEmpty ? null : trimmed;
    }

    final item = LostItem(
      id: 'lf-mock-${_nextId++}',
      kind: draft.kind,
      title: draft.title.trim(),
      category: draft.category,
      zone: draft.zone.trim(),
      location: draft.location.trim(),
      place: draft.place,
      reporterName: _studentName,
      reportedAt: DateTime.now(),
      reference: 'LF-${_nextReference++}',
      distinctiveDetail: text(draft.distinctiveDetail),
      reward: draft.isLost ? text(draft.reward) : null,
      isUrgent: draft.isLost && draft.isUrgent,
      dropOffNote: draft.isLost ? null : text(draft.dropOffNote),
      pickupDesk: draft.isLost ? null : text(draft.pickupDesk),
      isMine: true,
    );
    _publishedItems.insert(0, item);
    return Success(item);
  }

  @override
  Future<Result<void>> sendLostItemRequest({
    required String itemId,
    required String proof,
  }) async {
    await Future<void>.delayed(_latency);
    if (!_allLostItems(DateTime.now()).any((item) => item.id == itemId)) {
      return const Err(ServerFailure('This item is no longer listed.'));
    }
    if (proof.trim().isEmpty) {
      return const Err(ValidationFailure('Please add a detail that identifies the item.'));
    }
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteIdea(String id) async {
    await Future<void>.delayed(_latency);
    final idx = _publishedIdeas.indexWhere((p) => p.id == id);
    if (idx == -1) return const Err(ServerFailure("Cette idée n'existe plus."));
    _publishedIdeas.removeAt(idx);
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteLostItem(String id) async {
    await Future<void>.delayed(_latency);
    final idx = _publishedItems.indexWhere((item) => item.id == id);
    if (idx == -1) return const Err(ServerFailure('This item is no longer listed.'));
    _publishedItems.removeAt(idx);
    return const Success(null);
  }

  static List<LostItem> _seedLostItems(DateTime now) {
    DateTime hoursAgo(int h) => DateTime(now.year, now.month, now.day, now.hour - h);
    DateTime daysAgo(int d, int h, [int m = 0]) =>
        DateTime(now.year, now.month, now.day - d, h, m);

    return [
      LostItem(
        id: 'lf-409',
        kind: LostItemKind.found,
        title: 'Calculatrice TI-84 Plus CE',
        category: LostItemCategory.calculator,
        zone: 'Bloc C',
        location: 'Salle C12 (Ghazela)',
        place: LostItemPlace.classroom,
        reporterName: 'Youssef M.',
        reportedAt: now.subtract(const Duration(minutes: 45)),
        reference: 'TF-409',
        photoCount: 1,
        dropOffNote: "Déposé à l'accueil Bloc C",
        pickupDesk: 'Accueil Bloc C - Salle C12',
      ),
      LostItem(
        id: 'lf-411',
        kind: LostItemKind.found,
        title: 'Sony WH-1000XM4 (Étui)',
        category: LostItemCategory.audio,
        zone: 'Bibliothèque',
        location: 'Bibliothèque centrale (Étage 1)',
        place: LostItemPlace.library,
        reporterName: 'Bibliothèque Staff',
        reporterIsStaff: true,
        reportedAt: hoursAgo(3),
        photoCount: 2,
        pickupDesk: 'Bibliothèque centrale - Guichet Prêt',
        isSerialHidden: true,
      ),
      LostItem(
        id: 'lf-406',
        kind: LostItemKind.lost,
        title: 'Clés Peugeot + Porte-clé ESPRIT',
        category: LostItemCategory.keys,
        zone: 'Parking',
        location: 'Parking Amphi A (Ghazela)',
        place: LostItemPlace.parking,
        reporterName: 'Meriem B.',
        reportedAt: daysAgo(1, 16, 30),
        photoCount: 1,
        isUrgent: true,
        reward: 'Café offert ☕',
        distinctiveDetail: 'Boîtier 3 boutons noir',
      ),
      LostItem(
        id: 'lf-404',
        kind: LostItemKind.lost,
        title: "Carte d'étudiant ESPRIT",
        category: LostItemCategory.card,
        zone: 'Bloc E',
        location: 'Hall Bloc E (Charguia)',
        place: LostItemPlace.other,
        reporterName: 'Rami T.',
        reportedAt: daysAgo(1, 9, 45),
        distinctiveDetail: 'Pochette transparente bleue',
      ),
      LostItem(
        id: 'lf-402',
        kind: LostItemKind.found,
        title: 'Gourde isotherme bleue',
        category: LostItemCategory.bottle,
        zone: 'Cafétéria',
        location: 'Cafétéria centrale (Ghazela)',
        place: LostItemPlace.cafeteria,
        reporterName: 'Agent de sécurité',
        reporterIsStaff: true,
        reportedAt: daysAgo(2, 13),
        reference: 'TF-402',
        photoCount: 1,
        dropOffNote: "Déposé à l'accueil Bloc C",
        pickupDesk: 'Accueil Bloc C',
      ),
      LostItem(
        id: 'lf-398',
        kind: LostItemKind.lost,
        title: 'Sac à dos Eastpak noir',
        category: LostItemCategory.bag,
        zone: 'Bloc H',
        location: 'Salle H204 (Ghazela)',
        place: LostItemPlace.classroom,
        reporterName: 'Ines K.',
        reportedAt: daysAgo(3, 17),
        distinctiveDetail: 'Porte-clé drapeau Tunisie',
      ),
    ]..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
  }
}
