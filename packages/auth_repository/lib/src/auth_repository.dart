import 'dart:async';
import 'dart:convert';

import 'package:auth_repository/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:link_opener/link_opener.dart';

/// {@template auth_repository}
/// Signs people in with Google or a phone number over Firebase Auth and
/// reports who is signed in.
///
/// There is no email or anonymous sign-in. `firebaseAuth` is built in
/// bootstrap (pointed at the Auth emulator in the development flavor),
/// `googleSignInFlow` says how this platform reaches Google,
/// `phoneSignInFlow` how it sends a code by SMS, and `linkOpener` opens
/// Google's page to make an account. `now` is the clock the resend
/// cooldowns read.
/// {@endtemplate}
class AuthRepository {
  /// {@macro auth_repository}
  const new({
    required this._firebaseAuth,
    required this._googleSignInFlow,
    required this._linkOpener,
    required this._phoneSignInFlow,
    this._now = DateTime.now,
  });

  final firebase_auth.FirebaseAuth _firebaseAuth;
  final GoogleSignInFlow _googleSignInFlow;
  final LinkOpener _linkOpener;
  final PhoneSignInFlow _phoneSignInFlow;
  final DateTime Function() _now;

  /// Google's page to make an account, for someone who has none.
  static final Uri createAccountUrl = Uri.parse(
    'https://accounts.google.com/signup',
  );

  /// The demo account [GoogleSignInFlow.emulatorCredential] signs in as.
  ///
  /// Invented: it exists only inside the Auth emulator.
  static const emulatorAccount = <String, Object>{
    'sub': 'ronda-emulator-vecina',
    'email': 'vecina@example.com',
    'email_verified': true,
    'name': 'Vecina de prueba',
  };

  /// The signed-in [User], or [User.empty] when nobody is; emits on every
  /// sign-in and sign-out.
  Stream<User> get user =>
      _firebaseAuth.authStateChanges().map((user) => user.toUser);

  /// Who is signed in right now; [User.empty] when nobody is, and in a
  /// browser until [restoredUser] completes.
  User get currentUser => _firebaseAuth.currentUser.toUser;

  /// How long [restoredUser] waits for the saved session.
  static const restoreTimeout = Duration(seconds: 5);

  /// Who is signed in once Firebase Auth has read the session saved on this
  /// phone or browser, so the app opens on the right screen for someone who
  /// signed in before. Gives up after [timeout] and returns [currentUser];
  /// [user] reports the session if it arrives later.
  Future<User> restoredUser({Duration timeout = restoreTimeout}) async {
    try {
      final user = await _firebaseAuth.authStateChanges().first.timeout(
        timeout,
      );
      return user.toUser;
    } on TimeoutException {
      return currentUser;
    }
  }

  /// How the signed-in person enters, with Google or a phone number, and the
  /// email or the number; null when nobody is signed in or the account has
  /// neither (only the Auth emulator makes such accounts).
  ///
  /// Read from Firebase Auth on the phone, for the person's own eyes: no
  /// document holds it.
  SignInAccount? get signInAccount {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    for (final info in user.providerData) {
      switch (info.providerId) {
        case _googleProviderId:
          return SignInAccount(
            method: SignInMethod.google,
            address: info.email ?? user.email,
          );
        case _phoneProviderId:
          return SignInAccount(
            method: SignInMethod.phone,
            address: info.phoneNumber ?? user.phoneNumber,
          );
      }
    }
    return null;
  }

  /// Firebase Auth's ids for the two ways in.
  static const _googleProviderId = 'google.com';
  static const _phoneProviderId = 'phone';

  /// The signed-in [User], or [User.empty] when nobody is; emits on every
  /// sign-in and sign-out and each time Firebase Auth renews the ID token
  /// (about once an hour while the app is open), so a custom claim set or
  /// removed on the server is read again.
  Stream<User> get tokenChanges =>
      _firebaseAuth.idTokenChanges().map((user) => user.toUser);

  /// Whether the signed-in person's ID token carries the `admin` custom
  /// claim (`scripts/set_admin.py` sets it), exactly `true`. False when
  /// nobody is signed in.
  ///
  /// With [forceRefresh] the token is fetched again from Firebase Auth
  /// first, so a claim set since the last renewal shows; that fetch makes
  /// [tokenChanges] emit once more, so never force it from a listener of
  /// [tokenChanges] for every event. The claim only decides what the app
  /// shows: the rules and the callables check it again on every admin read
  /// and call.
  ///
  /// Throws an [AdminClaimFailure] when the token can't be read.
  Future<bool> hasAdminClaim({required bool forceRefresh}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return false;
    try {
      final token = await user.getIdTokenResult(forceRefresh);
      return token.claims?['admin'] == true;
    } on Exception {
      throw const AdminClaimFailure();
    }
  }

  /// Signs in with Google through [GoogleSignInFlow].
  ///
  /// Throws a [SignInWithGoogleFailure] when sign-in does not finish,
  /// including when the person cancels.
  Future<void> signInWithGoogle() async {
    try {
      switch (_googleSignInFlow) {
        case GoogleSignInFlow.popup:
          await _firebaseAuth.signInWithPopup(
            firebase_auth.GoogleAuthProvider(),
          );
        case GoogleSignInFlow.provider:
          await _firebaseAuth.signInWithProvider(
            firebase_auth.GoogleAuthProvider(),
          );
        case GoogleSignInFlow.emulatorCredential:
          await _firebaseAuth.signInWithCredential(
            firebase_auth.GoogleAuthProvider.credential(
              idToken: jsonEncode(emulatorAccount),
            ),
          );
      }
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw SignInWithGoogleFailure.fromCode(error.code);
    } on Exception {
      throw const SignInWithGoogleFailure();
    }
  }

  /// Sends a sign-in code by SMS to [phoneNumber].
  ///
  /// Returns the [PhoneVerification] to confirm the code against, or null
  /// when Android verified the number without one (instant verification),
  /// in which case the person is already signed in. On Android the SMS may
  /// also be read automatically after the code is sent: the person is then
  /// signed in while the code screen waits, and [user] says so.
  ///
  /// Pass the previous verification as [resending] to send another code;
  /// it waits for [PhoneVerification.resendAvailableAt]. Throws a
  /// [SendPhoneCodeFailure] when no code goes out, with
  /// [SendPhoneCodeFailureReason.tooSoon] (and nothing sent) when it is not
  /// time yet or no more codes may be sent.
  Future<PhoneVerification?> sendPhoneCode(
    PhoneNumber phoneNumber, {
    PhoneVerification? resending,
  }) async {
    final sends = (resending?.sends ?? 0) + 1;
    if (resending != null) {
      final availableAt = resending.resendAvailableAt;
      if (availableAt == null || _now().isBefore(availableAt)) {
        throw const SendPhoneCodeFailure(SendPhoneCodeFailureReason.tooSoon);
      }
    }
    try {
      switch (_phoneSignInFlow) {
        case PhoneSignInFlow.confirmation:
          // With no verifier, FlutterFire makes an invisible reCAPTCHA and
          // clears it afterwards.
          final confirmation = await _firebaseAuth.signInWithPhoneNumber(
            phoneNumber.e164,
          );
          return PhoneVerification(
            phoneNumber: phoneNumber,
            sentAt: _now(),
            sends: sends,
            confirmation: confirmation,
          );
        case PhoneSignInFlow.verify:
          return await _verifyPhoneNumber(
            phoneNumber,
            sends: sends,
            resendToken: resending?.resendToken,
          );
      }
    } on SendPhoneCodeFailure {
      rethrow;
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw SendPhoneCodeFailure.fromCode(error.code);
    } on Exception {
      throw const SendPhoneCodeFailure();
    }
  }

  /// `verifyPhoneNumber` answers through callbacks, some of them after the
  /// code is sent: the first of "code sent", "verified without a code" or
  /// "failed" settles the future; an automatic sign-in after that signs in
  /// on its own, and its failure leaves the person typing the code.
  Future<PhoneVerification?> _verifyPhoneNumber(
    PhoneNumber phoneNumber, {
    required int sends,
    required int? resendToken,
  }) async {
    final settled = Completer<PhoneVerification?>();
    // A callback can fail it before verifyPhoneNumber returns, while nobody
    // listens yet; the await below still gets the error.
    settled.future.ignore();
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber.e164,
      forceResendingToken: resendToken,
      verificationCompleted: (credential) async {
        try {
          await _firebaseAuth.signInWithCredential(credential);
          if (!settled.isCompleted) settled.complete(null);
        } on firebase_auth.FirebaseAuthException catch (error) {
          if (!settled.isCompleted) {
            settled.completeError(SendPhoneCodeFailure.fromCode(error.code));
          }
        } on Exception {
          if (!settled.isCompleted) {
            settled.completeError(const SendPhoneCodeFailure());
          }
        }
      },
      verificationFailed: (error) {
        if (!settled.isCompleted) {
          settled.completeError(SendPhoneCodeFailure.fromCode(error.code));
        }
      },
      codeSent: (verificationId, resendToken) {
        if (settled.isCompleted) return;
        settled.complete(
          PhoneVerification(
            phoneNumber: phoneNumber,
            sentAt: _now(),
            sends: sends,
            verificationId: verificationId,
            resendToken: resendToken,
          ),
        );
      },
      // The code screen keeps waiting for the person to type it.
      codeAutoRetrievalTimeout: (_) {},
    );
    return await settled.future;
  }

  /// Signs in with the [code] the person typed from the SMS [verification]
  /// announced.
  ///
  /// Throws a [ConfirmPhoneCodeFailure] when it does not sign them in.
  Future<void> confirmPhoneCode(
    PhoneVerification verification,
    String code,
  ) async {
    try {
      if (verification.confirmation case final confirmation?) {
        await confirmation.confirm(code);
        return;
      }
      final verificationId = verification.verificationId;
      if (verificationId == null) throw const ConfirmPhoneCodeFailure();
      await _firebaseAuth.signInWithCredential(
        firebase_auth.PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code,
        ),
      );
    } on ConfirmPhoneCodeFailure {
      rethrow;
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw ConfirmPhoneCodeFailure.fromCode(error.code);
    } on Exception {
      throw const ConfirmPhoneCodeFailure();
    }
  }

  /// Opens [createAccountUrl] in the phone's browser.
  ///
  /// Throws an [OpenCreateAccountFailure] when no browser opens it.
  Future<void> openCreateAccount() async {
    final bool opened;
    try {
      opened = await _linkOpener.open(createAccountUrl);
    } on Exception {
      throw const OpenCreateAccountFailure();
    }
    if (!opened) throw const OpenCreateAccountFailure();
  }

  /// Signs out.
  ///
  /// Throws a [SignOutFailure] when Firebase Auth fails to sign out.
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on Exception {
      throw const SignOutFailure();
    }
  }
}

extension on firebase_auth.User? {
  User get toUser {
    final user = this;
    return user == null ? User.empty : User(id: user.uid);
  }
}
