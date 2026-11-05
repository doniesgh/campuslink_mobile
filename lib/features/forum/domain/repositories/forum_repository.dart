import '../../../../core/error/result.dart';
import '../entities/forum_post.dart';

abstract interface class ForumRepository {
  /// Latest posts across all sections, newest first (Home "Campus Highlights").
  Future<Result<List<ForumPost>>> getHighlights();
}
