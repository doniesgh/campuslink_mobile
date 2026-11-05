/// Typed errors exposed to the UI. The UI never sees Dio or HTTP types.
sealed class Failure {
  const Failure(this.message);
  final String message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'The request timed out.']);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Invalid credentials or expired session.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'Invalid data.']);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server error. Please try again.']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong.']);
}

/// Human-readable message for any error caught by AsyncValue.
String failureMessage(Object error) =>
    error is Failure ? error.message : const UnknownFailure().message;
