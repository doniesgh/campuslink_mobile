import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/student_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../models/student_profile_model.dart';

/// Real implementation talking to the Node.js API.
class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<Result<StudentProfile>> getMyProfile() => guard(() async {
        final r = await _dio.get<Map<String, dynamic>>(ApiEndpoints.profile);
        return StudentProfileModel.fromJson(r.data!).toEntity();
      });
}
