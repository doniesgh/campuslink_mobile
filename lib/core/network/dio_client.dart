import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../storage/secure_storage.dart';
import 'interceptors/auth_interceptor.dart';

/// Builds the app-wide Dio instance.
abstract final class DioClient {
  static Dio create({
    required SecureStorage storage,
    VoidCallback? onSessionExpired,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
      ),
    );

    dio.interceptors.add(
      AuthInterceptor(
        storage: storage,
        dio: dio,
        onSessionExpired: onSessionExpired,
      ),
    );
    if (!Env.isProd) {
      dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
    }
    return dio;
  }
}
