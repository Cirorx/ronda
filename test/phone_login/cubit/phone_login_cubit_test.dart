import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/phone_login/phone_login.dart';

class _MockAuthRepository extends Mock implements AuthRepository;

// Invented numbers, nobody's phone.
const _typed = '099 000 001';
final PhoneNumber _number = PhoneNumber.tryParse(_typed)!;
final _start = DateTime.utc(2026, 11, 2, 10);

PhoneVerification _verification({int sends = 1, DateTime? sentAt}) =>
    PhoneVerification(
      phoneNumber: _number,
      sentAt: sentAt ?? _start,
      sends: sends,
      verificationId: 'verification-$sends',
    );

void main() {
  group(PhoneLoginCubit, () {
    late AuthRepository authRepository;

    setUpAll(() {
      registerFallbackValue(_number);
      registerFallbackValue(_verification());
    });

    setUp(() {
      authRepository = _MockAuthRepository();
    });

    PhoneLoginCubit build({DateTime Function()? now}) => PhoneLoginCubit(
      authRepository: authRepository,
      now: now ?? () => _start,
    );

    const typed = PhoneLoginState(number: PhoneNumberInput.dirty(_typed));

    test('starts on the number with +598 filled in', () {
      final state = build().state;

      expect(state, equals(const PhoneLoginState()));
      expect(state.number.value, equals('+598 '));
      expect(state.step, equals(PhoneLoginStep.number));
    });

    test('hides the number in its state toString', () {
      final state = typed.copyWith(verification: _verification());

      expect(state.toString(), isNot(contains('000')));
      expect(state.toString(), isNot(contains('598')));
    });

    group('numberChanged', () {
      blocTest<PhoneLoginCubit, PhoneLoginState>(
        'keeps the number and clears the error and the field message',
        build: build,
        seed: () => const PhoneLoginState(
          showInputError: true,
          error: PhoneLoginError.network,
        ),
        act: (cubit) => cubit.numberChanged(_typed),
        expect: () => [typed],
      );
    });

    group('sendCode', () {
      blocTest<PhoneLoginCubit, PhoneLoginState>(
        'shows why the number is not valid and sends nothing',
        build: build,
        seed: () =>
            const PhoneLoginState(number: PhoneNumberInput.dirty('2 000 0001')),
        act: (cubit) => cubit.sendCode(),
        expect: () => const [
          PhoneLoginState(
            number: PhoneNumberInput.dirty('2 000 0001'),
            showInputError: true,
          ),
        ],
        verify: (_) => verifyNever(() => authRepository.sendPhoneCode(any())),
      );

      blocTest<PhoneLoginCubit, PhoneLoginState>(
        'sends the code and opens the code step with the countdown',
        setUp: () =>
            when(() => authRepository.sendPhoneCode(_number))
                .thenAnswer((_) async => _verification()),
        build: build,
        seed: () => typed,
        act: (cubit) => cubit.sendCode(),
        expect: () => [
          typed.copyWith(status: PhoneLoginStatus.sending),
          typed.copyWith(
            step: PhoneLoginStep.code,
            verification: _verification(),
            secondsToResend: 30,
          ),
        ],
      );

      blocTest<PhoneLoginCubit, PhoneLoginState>(
        'ends in ${PhoneLoginStatus.success} when Android verifies without a '
        'code',
        setUp: () =>
            when(() => authRepository.sendPhoneCode(_number))
                .thenAnswer((_) async => null),
        build: build,
        seed: () => typed,
        act: (cubit) => cubit.sendCode(),
        expect: () => [
          typed.copyWith(status: PhoneLoginStatus.sending),
          typed.copyWith(status: PhoneLoginStatus.success),
        ],
      );

      blocTest<PhoneLoginCubit, PhoneLoginState>(
        'does nothing while a request is out',
        build: build,
        seed: () => typed.copyWith(status: PhoneLoginStatus.sending),
        act: (cubit) => cubit.sendCode(),
        expect: () => const <PhoneLoginState>[],
      );

      for (final (reason, error) in [
        (SendPhoneCodeFailureReason.cancelled, null),
        (
          SendPhoneCodeFailureReason.invalidNumber,
          PhoneLoginError.invalidNumber,
        ),
        (
          SendPhoneCodeFailureReason.tooManyRequests,
          PhoneLoginError.tooManyRequests,
        ),
        (SendPhoneCodeFailureReason.tooSoon, PhoneLoginError.tooManyRequests),
        (SendPhoneCodeFailureReason.unavailable, PhoneLoginError.unavailable),
        (SendPhoneCodeFailureReason.network, PhoneLoginError.network),
        (SendPhoneCodeFailureReason.unknown, PhoneLoginError.other),
      ]) {
        blocTest<PhoneLoginCubit, PhoneLoginState>(
          'says $error on $reason and stays on the number',
          setUp: () =>
              when(() => authRepository.sendPhoneCode(_number))
                  .thenThrow(SendPhoneCodeFailure(reason)),
          build: build,
          seed: () => typed,
          act: (cubit) => cubit.sendCode(),
          expect: () => [
            typed.copyWith(status: PhoneLoginStatus.sending),
            typed.copyWith(error: () => error),
          ],
        );
      }
    });

    group('countdown', () {
      test('counts down every second and stops at 0', () {
        fakeAsync((async) {
          when(() => authRepository.sendPhoneCode(_number))
              .thenAnswer((_) async => _verification());
          final cubit = build(now: () => _start.add(async.elapsed))
            ..numberChanged(_typed);
          unawaited(cubit.sendCode());
          async.flushMicrotasks();
          expect(cubit.state.secondsToResend, equals(30));

          async.elapse(const Duration(seconds: 1));
          expect(cubit.state.secondsToResend, equals(29));

          async.elapse(const Duration(seconds: 29));
          expect(cubit.state.secondsToResend, equals(0));
          expect(async.periodicTimerCount, equals(0));
          unawaited(cubit.close());
        });
      });

      test('stops when the cubit closes', () {
        fakeAsync((async) {
          when(() => authRepository.sendPhoneCode(_number))
              .thenAnswer((_) async => _verification());
          final cubit = build(now: () => _start.add(async.elapsed))
            ..numberChanged(_typed);
          unawaited(cubit.sendCode());
          async.flushMicrotasks();

          unawaited(cubit.close());
          async.flushMicrotasks();

          expect(async.periodicTimerCount, equals(0));
        });
      });

      test('starts no timer when another code may be asked for at once', () {
        fakeAsync((async) {
          when(() => authRepository.sendPhoneCode(_number))
              .thenAnswer((_) async => _verification());
          final cubit = build(now: () => _start.add(const Duration(minutes: 1)))
            ..numberChanged(_typed);
          unawaited(cubit.sendCode());
          async.flushMicrotasks();

          expect(cubit.state.secondsToResend, equals(0));
          expect(async.periodicTimerCount, equals(0));
          unawaited(cubit.close());
        });
      });
    });

    group('resendCode', () {
      final onCode = typed.copyWith(
        step: PhoneLoginStep.code,
        verification: _verification(),
        code: const SmsCode.dirty('12'),
      );

      blocTest<PhoneLoginCubit, PhoneLoginState>(
        'sends another code once the wait is over, saying so',
        setUp: () => when(
          () =>
              authRepository.sendPhoneCode(_number, resending: _verification()),
        ).thenAnswer((_) async => _verification(sends: 2)),
        build: build,
        seed: () => onCode,
        act: (cubit) => cubit.resendCode(),
        expect: () => [
          onCode.copyWith(status: PhoneLoginStatus.sending),
          onCode.copyWith(
            verification: _verification(sends: 2),
            code: const SmsCode.pure(),
            resent: true,
            secondsToResend: 60,
          ),
        ],
      );

      blocTest<PhoneLoginCubit, PhoneLoginState>(
        'does nothing during the wait',
        build: build,
        seed: () => onCode.copyWith(secondsToResend: 3),
        act: (cubit) => cubit.resendCode(),
        expect: () => const <PhoneLoginState>[],
      );

      blocTest<PhoneLoginCubit, PhoneLoginState>(
        'does nothing after the last code',
        build: build,
        seed: () => onCode.copyWith(verification: _verification(sends: 4)),
        act: (cubit) => cubit.resendCode(),
        expect: () => const <PhoneLoginState>[],
      );

      blocTest<PhoneLoginCubit, PhoneLoginState>(
        'does nothing before a code was sent',
        build: build,
        seed: () => typed,
        act: (cubit) => cubit.resendCode(),
        expect: () => const <PhoneLoginState>[],
      );
    });

    group('confirmCode', () {
      final onCode = typed.copyWith(
        step: PhoneLoginStep.code,
        verification: _verification(),
      );

      blocTest<PhoneLoginCubit, PhoneLoginState>(
        'keeps the code and clears the error on codeChanged',
        build: build,
        seed: () => onCode.copyWith(error: () => PhoneLoginError.wrongCode),
        act: (cubit) => cubit.codeChanged('123 456'),
        expect: () => [onCode.copyWith(code: const SmsCode.dirty('123 456'))],
      );

      blocTest<PhoneLoginCubit, PhoneLoginState>(
        'checks the digits and ends in ${PhoneLoginStatus.success}',
        setUp: () => when(
          () => authRepository.confirmPhoneCode(_verification(), '123456'),
        ).thenAnswer((_) async {}),
        build: build,
        seed: () => onCode.copyWith(code: const SmsCode.dirty('123 456')),
        act: (cubit) => cubit.confirmCode(),
        expect: () => [
          onCode.copyWith(
            code: const SmsCode.dirty('123 456'),
            status: PhoneLoginStatus.confirming,
          ),
          onCode.copyWith(
            code: const SmsCode.dirty('123 456'),
            status: PhoneLoginStatus.success,
          ),
        ],
      );

      blocTest<PhoneLoginCubit, PhoneLoginState>(
        'shows why the code is not valid and checks nothing',
        build: build,
        seed: () => onCode.copyWith(code: const SmsCode.dirty('12')),
        act: (cubit) => cubit.confirmCode(),
        expect: () => [
          onCode.copyWith(
            code: const SmsCode.dirty('12'),
            showInputError: true,
          ),
        ],
        verify: (_) =>
            verifyNever(() => authRepository.confirmPhoneCode(any(), any())),
      );

      blocTest<PhoneLoginCubit, PhoneLoginState>(
        'does nothing before a code was sent',
        build: build,
        seed: () => typed,
        act: (cubit) => cubit.confirmCode(),
        expect: () => const <PhoneLoginState>[],
      );

      for (final (reason, error) in [
        (ConfirmPhoneCodeFailureReason.invalidCode, PhoneLoginError.wrongCode),
        (ConfirmPhoneCodeFailureReason.expired, PhoneLoginError.expiredCode),
        (
          ConfirmPhoneCodeFailureReason.tooManyRequests,
          PhoneLoginError.tooManyRequests,
        ),
        (ConfirmPhoneCodeFailureReason.network, PhoneLoginError.network),
        (ConfirmPhoneCodeFailureReason.userDisabled, PhoneLoginError.other),
        (ConfirmPhoneCodeFailureReason.unknown, PhoneLoginError.other),
      ]) {
        blocTest<PhoneLoginCubit, PhoneLoginState>(
          'says $error on $reason',
          setUp: () =>
              when(() => authRepository.confirmPhoneCode(any(), any()))
                  .thenThrow(ConfirmPhoneCodeFailure(reason)),
          build: build,
          seed: () => onCode.copyWith(code: const SmsCode.dirty('123456')),
          act: (cubit) => cubit.confirmCode(),
          expect: () => [
            onCode.copyWith(
              code: const SmsCode.dirty('123456'),
              status: PhoneLoginStatus.confirming,
            ),
            onCode.copyWith(
              code: const SmsCode.dirty('123456'),
              error: () => error,
            ),
          ],
        );
      }
    });

    group('changeNumber', () {
      blocTest<PhoneLoginCubit, PhoneLoginState>(
        'goes back to the number, still typed',
        build: build,
        seed: () => typed.copyWith(
          step: PhoneLoginStep.code,
          verification: _verification(),
          secondsToResend: 12,
          error: () => PhoneLoginError.wrongCode,
        ),
        act: (cubit) => cubit.changeNumber(),
        expect: () => [typed],
      );

      blocTest<PhoneLoginCubit, PhoneLoginState>(
        'does nothing while a request is out',
        build: build,
        seed: () => typed.copyWith(
          step: PhoneLoginStep.code,
          status: PhoneLoginStatus.confirming,
        ),
        act: (cubit) => cubit.changeNumber(),
        expect: () => const <PhoneLoginState>[],
      );
    });
  });
}
