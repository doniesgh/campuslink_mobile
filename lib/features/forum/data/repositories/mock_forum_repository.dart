import '../../../../core/error/result.dart';
import '../../domain/entities/forum_post.dart';
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
}
