import 'dart:convert';

import 'package:auth_repository/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/// {@template auth_repository}
/// Signs people in with Google over Firebase Auth and reports who is signed
/// in.
///
/// Google is the only way in: there is no phone, email or anonymous sign-in.
/// `firebaseAuth` is built in bootstrap (pointed at the Auth emulator in the
/// development flavor) and `googleSignInFlow` says how this platform reaches
/// Google.
/// {@endtemplate}
class AuthRepository {
  /// {@macro auth_repository}
  const new({required this._firebaseAuth, required this._googleSignInFlow});

  final firebase_auth.FirebaseAuth _firebaseAuth;
  final GoogleSignInFlow _googleSignInFlow;

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

  /// Who is signed in right now; [User.empty] when nobody is.
  User get currentUser => _firebaseAuth.currentUser.toUser;

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
