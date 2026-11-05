import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/mock_forum_repository.dart';
import '../../domain/entities/forum_post.dart';
import '../../domain/repositories/forum_repository.dart';

/// Swap MockForumRepository for the Dio-based implementation when the API is ready.
final forumRepositoryProvider = Provider<ForumRepository>((ref) => MockForumRepository());

final highlightsProvider = FutureProvider.autoDispose<List<ForumPost>>(
  (ref) async => (await ref.watch(forumRepositoryProvider).getHighlights()).unwrap(),
);
