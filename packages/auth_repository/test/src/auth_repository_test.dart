import 'dart:async';
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

class _MockFirebaseUser extends Mock implements firebase_auth.User;

class _MockIdTokenResult extends Mock implements firebase_auth.IdTokenResult;

class _MockUserInfo extends Mock implements firebase_auth.UserInfo;

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
          phoneSignInFlow: PhoneSignInFlow.verify,
        );

        expect(subject.user, emits(User.empty));
      });

      test('emits the signed-in $User', () {
        final subject = AuthRepository(
          firebaseAuth: MockFirebaseAuth(signedIn: true, mockUser: mockUser),
          googleSignInFlow: GoogleSignInFlow.popup,
          linkOpener: linkOpener,
          phoneSignInFlow: PhoneSignInFlow.verify,
        );

        expect(subject.user, emits(const User(id: _uid)));
      });

      test('emits the $User after sign-in and ${User.empty} after '
          'sign-out', () async {
        final subject = AuthRepository(
          firebaseAuth: MockFirebaseAuth(mockUser: mockUser),
          googleSignInFlow: GoogleSignInFlow.popup,
          linkOpener: linkOpener,
          phoneSignInFlow: PhoneSignInFlow.verify,
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
          phoneSignInFlow: PhoneSignInFlow.verify,
        );

        expect(subject.currentUser, equals(User.empty));
      });

      test('is the signed-in $User', () {
        final subject = AuthRepository(
          firebaseAuth: MockFirebaseAuth(signedIn: true, mockUser: mockUser),
          googleSignInFlow: GoogleSignInFlow.popup,
          linkOpener: linkOpener,
          phoneSignInFlow: PhoneSignInFlow.verify,
        );

        expect(subject.currentUser, equals(const User(id: _uid)));
      });
    });

    group('restoredUser', () {
      test('is the signed-in $User once the saved session is read', () async {
        final subject = AuthRepository(
          firebaseAuth: MockFirebaseAuth(signedIn: true, mockUser: mockUser),
          googleSignInFlow: GoogleSignInFlow.popup,
          linkOpener: linkOpener,
          phoneSignInFlow: PhoneSignInFlow.verify,
        );

        expect(await subject.restoredUser(), equals(const User(id: _uid)));
      });

      test('is ${User.empty} when nobody is signed in', () async {
        final subject = AuthRepository(
          firebaseAuth: MockFirebaseAuth(mockUser: mockUser),
          googleSignInFlow: GoogleSignInFlow.popup,
          linkOpener: linkOpener,
          phoneSignInFlow: PhoneSignInFlow.verify,
        );

        expect(await subject.restoredUser(), equals(User.empty));
      });

      test('falls back to the current user when the session never '
          'arrives', () async {
        final firebaseAuth = _MockFirebaseAuth();
        final sessions = StreamController<firebase_auth.User?>();
        addTearDown(sessions.close);
        when(firebaseAuth.authStateChanges).thenAnswer((_) => sessions.stream);
        when(() => firebaseAuth.currentUser).thenReturn(null);
        final subject = AuthRepository(
          firebaseAuth: firebaseAuth,
          googleSignInFlow: GoogleSignInFlow.popup,
          linkOpener: linkOpener,
          phoneSignInFlow: PhoneSignInFlow.verify,
        );

        expect(
          await subject.restoredUser(timeout: Duration.zero),
          equals(User.empty),
        );
      });
    });

    group('signInAccount', () {
      late firebase_auth.FirebaseAuth firebaseAuth;
      late firebase_auth.User firebaseUser;

      AuthRepository subject() => AuthRepository(
        firebaseAuth: firebaseAuth,
        googleSignInFlow: GoogleSignInFlow.popup,
        linkOpener: linkOpener,
        phoneSignInFlow: PhoneSignInFlow.verify,
      );

      firebase_auth.UserInfo info(
        String providerId, {
        String? email,
        String? phoneNumber,
      }) {
        final info = _MockUserInfo();
        when(() => info.providerId).thenReturn(providerId);
        when(() => info.email).thenReturn(email);
        when(() => info.phoneNumber).thenReturn(phoneNumber);
        return info;
      }

      setUp(() {
        firebaseAuth = _MockFirebaseAuth();
        firebaseUser = _MockFirebaseUser();
        when(() => firebaseAuth.currentUser).thenReturn(firebaseUser);
        when(() => firebaseUser.email).thenReturn(null);
        when(() => firebaseUser.phoneNumber).thenReturn(null);
      });

      test('is null when nobody is signed in', () {
        when(() => firebaseAuth.currentUser).thenReturn(null);

        expect(subject().signInAccount, isNull);
      });

      test('is Google with its email', () {
        final google = info('google.com', email: 'vecina@example.com');
        when(() => firebaseUser.providerData).thenReturn([google]);

        expect(
          subject().signInAccount,
          equals(
            const SignInAccount(
              method: SignInMethod.google,
              address: 'vecina@example.com',
            ),
          ),
        );
      });

      test('is the phone with its number', () {
        final phone = info('phone', phoneNumber: '+59899123456');
        when(() => firebaseUser.providerData).thenReturn([phone]);

        expect(
          subject().signInAccount,
          equals(
            const SignInAccount(
              method: SignInMethod.phone,
              address: '+59899123456',
            ),
          ),
        );
      });

      test("falls back to the user's own email and number", () {
        when(() => firebaseUser.email).thenReturn('vecina@example.com');
        when(() => firebaseUser.phoneNumber).thenReturn('+59899123456');
        final google = info('google.com');
        when(() => firebaseUser.providerData).thenReturn([google]);
        expect(subject().signInAccount?.address, equals('vecina@example.com'));

        final phone = info('phone');
        when(() => firebaseUser.providerData).thenReturn([phone]);
        expect(subject().signInAccount?.address, equals('+59899123456'));
      });

      test('is null for an account with neither way in', () {
        final password = info('password');
        when(() => firebaseUser.providerData).thenReturn([password]);

        expect(subject().signInAccount, isNull);
      });
    });

    group('tokenChanges', () {
      test('emits ${User.empty} when nobody is signed in', () {
        final subject = AuthRepository(
          firebaseAuth: MockFirebaseAuth(mockUser: mockUser),
          googleSignInFlow: GoogleSignInFlow.popup,
          linkOpener: linkOpener,
          phoneSignInFlow: PhoneSignInFlow.verify,
        );

        expect(subject.tokenChanges, emits(User.empty));
      });

      test('emits the signed-in $User on each new ID token', () {
        final firebaseAuth = _MockFirebaseAuth();
        final firebaseUser = _MockFirebaseUser();
        when(() => firebaseUser.uid).thenReturn(_uid);
        when(firebaseAuth.idTokenChanges).thenAnswer(
          (_) => Stream.fromIterable([firebaseUser, firebaseUser, null]),
        );
        final subject = AuthRepository(
          firebaseAuth: firebaseAuth,
          googleSignInFlow: GoogleSignInFlow.popup,
          linkOpener: linkOpener,
          phoneSignInFlow: PhoneSignInFlow.verify,
        );

        expect(
          subject.tokenChanges,
          emitsInOrder([
            const User(id: _uid),
            const User(id: _uid),
            User.empty,
            emitsDone,
          ]),
        );
      });
    });

    group('hasAdminClaim', () {
      late firebase_auth.FirebaseAuth firebaseAuth;
      late firebase_auth.User firebaseUser;
      late firebase_auth.IdTokenResult token;

      setUp(() {
        firebaseAuth = _MockFirebaseAuth();
        firebaseUser = _MockFirebaseUser();
        token = _MockIdTokenResult();
        when(() => firebaseAuth.currentUser).thenReturn(firebaseUser);
        when(() => firebaseUser.getIdTokenResult(any()))
            .thenAnswer((_) async => token);
      });

      AuthRepository build() => AuthRepository(
        firebaseAuth: firebaseAuth,
        googleSignInFlow: GoogleSignInFlow.popup,
        linkOpener: linkOpener,
        phoneSignInFlow: PhoneSignInFlow.verify,
      );

      test('is true when the token carries admin: true', () async {
        when(() => token.claims).thenReturn({'admin': true});

        expect(await build().hasAdminClaim(forceRefresh: false), isTrue);
      });

      for (final claims in <Map<String, dynamic>?>[
        null,
        {},
        {'admin': false},
        {'admin': 'true'},
        {'admin': 1},
        {'role': 'admin'},
      ]) {
        test('is false when the claims are $claims', () async {
          when(() => token.claims).thenReturn(claims);

          expect(await build().hasAdminClaim(forceRefresh: false), isFalse);
        });
      }

      test('fetches the token again when forced', () async {
        when(() => token.claims).thenReturn({'admin': true});

        await build().hasAdminClaim(forceRefresh: true);

        verify(() => firebaseUser.getIdTokenResult(true)).called(1);
      });

      test('reads the token it has when not forced', () async {
        when(() => token.claims).thenReturn({});

        await build().hasAdminClaim(forceRefresh: false);

        verify(() => firebaseUser.getIdTokenResult()).called(1);
      });

      test('is false when nobody is signed in', () async {
        when(() => firebaseAuth.currentUser).thenReturn(null);

        expect(await build().hasAdminClaim(forceRefresh: true), isFalse);
      });

      test('throws $AdminClaimFailure when the token cannot be read', () {
        when(() => firebaseUser.getIdTokenResult(any()))
            .thenThrow(firebase_auth.FirebaseAuthException(code: 'network'));

        expect(
          () => build().hasAdminClaim(forceRefresh: true),
          throwsA(isA<AdminClaimFailure>()),
        );
      });

      test('reads a claim from a real-shaped token', () async {
        final subject = AuthRepository(
          firebaseAuth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: _uid, customClaim: {'admin': true}),
          ),
          googleSignInFlow: GoogleSignInFlow.popup,
          linkOpener: linkOpener,
          phoneSignInFlow: PhoneSignInFlow.verify,
        );

        expect(await subject.hasAdminClaim(forceRefresh: true), isTrue);
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
        phoneSignInFlow: PhoneSignInFlow.verify,
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
        phoneSignInFlow: PhoneSignInFlow.verify,
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
          phoneSignInFlow: PhoneSignInFlow.verify,
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
          phoneSignInFlow: PhoneSignInFlow.verify,
        );

        expect(subject.signOut, throwsA(isA<SignOutFailure>()));
      });
    });
  });
}
