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

  /// Same options as [dio] but without interceptors, for the refresh call and
  /// the retry. Sending the retry through [dio] would deadlock if it failed:
  /// its error would queue behind the onError call that is awaiting it.
  late final Dio _plainDio = Dio(dio.options.copyWith());

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

    final String access;
    try {
      final res = await _plainDio
          .post(ApiEndpoints.refresh, data: {'refreshToken': refresh});
      final data = res.data as Map<String, dynamic>;
      access = data['accessToken'] as String;
      await storage.saveTokens(
        access: access,
        refresh: (data['refreshToken'] as String?) ?? refresh,
      );
    } catch (_) {
      // Catch everything (not just DioException): a malformed response throws
      // a TypeError, and an uncaught error here would never call the handler.
      await storage.clear();
      onSessionExpired?.call();
      return handler.next(err);
    }

    // The session is valid again, so a failed retry is reported as-is
    // instead of logging the user out.
    final retry = err.requestOptions
      ..headers['Authorization'] = 'Bearer $access';
    try {
      handler.resolve(await _plainDio.fetch(retry));
    } on DioException catch (e) {
      handler.next(e);
    } catch (e, st) {
      handler.next(DioException(requestOptions: retry, error: e, stackTrace: st));
    }
  }
}
