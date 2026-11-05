import '../../../../core/error/result.dart';
import '../entities/forum_post.dart';
import '../entities/lost_item.dart';

abstract interface class ForumRepository {
  /// Latest posts across all sections, newest first (Home "Campus Highlights").
  Future<Result<List<ForumPost>>> getHighlights();

  /// Lost & Found board, newest first.
  Future<Result<List<LostItem>>> getLostItems();

  /// Sends a claim / "I found it" / serial-number check for [itemId] to the
  /// campus security desk. [proof] is the distinctive detail typed by the student.
  Future<Result<void>> sendLostItemRequest({required String itemId, required String proof});
}
