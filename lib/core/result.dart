sealed class AppResult<T> {
  const AppResult();

  R fold<R>({
    required R Function(T) onSuccess,
    required R Function(String) onFailure,
  }) {
    return switch (this) {
      AppSuccess(:final value) => onSuccess(value),
      AppFailure(:final message) => onFailure(message),
    };
  }

  R when<R>({
    required R Function(T) onSuccess,
    required R Function(String) onFailure,
  }) =>
      fold(onSuccess: onSuccess, onFailure: onFailure);
}

class AppSuccess<T> extends AppResult<T> {
  const AppSuccess(this.value);

  final T value;
}

class AppFailure<T> extends AppResult<T> {
  const AppFailure(this.message);

  final String message;
}
