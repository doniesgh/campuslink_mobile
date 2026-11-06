import '../../../../core/error/result.dart';
import '../entities/forum_post.dart';
import '../entities/lost_item.dart';
import '../entities/lost_item_draft.dart';

abstract interface class ForumRepository {
  /// Latest posts across all sections, newest first (Home "Campus Highlights").
  /// Ideas carry the student's own vote ([ForumPost.isUpvotedByMe]).
  Future<Result<List<ForumPost>>> getHighlights();

  /// Lost & Found board, newest first.
  Future<Result<List<LostItem>>> getLostItems();

  /// Publishes a lost or found notice by the signed-in student. Returns it as
  /// the board lists it: the server sets the reporter, the date and the
  /// "LF-412" reference. A refused draft is a ValidationFailure with a French
  /// message.
  Future<Result<LostItem>> publishLostItem(LostItemDraft draft);

  /// Sends a claim / "I found it" / serial-number check for [itemId] to the
  /// campus security desk. [proof] is the distinctive detail typed by the student.
  Future<Result<void>> sendLostItemRequest({required String itemId, required String proof});

  /// Ideas of the forum, most upvoted first, then newest.
  Future<Result<List<ForumPost>>> getIdeas();

  /// Publishes an idea by the signed-in student. [tag] is its theme badge
  /// ("Proposition" when null or blank). A refused idea is a
  /// ValidationFailure with a French message.
  Future<Result<ForumPost>> publishIdea({required String body, String? tag});

  /// Adds the student's upvote to idea [id], or takes it back. Returns the
  /// new count and state. An idea that no longer exists is a ServerFailure.
  Future<Result<IdeaUpvote>> toggleIdeaUpvote(String id);
}
