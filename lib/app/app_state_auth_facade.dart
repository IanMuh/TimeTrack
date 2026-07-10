part of 'app_state.dart';

mixin AppStateAuthFacade on ChangeNotifier {
  AuthState get _authState;

  Future<void> sendMagicLink(String email) {
    return _authState.sendMagicLink(email);
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) {
    return _authState.verifyEmailOtp(email: email, token: token);
  }

  Future<void> signOut() => _authState.signOut();
}
