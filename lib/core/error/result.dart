import 'failures.dart';

/// Success-or-failure wrapper returned by repositories.
sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) =>
      switch (this) {
        Success<T>(value: final v) => success(v),
        Err<T>(failure: final f) => failure(f),
      };

  /// Returns the value or throws the [Failure] (handy inside FutureProviders).
  T unwrap() => when(success: (v) => v, failure: (f) => throw f);

  T? get dataOrNull => switch (this) {
        Success<T>(value: final v) => v,
        Err<T>() => null,
      };
}

class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
