import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';

/// What the app may show of the admin screens to whoever is signed in.
enum AdminAccess {
  /// Nobody is signed in, or the token of who just signed in hasn't come
  /// yet.
  signedOut,

  /// Signed in; the token is being read.
  checking,

  /// The ID token carries `admin: true`: the Admin tab shows.
  admin,

  /// Signed in without the claim, or the token couldn't be read.
  member,
}

/// Whether the signed-in person is the admin, read from their ID token's
/// `admin` custom claim, never from Firestore, the phone or the build.
///
/// For each person who signs in, the first read forces a fresh token, so a
/// claim set or taken away since the token was saved on this phone shows
/// at once. That fetch renews the token, and every later renewal (about
/// once an hour) is read as it comes, without forcing, so a lost claim
/// hides the tab after the next renewal. A token that can't be read counts
/// as no claim.
///
/// This only decides what the app shows. Every admin read and call is
/// checked again on the server (`firestore.rules`, the callables'
/// `_require_admin`).
class AdminAccessCubit extends Cubit<AdminAccess> {
  new({required this._authRepository}) : super(AdminAccess.signedOut);

  final AuthRepository _authRepository;
  StreamSubscription<User>? _subscription;

  /// The uid whose token was last fetched fresh.
  String? _refreshedFor;

  /// Counts token events, so only the newest read is emitted.
  int _reads = 0;

  /// Follows sign-ins, sign-outs and token renewals.
  void subscribe() {
    unawaited(_subscription?.cancel());
    _subscription = _authRepository.tokenChanges.listen(
      _onToken,
      onError: (Object error, StackTrace stackTrace) {
        addError(error, stackTrace);
        emit(AdminAccess.member);
      },
    );
  }

  Future<void> _onToken(User user) async {
    final read = ++_reads;
    if (user.isEmpty) {
      _refreshedFor = null;
      emit(AdminAccess.signedOut);
      return;
    }
    final forceRefresh = _refreshedFor != user.id;
    if (forceRefresh) {
      _refreshedFor = user.id;
      emit(AdminAccess.checking);
    }
    AdminAccess access;
    try {
      access = await _authRepository.hasAdminClaim(forceRefresh: forceRefresh)
          ? AdminAccess.admin
          : AdminAccess.member;
    } on AdminClaimFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      access = AdminAccess.member;
    }
    if (read == _reads && !isClosed) emit(access);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
