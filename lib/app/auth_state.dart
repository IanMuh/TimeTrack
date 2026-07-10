import '../data/sync_service.dart';

typedef MagicLinkSender = Future<void> Function(String email);
typedef EmailOtpVerifier = Future<void> Function({
  required String email,
  required String token,
});
typedef AuthActionRunner = Future<void> Function();

class AuthState {
  AuthState({
    required SyncService syncService,
    required AuthActionRunner refresh,
    required AuthActionRunner sync,
  }) : this.withHandlers(
          sendMagicLink: syncService.sendMagicLink,
          verifyEmailOtp: syncService.verifyEmailOtp,
          signOut: syncService.signOut,
          refresh: refresh,
          sync: sync,
        );

  AuthState.withHandlers({
    required MagicLinkSender sendMagicLink,
    required EmailOtpVerifier verifyEmailOtp,
    required AuthActionRunner signOut,
    required AuthActionRunner refresh,
    required AuthActionRunner sync,
  })  : _sendMagicLink = sendMagicLink,
        _verifyEmailOtp = verifyEmailOtp,
        _signOut = signOut,
        _refresh = refresh,
        _sync = sync;

  final MagicLinkSender _sendMagicLink;
  final EmailOtpVerifier _verifyEmailOtp;
  final AuthActionRunner _signOut;
  final AuthActionRunner _refresh;
  final AuthActionRunner _sync;

  Future<void> sendMagicLink(String email) {
    return _sendMagicLink(email);
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    await _verifyEmailOtp(email: email, token: token);
    await _refresh();
    await _sync();
  }

  Future<void> signOut() async {
    await _signOut();
    await _refresh();
  }
}
