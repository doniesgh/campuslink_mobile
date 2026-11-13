/// Typed errors exposed to the UI. The UI never sees Dio or HTTP types.
///
/// [message] is ready to show (usually the server's own sentence). [code] is
/// the server's machine-readable `code` when it sent one (e.g.
/// `VALIDATION_ERROR`, `TOO_MANY_REQUESTS`, `AI_UNAVAILABLE`, see docs/api.md):
/// screens can react to it, and `failureText` translates the known ones.
sealed class Failure {
  const Failure(this.message, {this.code});
  final String message;
  final String? code;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'The request timed out.']);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Invalid credentials or expired session.', String? code])
      : super(code: code);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Invalid data.', String? code]) : super(code: code);
}

/// Too many requests (HTTP 429): a rate limit, or a busy AI service. The
/// server's message says what to do; [retryAfter] is how long to wait, when
/// the server said so.
class TooManyRequestsFailure extends Failure {
  const TooManyRequestsFailure([
    super.message = TooManyRequestsFailure.defaultMessage,
    String? code = 'TOO_MANY_REQUESTS',
    this.retryAfter,
  ]) : super(code: code);

  static const defaultMessage = 'Too many attempts. Try again in a few minutes.';

  final Duration? retryAfter;
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server error. Please try again.', String? code])
      : super(code: code);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong.']);
}

/// Human-readable message for any error caught by AsyncValue.
String failureMessage(Object error) =>
    error is Failure ? error.message : const UnknownFailure().message;
