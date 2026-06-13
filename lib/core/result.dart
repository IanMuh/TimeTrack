sealed class AppResult<T> {
  const AppResult();
}

class AppSuccess<T> extends AppResult<T> {
  const AppSuccess(this.value);

  final T value;
}

class AppFailure<T> extends AppResult<T> {
  const AppFailure(this.message);

  final String message;
}
