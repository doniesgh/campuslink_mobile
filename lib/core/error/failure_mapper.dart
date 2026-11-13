import 'package:dio/dio.dart';

import 'failures.dart';
import 'result.dart';

/// Converts a [DioException] into a [Failure]. Error bodies are
/// `{ "message": ..., "code"?: ..., ...details }` (see docs/api.md).
Failure mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.badResponse:
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final msg = data is Map ? data['message']?.toString() : null;
      final code = data is Map ? data['code']?.toString() : null;
      if (status == 401) {
        return UnauthorizedFailure(msg ?? 'Invalid credentials or expired session.', code);
      }
      if (status == 400 || status == 422) return ValidationFailure(msg ?? 'Invalid data.', code);
      if (status == 429) {
        return TooManyRequestsFailure(
          msg ?? TooManyRequestsFailure.defaultMessage,
          code ?? 'TOO_MANY_REQUESTS',
          _retryAfter(data, e.response?.headers),
        );
      }
      return ServerFailure(msg ?? 'Server error ($status).', code);
    default:
      return const UnknownFailure();
  }
}

/// The wait the server asked for: `retryAfter` (seconds) in the body, else
/// the `Retry-After` header. Null when neither says.
Duration? _retryAfter(Object? data, Headers? headers) {
  final fromBody = data is Map ? data['retryAfter'] : null;
  final seconds = fromBody is num
      ? fromBody.toInt()
      : int.tryParse(headers?.value('retry-after') ?? '');
  return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
}

/// Runs [call] and wraps the outcome in a [Result]. Use it in every repository.
Future<Result<T>> guard<T>(Future<T> Function() call) async {
  try {
    return Success(await call());
  } on DioException catch (e) {
    return Err(mapDioException(e));
  } catch (_) {
    return const Err(UnknownFailure());
  }
}
