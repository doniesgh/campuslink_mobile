import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/repositories/forum_repository_impl.dart';
import '../../data/repositories/mock_forum_repository.dart';
import '../../domain/entities/forum_post.dart';
import '../../domain/entities/lost_item.dart';
import '../../domain/entities/lost_item_match.dart';
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

/// "Correspondances possibles" of the notice with this id, best first.
final lostItemMatchesProvider = FutureProvider.autoDispose.family<LostItemMatches, String>(
  (ref, id) async => (await ref.watch(forumRepositoryProvider).getLostItemMatches(id)).unwrap(),
);

/// Ideas of the forum, most upvoted first, then newest. An idea published
/// from the app is shown first until the next reload.
///
/// The vote counts here are the fetched ones: read them through
/// [ideaUpvotesProvider], which adds the votes of this session.
final ideasProvider =
    AsyncNotifierProvider.autoDispose<IdeasNotifier, List<ForumPost>>(IdeasNotifier.new);

class IdeasNotifier extends AutoDisposeAsyncNotifier<List<ForumPost>> {
  @override
  Future<List<ForumPost>> build() async =>
      (await ref.watch(forumRepositoryProvider).getIdeas()).unwrap();

  /// Reloads the list (pull to refresh). Errors are exposed through the state.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // The section shows the error state.
    }
  }

  /// Publishes an idea. On success it is put first in the list, and Home's
  /// highlights reload to show it.
  Future<Result<ForumPost>> publish({required String body, String? tag}) async {
    // Keep the list while the request runs, even if the section closes.
    final link = ref.keepAlive();
    try {
      final result = await ref.read(forumRepositoryProvider).publishIdea(body: body, tag: tag);
      if (result case Success(value: final idea)) {
        final ideas = state.valueOrNull;
        if (ideas != null && !ideas.any((i) => i.id == idea.id)) {
          state = AsyncData([idea, ...ideas]);
        }
        ref.invalidate(highlightsProvider);
      }
      return result;
    } finally {
      link.close();
    }
  }
}

/// Idea upvotes made during this session, by idea id. Shared by every screen
/// that shows ideas (Forum "Ideas", Home "Campus Highlights"), so a vote
/// shows the same count and state everywhere without reloading.
///
/// Read an idea's state with `ref.watch(ideaUpvotesProvider)[post.id] ??
/// post.upvote`, and vote with
/// `ref.read(ideaUpvotesProvider.notifier).toggle(post)`.
final ideaUpvotesProvider =
    NotifierProvider<IdeaUpvotesNotifier, Map<String, IdeaUpvote>>(IdeaUpvotesNotifier.new);

class IdeaUpvotesNotifier extends Notifier<Map<String, IdeaUpvote>> {
  /// Ideas whose toggle is waiting for the API.
  final _pending = <String>{};

  @override
  Map<String, IdeaUpvote> build() {
    // Votes belong to one student: forget them when another one signs in.
    ref.watch(currentUserIdProvider);
    return const {};
  }

  /// [post]'s count and state, with this session's votes applied.
  IdeaUpvote of(ForumPost post) => state[post.id] ?? post.upvote;

  /// Adds or takes back the student's vote on [post]. Optimistic: the count
  /// changes at once, then takes the API's value; on failure it goes back to
  /// what it was and the [Failure] is returned (null otherwise). A tap while
  /// the previous one is still being sent is ignored.
  Future<Failure?> toggle(ForumPost post) async {
    if (!_pending.add(post.id)) return null;
    final before = of(post);
    _set(post.id, (
      upvotes: before.upvotes + (before.isUpvotedByMe ? -1 : 1),
      isUpvotedByMe: !before.isUpvotedByMe,
    ));
    try {
      final result = await ref.read(forumRepositoryProvider).toggleIdeaUpvote(post.id);
      return result.when<Failure?>(
        success: (upvote) {
          _set(post.id, upvote);
          return null;
        },
        failure: (failure) {
          _set(post.id, before);
          return failure;
        },
      );
    } finally {
      _pending.remove(post.id);
    }
  }

  void _set(String id, IdeaUpvote upvote) => state = {...state, id: upvote};
}
