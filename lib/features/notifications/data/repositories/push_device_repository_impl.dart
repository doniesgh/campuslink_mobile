import 'package:dio/dio.dart';

import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/push_message.dart';
import '../../domain/repositories/push_device_repository.dart';

class PushDeviceRepositoryImpl implements PushDeviceRepository {
  const PushDeviceRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<Result<void>> register(String token, PushPlatform platform) => guard(() async {
        await _dio.put<void>(
          ApiEndpoints.pushDevices,
          data: {'token': token, 'platform': platform.name},
        );
      });
}
