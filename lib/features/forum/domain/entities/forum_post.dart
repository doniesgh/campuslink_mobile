enum PostCategory { carpool, lostFound, idea }

/// A post in one of the forum sections (covoiturage, lost & found, ideas).
class ForumPost {
  const ForumPost({
    required this.id,
    required this.authorName,
    required this.authorInfo,
    required this.category,
    required this.body,
    required this.postedAt,
    required this.tag,
    this.place,
    this.upvotes = 0,
    this.comments = 0,
    this.status,
  });

  final String id;
  final String authorName;

  /// Year and program, e.g. "5A - Informatique".
  final String authorInfo;
  final PostCategory category;
  final String body;
  final DateTime postedAt;

  /// Short badge text: "2 places", "Trouvé", "Proposition".
  final String tag;

  /// Route or location shown under the post ("Passage → Ghazela").
  final String? place;
  final int upvotes;
  final int comments;

  /// Moderation status of an idea, e.g. "En examen BDE".
  final String? status;
}
