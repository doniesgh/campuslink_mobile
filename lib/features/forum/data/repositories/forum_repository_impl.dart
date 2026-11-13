import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/forum_post.dart';
import '../../domain/entities/lost_item.dart';
import '../../domain/entities/lost_item_draft.dart';
import '../../domain/repositories/forum_repository.dart';
import '../models/forum_models.dart';

/// Real implementation talking to the Node.js API (/api/forum).
class ForumRepositoryImpl implements ForumRepository {
  const ForumRepositoryImpl(this._dio);
  final Dio _dio;

  List<Map<String, dynamic>> _list(Response<dynamic> r) =>
      (r.data as List<dynamic>).cast<Map<String, dynamic>>();

  Map<String, dynamic> _object(Response<dynamic> r) => r.data as Map<String, dynamic>;

  @override
  Future<Result<List<ForumPost>>> getHighlights() => guard<List<ForumPost>>(() async {
        final r = await _dio.get<dynamic>(ApiEndpoints.forumHighlights);
        return [for (final json in _list(r)) ForumPostModel.fromJson(json)];
      });

  @override
  Future<Result<List<LostItem>>> getLostItems() => guard<List<LostItem>>(() async {
        final r = await _dio.get<dynamic>(ApiEndpoints.lostItems);
        return [for (final json in _list(r)) LostItemModel.fromJson(json)];
      });

  /// 201 with the created item. A 422 (refused draft) becomes a
  /// ValidationFailure with the API's French message.
  @override
  Future<Result<LostItem>> publishLostItem(LostItemDraft draft) => guard<LostItem>(() async {
        final r = await _dio.post<dynamic>(ApiEndpoints.lostItems, data: draft.toJson());
        return LostItemModel.fromJson(_object(r));
      });

  /// 422 (blank proof) becomes a ValidationFailure; 404 (item gone) and
  /// 409 (already sent) a ServerFailure, each with the API's message.
  @override
  Future<Result<void>> sendLostItemRequest({required String itemId, required String proof}) =>
      guard<void>(() async {
        await _dio.post<dynamic>(
          ApiEndpoints.lostItemRequests(Uri.encodeComponent(itemId)),
          data: {'proof': proof},
        );
      });

  @override
  Future<Result<List<ForumPost>>> getIdeas() => guard<List<ForumPost>>(() async {
        final r = await _dio.get<dynamic>(ApiEndpoints.ideas);
        return [for (final json in _list(r)) ForumPostModel.fromJson(json)];
      });

  /// 201 with the created post. A 422 becomes a ValidationFailure.
  @override
  Future<Result<ForumPost>> publishIdea({required String body, String? tag}) =>
      guard<ForumPost>(() async {
        final theme = tag?.trim() ?? '';
        final r = await _dio.post<dynamic>(
          ApiEndpoints.ideas,
          data: {'body': body.trim(), if (theme.isNotEmpty) 'tag': theme},
        );
        return ForumPostModel.fromJson(_object(r));
      });

  /// A 404 (idea gone) becomes a ServerFailure with the API's message.
  @override
  Future<Result<IdeaUpvote>> toggleIdeaUpvote(String id) => guard<IdeaUpvote>(() async {
        final r = await _dio.post<dynamic>(ApiEndpoints.ideaUpvote(Uri.encodeComponent(id)));
        return ideaUpvoteFromJson(_object(r));
      });

  /// 204 on success; 403/404 from the server become a ServerFailure.
  @override
  Future<Result<void>> deleteIdea(String id) => guard<void>(() async {
        await _dio.delete<dynamic>(ApiEndpoints.idea(Uri.encodeComponent(id)));
      });

  /// 204 on success; 403/404 from the server become a ServerFailure.
  @override
  Future<Result<void>> deleteLostItem(String id) => guard<void>(() async {
        await _dio.delete<dynamic>(ApiEndpoints.lostItem(Uri.encodeComponent(id)));
      });
}
