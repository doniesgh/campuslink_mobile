import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/audit_entry.dart';
import '../../domain/entities/managed_user.dart';
import '../../domain/entities/user_import.dart';
import '../../domain/import_assist.dart';
import '../../domain/repositories/admin_repository.dart';
import '../models/admin_models.dart';

/// Real implementation talking to the Node.js API (backend/src/modules/admin).
/// The server's messages ("You can't delete your own account.") come back
/// as the failures' messages and are shown as-is.
class AdminRepositoryImpl implements AdminRepository {
  const AdminRepositoryImpl(this._dio);
  final Dio _dio;

  Map<String, dynamic> _map(Response<dynamic> r) => r.data as Map<String, dynamic>;

  @override
  Future<Result<UserPage>> getUsers({
    String query = '',
    UserRole? role,
    int page = 1,
    int limit = 20,
  }) =>
      guard(() async {
        final q = query.trim();
        final r = await _dio.get<dynamic>(
          ApiEndpoints.adminUsers,
          queryParameters: {
            if (q.isNotEmpty) 'q': q,
            if (role != null) 'role': role.name,
            'page': page,
            'limit': limit,
          },
        );
        return userPageFromJson(_map(r));
      });

  @override
  Future<Result<UserStats>> getStats() => guard(() async {
        return userStatsFromJson(_map(await _dio.get<dynamic>(ApiEndpoints.adminUserStats)));
      });

  @override
  Future<Result<ManagedUser>> getUser(String id) => guard(() async {
        return managedUserFromJson(_map(await _dio.get<dynamic>(ApiEndpoints.adminUser(id))));
      });

  @override
  Future<Result<ManagedUser>> createUser(NewUser user) => guard(() async {
        final r = await _dio.post<dynamic>(ApiEndpoints.adminUsers, data: newUserToJson(user));
        return managedUserFromJson(_map(r));
      });

  @override
  Future<Result<ManagedUser>> updateUser(String id, UserChanges changes) => guard(() async {
        final r = await _dio.patch<dynamic>(
          ApiEndpoints.adminUser(id),
          data: userChangesToJson(changes),
        );
        return managedUserFromJson(_map(r));
      });

  @override
  Future<Result<void>> deleteUser(String id) => guard(() async {
        await _dio.delete<dynamic>(ApiEndpoints.adminUser(id));
      });

  @override
  Future<Result<ImportCheck>> checkImport(List<ImportRow> rows) => guard(() async {
        final r = await _dio.post<dynamic>(
          ApiEndpoints.adminUserImport,
          data: {'dryRun': true, 'users': rows.map(importRowToJson).toList()},
        );
        return importCheckFromJson(_map(r));
      });

  /// A 422 listing problems is an answer, not an error: the screen shows
  /// them on their lines.
  @override
  Future<Result<ImportOutcome>> importUsers(List<ImportRow> rows) => guard(() async {
        try {
          final r = await _dio.post<dynamic>(
            ApiEndpoints.adminUserImport,
            data: {'dryRun': false, 'users': rows.map(importRowToJson).toList()},
          );
          return ImportCreated([
            for (final u in _map(r)['created'] as List<dynamic>)
              managedUserFromJson(u as Map<String, dynamic>),
          ]);
        } on DioException catch (e) {
          final body = e.response?.data;
          if (e.response?.statusCode == 422 && body is Map && body['problems'] is List) {
            return ImportRefused(
              body['message']?.toString() ?? 'The file has errors, so nothing was imported.',
              importProblemsFromJson(body['problems']),
            );
          }
          rethrow;
        }
      });

  @override
  Future<Result<ImportAssistStatus>> getImportAssistStatus() => guard(() async {
        return importAssistStatusFromJson(
          _map(await _dio.get<dynamic>(ApiEndpoints.adminUserImportAssist)),
        );
      });

  /// The AI can take longer than the usual 20 s (the server stops at 45 s).
  @override
  Future<Result<ImportAssistAnswer>> assistImport(AssistRequest request) => guard(() async {
        final r = await _dio.post<dynamic>(
          ApiEndpoints.adminUserImportAssist,
          data: assistRequestToJson(request),
          options: Options(receiveTimeout: const Duration(seconds: 60)),
        );
        return importAssistAnswerFromJson(_map(r));
      });

  @override
  Future<Result<AuditPage>> getAudit({String? action, int page = 1, int limit = 30}) =>
      guard(() async {
        final r = await _dio.get<dynamic>(
          ApiEndpoints.adminAudit,
          queryParameters: {
            if (action != null) 'action': action,
            'page': page,
            'limit': limit,
          },
        );
        return auditPageFromJson(_map(r));
      });

  @override
  Future<Result<List<String>>> getAuditActions() => guard(() async {
        final r = await _dio.get<dynamic>(ApiEndpoints.adminAuditActions);
        return [for (final a in r.data as List<dynamic>) a as String];
      });
}
