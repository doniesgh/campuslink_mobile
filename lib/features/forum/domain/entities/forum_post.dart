import 'lost_item.dart' show foldForSearch;

enum PostCategory { carpool, lostFound, idea }

/// Vote count of an idea and whether the signed-in student voted for it.
typedef IdeaUpvote = ({int upvotes, bool isUpvotedByMe});

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
    this.isUpvotedByMe = false,
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

  /// Whether the signed-in student upvoted this idea (always false for other posts).
  final bool isUpvotedByMe;

  /// [upvotes] and [isUpvotedByMe] together.
  IdeaUpvote get upvote => (upvotes: upvotes, isUpvotedByMe: isUpvotedByMe);

  /// This post with another vote count and state (after an upvote).
  ForumPost withUpvote(IdeaUpvote upvote) => ForumPost(
        id: id,
        authorName: authorName,
        authorInfo: authorInfo,
        category: category,
        body: body,
        postedAt: postedAt,
        tag: tag,
        place: place,
        upvotes: upvote.upvotes,
        comments: comments,
        status: status,
        isUpvotedByMe: upvote.isUpvotedByMe,
      );

  /// Case- and accent-insensitive search on the text, badge, author and status.
  bool matches(String query) {
    final q = foldForSearch(query.trim());
    if (q.isEmpty) return true;
    return [body, tag, authorName, status ?? '']
        .any((field) => foldForSearch(field).contains(q));
  }
}
