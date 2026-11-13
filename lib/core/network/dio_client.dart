import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../storage/secure_storage.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/locale_interceptor.dart';

/// Builds the app-wide Dio instance.
abstract final class DioClient {
  /// [languageCode] gives the app's language ("fr" or "en"), sent as
  /// `Accept-Language` on every request.
  static Dio create({
    required SecureStorage storage,
    VoidCallback? onSessionExpired,
    String Function()? languageCode,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
      ),
    );

    if (languageCode != null) dio.interceptors.add(LocaleInterceptor(languageCode));
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
