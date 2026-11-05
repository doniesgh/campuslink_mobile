import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../storage/secure_storage.dart';
import '../api_endpoints.dart';

/// Attaches the JWT, and on a 401 refreshes it once and retries the request.
/// Requests that must not carry a token (login...) pass [skipAuth].
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.storage,
    required this.dio,
    this.onSessionExpired,
  });

  final SecureStorage storage;
  final Dio dio;
  final VoidCallback? onSessionExpired;

  static const _skipKey = 'skipAuth';
  static Options get skipAuth => Options(extra: {_skipKey: true});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[_skipKey] != true) {
      final token = await storage.readAccessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final skip = err.requestOptions.extra[_skipKey] == true;
    if (err.response?.statusCode != 401 || skip) return handler.next(err);

    final refresh = await storage.readRefreshToken();
    if (refresh == null) {
      onSessionExpired?.call();
      return handler.next(err);
    }

    try {
      // Separate Dio instance: avoids re-entering this interceptor.
      final res = await Dio(BaseOptions(baseUrl: dio.options.baseUrl))
          .post(ApiEndpoints.refresh, data: {'refreshToken': refresh});
      final data = res.data as Map<String, dynamic>;
      final access = data['accessToken'] as String;
      await storage.saveTokens(
        access: access,
        refresh: (data['refreshToken'] as String?) ?? refresh,
      );
      final retry = err.requestOptions
        ..headers['Authorization'] = 'Bearer $access';
      handler.resolve(await dio.fetch(retry));
    } on DioException {
      await storage.clear();
      onSessionExpired?.call();
      handler.next(err);
    }
  }
}
