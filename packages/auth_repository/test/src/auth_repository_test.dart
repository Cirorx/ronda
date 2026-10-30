import 'dart:convert';

import 'package:auth_repository/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_opener/link_opener.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements firebase_auth.FirebaseAuth;

class _FakeAuthProvider extends Fake implements firebase_auth.AuthProvider;

class _FakeAuthCredential extends Fake implements firebase_auth.AuthCredential;

class _MockUserCredential extends Mock implements firebase_auth.UserCredential;

class _MockLinkOpener extends Mock implements LinkOpener;

const _uid = 'demo-uid';

void main() {
  group(AuthRepository, () {
    late MockUser mockUser;
    late LinkOpener linkOpener;

    setUpAll(() {
      registerFallbackValue(_FakeAuthProvider());
      registerFallbackValue(_FakeAuthCredential());
      registerFallbackValue(Uri());
    });

    setUp(() {
      mockUser = MockUser(uid: _uid);
      linkOpener = _MockLinkOpener();
    });

    group('user', () {
      test('emits ${User.empty} when nobody is signed in', () {
        final subject = AuthRepository(
          firebaseAuth: MockFirebaseAuth(mockUser: mockUser),
          googleSignInFlow: GoogleSignInFlow.popup,
          linkOpener: linkOpener,
        );

        expect(subject.user, emits(User.empty));
      });

      test('emits the signed-in $User', () {
        final subject = AuthRepository(
          firebaseAuth: MockFirebaseAuth(signedIn: true, mockUser: mockUser),
          googleSignInFlow: GoogleSignInFlow.popup,
          linkOpener: linkOpener,
        );

        expect(subject.user, emits(const User(id: _uid)));
      });

      test('emits the $User after sign-in and ${User.empty} after '
          'sign-out', () async {
        final subject = AuthRepository(
          firebaseAuth: MockFirebaseAuth(mockUser: mockUser),
          googleSignInFlow: GoogleSignInFlow.popup,
          linkOpener: linkOpener,
        );

        final expectation = expectLater(
          subject.user,
          emitsInOrder([User.empty, const User(id: _uid), User.empty]),
        );
        await subject.signInWithGoogle();
        await subject.signOut();
        await expectation;
      });
    });

    group('currentUser', () {
      test('is ${User.empty} when nobody is signed in', () {
        final subject = AuthRepository(
          firebaseAuth: MockFirebaseAuth(mockUser: mockUser),
          googleSignInFlow: GoogleSignInFlow.popup,
          linkOpener: linkOpener,
        );

        expect(subject.currentUser, equals(User.empty));
      });

      test('is the signed-in $User', () {
        final subject = AuthRepository(
          firebaseAuth: MockFirebaseAuth(signedIn: true, mockUser: mockUser),
          googleSignInFlow: GoogleSignInFlow.popup,
          linkOpener: linkOpener,
        );

        expect(subject.currentUser, equals(const User(id: _uid)));
      });
    });

    group('signInWithGoogle', () {
      late firebase_auth.FirebaseAuth firebaseAuth;

      setUp(() {
        firebaseAuth = _MockFirebaseAuth();
      });

      AuthRepository subjectWith(GoogleSignInFlow flow) => AuthRepository(
        firebaseAuth: firebaseAuth,
        googleSignInFlow: flow,
        linkOpener: linkOpener,
      );

      test('calls signInWithPopup with a '
          '${firebase_auth.GoogleAuthProvider} on '
          '${GoogleSignInFlow.popup}', () async {
        when(() => firebaseAuth.signInWithPopup(any()))
            .thenAnswer((_) async => _MockUserCredential());

        await subjectWith(GoogleSignInFlow.popup).signInWithGoogle();

        final provider = verify(
          () => firebaseAuth.signInWithPopup(captureAny()),
        ).captured.single;
        expect(provider, isA<firebase_auth.GoogleAuthProvider>());
        verifyNever(() => firebaseAuth.signInWithProvider(any()));
        verifyNever(() => firebaseAuth.signInWithCredential(any()));
      });

      test('calls signInWithProvider with a '
          '${firebase_auth.GoogleAuthProvider} on '
          '${GoogleSignInFlow.provider}', () async {
        when(() => firebaseAuth.signInWithProvider(any()))
            .thenAnswer((_) async => _MockUserCredential());

        await subjectWith(GoogleSignInFlow.provider).signInWithGoogle();

        final provider = verify(
          () => firebaseAuth.signInWithProvider(captureAny()),
        ).captured.single;
        expect(provider, isA<firebase_auth.GoogleAuthProvider>());
        verifyNever(() => firebaseAuth.signInWithPopup(any()));
        verifyNever(() => firebaseAuth.signInWithCredential(any()));
      });

      test('calls signInWithCredential with the emulator account as an '
          'unsigned JSON id token on '
          '${GoogleSignInFlow.emulatorCredential}', () async {
        when(() => firebaseAuth.signInWithCredential(any()))
            .thenAnswer((_) async => _MockUserCredential());

        await subjectWith(GoogleSignInFlow.emulatorCredential)
            .signInWithGoogle();

        final credential =
            verify(() => firebaseAuth.signInWithCredential(captureAny()))
                    .captured
                    .single
                as firebase_auth.OAuthCredential;
        expect(credential.providerId, equals('google.com'));
        expect(
          jsonDecode(credential.idToken!),
          equals(AuthRepository.emulatorAccount),
        );
        verifyNever(() => firebaseAuth.signInWithPopup(any()));
        verifyNever(() => firebaseAuth.signInWithProvider(any()));
      });

      test('throws a cancelled $SignInWithGoogleFailure when the person '
          'closes the picker', () {
        when(() => firebaseAuth.signInWithPopup(any())).thenThrow(
          firebase_auth.FirebaseAuthException(code: 'popup-closed-by-user'),
        );

        expect(
          subjectWith(GoogleSignInFlow.popup).signInWithGoogle,
          throwsA(
            isA<SignInWithGoogleFailure>().having(
              (failure) => failure.reason,
              'reason',
              SignInWithGoogleFailureReason.cancelled,
            ),
          ),
        );
      });

      test('throws an unknown $SignInWithGoogleFailure on any other '
          'exception', () {
        when(() => firebaseAuth.signInWithProvider(any()))
            .thenThrow(Exception('boom'));

        expect(
          subjectWith(GoogleSignInFlow.provider).signInWithGoogle,
          throwsA(
            isA<SignInWithGoogleFailure>().having(
              (failure) => failure.reason,
              'reason',
              SignInWithGoogleFailureReason.unknown,
            ),
          ),
        );
      });
    });

    group('openCreateAccount', () {
      AuthRepository build() => AuthRepository(
        firebaseAuth: MockFirebaseAuth(mockUser: mockUser),
        googleSignInFlow: GoogleSignInFlow.popup,
        linkOpener: linkOpener,
      );

      test("opens Google's page to make an account", () async {
        when(() => linkOpener.open(any())).thenAnswer((_) async => true);

        await build().openCreateAccount();

        verify(
          () =>
              linkOpener.open(Uri.parse('https://accounts.google.com/signup')),
        ).called(1);
        expect(
          AuthRepository.createAccountUrl,
          equals(Uri.parse('https://accounts.google.com/signup')),
        );
      });

      test('throws $OpenCreateAccountFailure when nothing opens it', () {
        when(() => linkOpener.open(any())).thenAnswer((_) async => false);

        expect(
          build().openCreateAccount,
          throwsA(isA<OpenCreateAccountFailure>()),
        );
      });

      test('throws $OpenCreateAccountFailure when opening fails', () {
        when(() => linkOpener.open(any())).thenThrow(Exception('boom'));

        expect(
          build().openCreateAccount,
          throwsA(isA<OpenCreateAccountFailure>()),
        );
      });
    });

    group('signOut', () {
      test('signs out of Firebase Auth', () async {
        final subject = AuthRepository(
          firebaseAuth: MockFirebaseAuth(signedIn: true, mockUser: mockUser),
          googleSignInFlow: GoogleSignInFlow.popup,
          linkOpener: linkOpener,
        );

        await subject.signOut();

        expect(subject.currentUser, equals(User.empty));
      });

      test('throws $SignOutFailure when Firebase Auth fails', () {
        final firebaseAuth = _MockFirebaseAuth();
        when(firebaseAuth.signOut).thenThrow(Exception('boom'));
        final subject = AuthRepository(
          firebaseAuth: firebaseAuth,
          googleSignInFlow: GoogleSignInFlow.popup,
          linkOpener: linkOpener,
        );

        expect(subject.signOut, throwsA(isA<SignOutFailure>()));
      });
    });
  });
}
