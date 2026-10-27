import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/app/app.dart';

class _MockAuthRepository extends Mock implements AuthRepository;

const _user = User(id: 'demo-uid');

void main() {
  group(AppBloc, () {
    late AuthRepository authRepository;

    setUp(() {
      authRepository = _MockAuthRepository();
      when(() => authRepository.currentUser).thenReturn(User.empty);
      when(() => authRepository.user)
          .thenAnswer((_) => const Stream<User>.empty());
    });

    test('starts unauthenticated when nobody is signed in', () {
      expect(
        AppBloc(authRepository: authRepository).state,
        equals(const AppState(status: AppStatus.unauthenticated)),
      );
    });

    test('starts authenticated when someone is already signed in', () {
      when(() => authRepository.currentUser).thenReturn(_user);

      expect(
        AppBloc(authRepository: authRepository).state,
        equals(const AppState(status: AppStatus.authenticated, user: _user)),
      );
    });

    group(AppUserSubscriptionRequested, () {
      blocTest<AppBloc, AppState>(
        'emits authenticated then unauthenticated as the person signs in '
        'and out',
        setUp: () {
          when(() => authRepository.user)
              .thenAnswer((_) => Stream.fromIterable([_user, User.empty]));
        },
        build: () => AppBloc(authRepository: authRepository),
        act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
        expect: () => const [
          AppState(status: AppStatus.authenticated, user: _user),
          AppState(status: AppStatus.unauthenticated),
        ],
      );

      blocTest<AppBloc, AppState>(
        'adds the error when the user stream fails',
        setUp: () {
          when(() => authRepository.user)
              .thenAnswer((_) => Stream.error(Exception('boom')));
        },
        build: () => AppBloc(authRepository: authRepository),
        act: (bloc) => bloc.add(const AppUserSubscriptionRequested()),
        expect: () => const <AppState>[],
        errors: () => [isA<Exception>()],
      );
    });
  });

  group(AppState, () {
    group('fromUser', () {
      test('is unauthenticated for ${User.empty}', () {
        expect(
          AppState.fromUser(User.empty),
          equals(const AppState(status: AppStatus.unauthenticated)),
        );
      });

      test('is authenticated for a signed-in $User', () {
        expect(
          AppState.fromUser(_user),
          equals(const AppState(status: AppStatus.authenticated, user: _user)),
        );
      });
    });
  });

  group(AppUserSubscriptionRequested, () {
    test('carries no props', () {
      expect(const AppUserSubscriptionRequested().props, isEmpty);
    });
  });
}
