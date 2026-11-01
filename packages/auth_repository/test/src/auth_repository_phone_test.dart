import 'package:auth_repository/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:link_opener/link_opener.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements firebase_auth.FirebaseAuth;

class _MockConfirmationResult extends Mock
    implements firebase_auth.ConfirmationResult;

class _MockUserCredential extends Mock implements firebase_auth.UserCredential;

class _FakeAuthCredential extends Fake implements firebase_auth.AuthCredential;

class _MockLinkOpener extends Mock implements LinkOpener;

// An invented number, nobody's phone.
final PhoneNumber _number = PhoneNumber.tryParse('099 000 001')!;
const _e164 = '+59899000001';
final _start = DateTime.utc(2026, 11, 2, 10);

void main() {
  group('$AuthRepository phone sign-in', () {
    late firebase_auth.FirebaseAuth firebaseAuth;
    late DateTime now;

    setUpAll(() {
      registerFallbackValue(_FakeAuthCredential());
      registerFallbackValue((firebase_auth.PhoneAuthCredential _) {});
      registerFallbackValue((firebase_auth.FirebaseAuthException _) {});
      registerFallbackValue((String _, int? _) {});
      registerFallbackValue((String _) {});
    });

    setUp(() {
      firebaseAuth = _MockFirebaseAuth();
      now = _start;
      when(() => firebaseAuth.signInWithCredential(any()))
          .thenAnswer((_) async => _MockUserCredential());
    });

    AuthRepository subjectWith(PhoneSignInFlow flow) => AuthRepository(
      firebaseAuth: firebaseAuth,
      googleSignInFlow: GoogleSignInFlow.provider,
      linkOpener: _MockLinkOpener(),
      phoneSignInFlow: flow,
      now: () => now,
    );

    /// Answers `verifyPhoneNumber` by calling back what [answer] picks.
    void whenVerify(
      void Function({
        required firebase_auth.PhoneVerificationCompleted completed,
        required firebase_auth.PhoneVerificationFailed failed,
        required firebase_auth.PhoneCodeSent codeSent,
      })
      answer,
    ) {
      when(
        () => firebaseAuth.verifyPhoneNumber(
          phoneNumber: any(named: 'phoneNumber'),
          forceResendingToken: any(named: 'forceResendingToken'),
          verificationCompleted: any(named: 'verificationCompleted'),
          verificationFailed: any(named: 'verificationFailed'),
          codeSent: any(named: 'codeSent'),
          codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
        ),
      ).thenAnswer((invocation) async {
        final named = invocation.namedArguments;
        answer(
          completed:
              named[#verificationCompleted]
                  as firebase_auth.PhoneVerificationCompleted,
          failed:
              named[#verificationFailed]
                  as firebase_auth.PhoneVerificationFailed,
          codeSent: named[#codeSent] as firebase_auth.PhoneCodeSent,
        );
        (named[#codeAutoRetrievalTimeout]
                as firebase_auth.PhoneCodeAutoRetrievalTimeout)
            .call('verification-id');
      });
    }

    Matcher throwsSendFailure(SendPhoneCodeFailureReason reason) => throwsA(
      isA<SendPhoneCodeFailure>().having(
        (failure) => failure.reason,
        'reason',
        reason,
      ),
    );

    Matcher throwsConfirmFailure(ConfirmPhoneCodeFailureReason reason) =>
        throwsA(
          isA<ConfirmPhoneCodeFailure>().having(
            (failure) => failure.reason,
            'reason',
            reason,
          ),
        );

    final credential = firebase_auth.PhoneAuthProvider.credential(
      verificationId: 'verification-id',
      smsCode: '123456',
    );

    group('sendPhoneCode on ${PhoneSignInFlow.verify}', () {
      test('returns the verification once the code is sent', () async {
        whenVerify(({required completed, required failed, required codeSent}) {
          codeSent('verification-id', 7);
        });

        final verification = await subjectWith(PhoneSignInFlow.verify)
            .sendPhoneCode(_number);

        expect(
          verification,
          equals(
            PhoneVerification(
              phoneNumber: _number,
              sentAt: _start,
              verificationId: 'verification-id',
              resendToken: 7,
            ),
          ),
        );
        verify(
          () => firebaseAuth.verifyPhoneNumber(
            phoneNumber: _e164,
            verificationCompleted: any(named: 'verificationCompleted'),
            verificationFailed: any(named: 'verificationFailed'),
            codeSent: any(named: 'codeSent'),
            codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
          ),
        ).called(1);
      });

      test('signs in and returns null when Android verifies the number '
          'without a code', () async {
        whenVerify(({required completed, required failed, required codeSent}) {
          completed(credential);
        });

        final verification = await subjectWith(PhoneSignInFlow.verify)
            .sendPhoneCode(_number);

        expect(verification, isNull);
        verify(() => firebaseAuth.signInWithCredential(credential)).called(1);
      });

      test('signs in when the SMS is read automatically after the code is '
          'sent', () async {
        whenVerify(({required completed, required failed, required codeSent}) {
          codeSent('verification-id', 7);
          completed(credential);
        });

        final verification = await subjectWith(PhoneSignInFlow.verify)
            .sendPhoneCode(_number);
        await pumpEventQueue();

        expect(verification, isNotNull);
        verify(() => firebaseAuth.signInWithCredential(credential)).called(1);
      });

      test(
        'ignores a failed automatic sign-in after the code is sent',
        () async {
          when(() => firebaseAuth.signInWithCredential(any())).thenThrow(
            firebase_auth.FirebaseAuthException(code: 'session-expired'),
          );
          whenVerify(({
            required completed,
            required failed,
            required codeSent,
          }) {
            codeSent('verification-id', 7);
            completed(credential);
            failed(firebase_auth.FirebaseAuthException(code: 'internal-error'));
          });

          final verification = await subjectWith(PhoneSignInFlow.verify)
              .sendPhoneCode(_number);
          await pumpEventQueue();

          expect(verification, isNotNull);
        },
      );

      test('throws when the automatic sign-in without a code fails', () {
        when(() => firebaseAuth.signInWithCredential(any())).thenThrow(
          firebase_auth.FirebaseAuthException(code: 'network-request-failed'),
        );
        whenVerify(({required completed, required failed, required codeSent}) {
          completed(credential);
        });

        expect(
          subjectWith(PhoneSignInFlow.verify).sendPhoneCode(_number),
          throwsSendFailure(SendPhoneCodeFailureReason.network),
        );
      });

      test('throws an unknown failure when the automatic sign-in throws '
          'something else', () {
        when(() => firebaseAuth.signInWithCredential(any()))
            .thenThrow(Exception('boom'));
        whenVerify(({required completed, required failed, required codeSent}) {
          completed(credential);
        });

        expect(
          subjectWith(PhoneSignInFlow.verify).sendPhoneCode(_number),
          throwsSendFailure(SendPhoneCodeFailureReason.unknown),
        );
      });

      test('ignores a late automatic sign-in failure', () async {
        when(() => firebaseAuth.signInWithCredential(any()))
            .thenThrow(Exception('boom'));
        whenVerify(({required completed, required failed, required codeSent}) {
          codeSent('verification-id', 7);
          completed(credential);
        });

        expect(
          await subjectWith(PhoneSignInFlow.verify).sendPhoneCode(_number),
          isNotNull,
        );
        await pumpEventQueue();
      });

      test('ignores a code sent after verifying without one', () async {
        whenVerify(({required completed, required failed, required codeSent}) {
          completed(credential);
          // Lands after the sign-in above has settled the future.
          Future<void>.delayed(Duration.zero, () => codeSent('late', null));
        });

        final verification = await subjectWith(PhoneSignInFlow.verify)
            .sendPhoneCode(_number);
        await pumpEventQueue();

        expect(verification, isNull);
      });

      test('throws the mapped failure when verification fails', () {
        whenVerify(({required completed, required failed, required codeSent}) {
          failed(
            firebase_auth.FirebaseAuthException(code: 'too-many-requests'),
          );
        });

        expect(
          subjectWith(PhoneSignInFlow.verify).sendPhoneCode(_number),
          throwsSendFailure(SendPhoneCodeFailureReason.tooManyRequests),
        );
      });

      test('throws the mapped failure when verifyPhoneNumber throws', () {
        when(
          () => firebaseAuth.verifyPhoneNumber(
            phoneNumber: any(named: 'phoneNumber'),
            forceResendingToken: any(named: 'forceResendingToken'),
            verificationCompleted: any(named: 'verificationCompleted'),
            verificationFailed: any(named: 'verificationFailed'),
            codeSent: any(named: 'codeSent'),
            codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
          ),
        ).thenThrow(
          firebase_auth.FirebaseAuthException(code: 'invalid-phone-number'),
        );

        expect(
          subjectWith(PhoneSignInFlow.verify).sendPhoneCode(_number),
          throwsSendFailure(SendPhoneCodeFailureReason.invalidNumber),
        );
      });

      test('throws an unknown failure on any other exception', () {
        when(
          () => firebaseAuth.verifyPhoneNumber(
            phoneNumber: any(named: 'phoneNumber'),
            forceResendingToken: any(named: 'forceResendingToken'),
            verificationCompleted: any(named: 'verificationCompleted'),
            verificationFailed: any(named: 'verificationFailed'),
            codeSent: any(named: 'codeSent'),
            codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
          ),
        ).thenThrow(Exception('boom'));

        expect(
          subjectWith(PhoneSignInFlow.verify).sendPhoneCode(_number),
          throwsSendFailure(SendPhoneCodeFailureReason.unknown),
        );
      });
    });

    group('resending', () {
      final first = PhoneVerification(
        phoneNumber: _number,
        sentAt: _start,
        verificationId: 'verification-id',
        resendToken: 7,
      );

      test('throws ${SendPhoneCodeFailureReason.tooSoon} and sends nothing '
          'before the cooldown ends', () {
        now = _start.add(const Duration(seconds: 29));

        expect(
          subjectWith(PhoneSignInFlow.verify)
              .sendPhoneCode(_number, resending: first),
          throwsSendFailure(SendPhoneCodeFailureReason.tooSoon),
        );
        verifyNever(
          () => firebaseAuth.verifyPhoneNumber(
            phoneNumber: any(named: 'phoneNumber'),
            verificationCompleted: any(named: 'verificationCompleted'),
            verificationFailed: any(named: 'verificationFailed'),
            codeSent: any(named: 'codeSent'),
            codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
          ),
        );
      });

      test('throws ${SendPhoneCodeFailureReason.tooSoon} after the last '
          'resend', () {
        now = _start.add(const Duration(hours: 1));

        expect(
          subjectWith(PhoneSignInFlow.verify).sendPhoneCode(
            _number,
            resending: PhoneVerification(
              phoneNumber: _number,
              sentAt: _start,
              sends: 4,
            ),
          ),
          throwsSendFailure(SendPhoneCodeFailureReason.tooSoon),
        );
      });

      test('sends again with the resend token once the cooldown ends, '
          'counting the codes', () async {
        now = _start.add(const Duration(seconds: 30));
        whenVerify(({required completed, required failed, required codeSent}) {
          codeSent('second-id', 8);
        });

        final second = await subjectWith(PhoneSignInFlow.verify)
            .sendPhoneCode(_number, resending: first);

        expect(second?.sends, equals(2));
        expect(second?.sentAt, equals(now));
        expect(second?.verificationId, equals('second-id'));
        verify(
          () => firebaseAuth.verifyPhoneNumber(
            phoneNumber: _e164,
            forceResendingToken: 7,
            verificationCompleted: any(named: 'verificationCompleted'),
            verificationFailed: any(named: 'verificationFailed'),
            codeSent: any(named: 'codeSent'),
            codeAutoRetrievalTimeout: any(named: 'codeAutoRetrievalTimeout'),
          ),
        ).called(1);
      });
    });

    group('sendPhoneCode on ${PhoneSignInFlow.confirmation}', () {
      test('returns the verification holding the confirmation', () async {
        final confirmation = _MockConfirmationResult();
        when(() => firebaseAuth.signInWithPhoneNumber(any()))
            .thenAnswer((_) async => confirmation);

        final verification = await subjectWith(PhoneSignInFlow.confirmation)
            .sendPhoneCode(_number);

        expect(verification?.confirmation, same(confirmation));
        expect(verification?.sentAt, equals(_start));
        verify(() => firebaseAuth.signInWithPhoneNumber(_e164)).called(1);
      });

      test('throws the mapped failure', () {
        when(() => firebaseAuth.signInWithPhoneNumber(any())).thenThrow(
          firebase_auth.FirebaseAuthException(code: 'captcha-check-failed'),
        );

        expect(
          subjectWith(PhoneSignInFlow.confirmation).sendPhoneCode(_number),
          throwsSendFailure(SendPhoneCodeFailureReason.unavailable),
        );
      });
    });

    group('confirmPhoneCode', () {
      test('confirms the code on the web confirmation', () async {
        final confirmation = _MockConfirmationResult();
        when(() => confirmation.confirm(any()))
            .thenAnswer((_) async => _MockUserCredential());

        await subjectWith(PhoneSignInFlow.confirmation).confirmPhoneCode(
          PhoneVerification(
            phoneNumber: _number,
            sentAt: _start,
            confirmation: confirmation,
          ),
          '123456',
        );

        verify(() => confirmation.confirm('123456')).called(1);
        verifyNever(() => firebaseAuth.signInWithCredential(any()));
      });

      test('signs in with a phone credential on phones', () async {
        await subjectWith(PhoneSignInFlow.verify).confirmPhoneCode(
          PhoneVerification(
            phoneNumber: _number,
            sentAt: _start,
            verificationId: 'verification-id',
          ),
          '123456',
        );

        final used =
            verify(() => firebaseAuth.signInWithCredential(captureAny()))
                    .captured
                    .single
                as firebase_auth.PhoneAuthCredential;
        expect(used.verificationId, equals('verification-id'));
        expect(used.smsCode, equals('123456'));
      });

      test('throws an unknown failure with no verification id', () {
        expect(
          subjectWith(PhoneSignInFlow.verify).confirmPhoneCode(
            PhoneVerification(phoneNumber: _number, sentAt: _start),
            '123456',
          ),
          throwsConfirmFailure(ConfirmPhoneCodeFailureReason.unknown),
        );
      });

      test('throws the mapped failure for a wrong code', () {
        when(() => firebaseAuth.signInWithCredential(any())).thenThrow(
          firebase_auth.FirebaseAuthException(
            code: 'invalid-verification-code',
          ),
        );

        expect(
          subjectWith(PhoneSignInFlow.verify).confirmPhoneCode(
            PhoneVerification(
              phoneNumber: _number,
              sentAt: _start,
              verificationId: 'verification-id',
            ),
            '000000',
          ),
          throwsConfirmFailure(ConfirmPhoneCodeFailureReason.invalidCode),
        );
      });

      test('throws an unknown failure on any other exception', () {
        when(() => firebaseAuth.signInWithCredential(any()))
            .thenThrow(Exception('boom'));

        expect(
          subjectWith(PhoneSignInFlow.verify).confirmPhoneCode(
            PhoneVerification(
              phoneNumber: _number,
              sentAt: _start,
              verificationId: 'verification-id',
            ),
            '123456',
          ),
          throwsConfirmFailure(ConfirmPhoneCodeFailureReason.unknown),
        );
      });
    });
  });
}
