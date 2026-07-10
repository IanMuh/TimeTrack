import '../core/result.dart';

final class RepositoryFailure {
  const RepositoryFailure(this.message);

  final String message;
}

final class RepositoryException extends StateError implements Exception {
  RepositoryException(this.failure) : super(failure.message);

  final RepositoryFailure failure;
}

T unwrapRepositoryResult<T>(AppResult<T> result) {
  return switch (result) {
    AppSuccess(:final value) => value,
    AppFailure(:final message) => throw RepositoryException(
        RepositoryFailure(message),
      ),
  };
}
