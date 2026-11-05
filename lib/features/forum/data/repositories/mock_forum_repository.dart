import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/forum_post.dart';
import '../../domain/entities/lost_item.dart';
import '../../domain/repositories/forum_repository.dart';

/// In-memory fake. Replace with a Dio-based implementation when the API exists.
class MockForumRepository implements ForumRepository {
  static const _latency = Duration(milliseconds: 450);

  @override
  Future<Result<List<ForumPost>>> getHighlights() async {
    await Future<void>.delayed(_latency);
    final now = DateTime.now();
    return Success([
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
    ]);
  }

  @override
  Future<Result<List<LostItem>>> getLostItems() async {
    await Future<void>.delayed(_latency);
    return Success(List<LostItem>.unmodifiable(_seedLostItems(DateTime.now())));
  }

  @override
  Future<Result<void>> sendLostItemRequest({
    required String itemId,
    required String proof,
  }) async {
    await Future<void>.delayed(_latency);
    // TODO: POST the request to the API once the lost & found endpoints exist.
    if (!_seedLostItems(DateTime.now()).any((item) => item.id == itemId)) {
      return const Err(ServerFailure('This item is no longer listed.'));
    }
    if (proof.trim().isEmpty) {
      return const Err(ValidationFailure('Please add a detail that identifies the item.'));
    }
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
