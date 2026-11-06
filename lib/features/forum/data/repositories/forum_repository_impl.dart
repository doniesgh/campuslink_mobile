import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/forum_post.dart';
import '../../domain/entities/lost_item.dart';
import '../../domain/repositories/forum_repository.dart';
import '../models/forum_models.dart';

/// Real implementation talking to the Node.js API (/api/forum).
class ForumRepositoryImpl implements ForumRepository {
  const ForumRepositoryImpl(this._dio);
  final Dio _dio;

  List<Map<String, dynamic>> _list(Response<dynamic> r) =>
      (r.data as List<dynamic>).cast<Map<String, dynamic>>();

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
}
