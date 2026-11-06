import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/repositories/forum_repository_impl.dart';
import '../../data/repositories/mock_forum_repository.dart';
import '../../domain/entities/forum_post.dart';
import '../../domain/entities/lost_item.dart';
import '../../domain/repositories/forum_repository.dart';

/// The API (/api/forum), or in-memory demo data when USE_MOCK=true.
final forumRepositoryProvider = Provider<ForumRepository>((ref) {
  return Env.useMock ? MockForumRepository() : ForumRepositoryImpl(ref.watch(dioProvider));
});

final highlightsProvider = FutureProvider.autoDispose<List<ForumPost>>(
  (ref) async => (await ref.watch(forumRepositoryProvider).getHighlights()).unwrap(),
);

/// Lost & Found board of the forum, newest first.
final lostItemsProvider = FutureProvider.autoDispose<List<LostItem>>(
  (ref) async => (await ref.watch(forumRepositoryProvider).getLostItems()).unwrap(),
);
