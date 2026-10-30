import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/login/login.dart';

class _MockAuthRepository extends Mock implements AuthRepository;

void main() {
  group(LoginCubit, () {
    late AuthRepository authRepository;

    setUp(() {
      authRepository = _MockAuthRepository();
    });

    test('starts at ${LoginStatus.initial}', () {
      expect(
        LoginCubit(authRepository: authRepository).state,
        equals(const LoginState()),
      );
    });

    group('signInWithGoogle', () {
      blocTest<LoginCubit, LoginState>(
        'emits [inProgress, success] when sign-in finishes',
        setUp: () {
          when(() => authRepository.signInWithGoogle())
              .thenAnswer((_) async {});
        },
        build: () => LoginCubit(authRepository: authRepository),
        act: (cubit) => cubit.signInWithGoogle(),
        expect: () => const [
          LoginState(status: LoginStatus.inProgress),
          LoginState(status: LoginStatus.success),
        ],
        verify: (_) {
          verify(() => authRepository.signInWithGoogle()).called(1);
        },
      );

      blocTest<LoginCubit, LoginState>(
        'emits [inProgress, initial] without an error when the person '
        'cancels',
        setUp: () {
          when(() => authRepository.signInWithGoogle()).thenThrow(
            const SignInWithGoogleFailure(
              SignInWithGoogleFailureReason.cancelled,
            ),
          );
        },
        build: () => LoginCubit(authRepository: authRepository),
        act: (cubit) => cubit.signInWithGoogle(),
        expect: () => const [
          LoginState(status: LoginStatus.inProgress),
          LoginState(),
        ],
      );

      blocTest<LoginCubit, LoginState>(
        'emits [inProgress, failure] with ${LoginError.network} when there '
        'is no connection',
        setUp: () {
          when(() => authRepository.signInWithGoogle()).thenThrow(
            const SignInWithGoogleFailure(
              SignInWithGoogleFailureReason.network,
            ),
          );
        },
        build: () => LoginCubit(authRepository: authRepository),
        act: (cubit) => cubit.signInWithGoogle(),
        expect: () => const [
          LoginState(status: LoginStatus.inProgress),
          LoginState(status: LoginStatus.failure, error: LoginError.network),
        ],
      );

      for (final reason in [
        SignInWithGoogleFailureReason.userDisabled,
        SignInWithGoogleFailureReason.unknown,
      ]) {
        blocTest<LoginCubit, LoginState>(
          'emits [inProgress, failure] with ${LoginError.other} on $reason',
          setUp: () {
            when(() => authRepository.signInWithGoogle())
                .thenThrow(SignInWithGoogleFailure(reason));
          },
          build: () => LoginCubit(authRepository: authRepository),
          act: (cubit) => cubit.signInWithGoogle(),
          expect: () => const [
            LoginState(status: LoginStatus.inProgress),
            LoginState(status: LoginStatus.failure, error: LoginError.other),
          ],
        );
      }

      blocTest<LoginCubit, LoginState>(
        'does nothing while a sign-in is already in progress',
        build: () => LoginCubit(authRepository: authRepository),
        seed: () => const LoginState(status: LoginStatus.inProgress),
        act: (cubit) => cubit.signInWithGoogle(),
        expect: () => const <LoginState>[],
        verify: (_) {
          verifyNever(() => authRepository.signInWithGoogle());
        },
      );
    });

    group('createAccountTapped', () {
      blocTest<LoginCubit, LoginState>(
        "opens Google's page to make an account, and emits nothing",
        setUp: () {
          when(() => authRepository.openCreateAccount())
              .thenAnswer((_) async {});
        },
        build: () => LoginCubit(authRepository: authRepository),
        act: (cubit) => cubit.createAccountTapped(),
        expect: () => const <LoginState>[],
        verify: (_) {
          verify(() => authRepository.openCreateAccount()).called(1);
        },
      );

      blocTest<LoginCubit, LoginState>(
        'reports the failure and emits nothing when no browser opens it',
        setUp: () {
          when(() => authRepository.openCreateAccount())
              .thenThrow(const OpenCreateAccountFailure());
        },
        build: () => LoginCubit(authRepository: authRepository),
        act: (cubit) => cubit.createAccountTapped(),
        expect: () => const <LoginState>[],
        errors: () => [isA<OpenCreateAccountFailure>()],
      );
    });
  });
}
