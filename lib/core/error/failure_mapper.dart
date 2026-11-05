import 'package:dio/dio.dart';

import 'failures.dart';
import 'result.dart';

/// Converts a [DioException] into a [Failure].
Failure mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.badResponse:
      final code = e.response?.statusCode;
      final data = e.response?.data;
      final msg = data is Map ? data['message']?.toString() : null;
      if (code == 401) return UnauthorizedFailure(msg ?? 'Invalid credentials or expired session.');
      if (code == 400 || code == 422) return ValidationFailure(msg ?? 'Invalid data.');
      return ServerFailure(msg ?? 'Server error ($code).');
    default:
      return const UnknownFailure();
  }
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
