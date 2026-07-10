import '../core/result.dart';

final class AppStateFailure {
  const AppStateFailure(this.message);

  final String message;
}

final class AppStateException extends StateError implements Exception {
  AppStateException(this.failure) : super(failure.message);

  final AppStateFailure failure;
}

T unwrapAppStateResult<T>(AppResult<T> result) {
  return switch (result) {
    AppSuccess(:final value) => value,
    AppFailure(:final message) => throw AppStateException(
        AppStateFailure(message),
      ),
  };
}
