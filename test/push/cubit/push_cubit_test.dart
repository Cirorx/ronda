import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda/push/push.dart';

class _MockPushRepository extends Mock implements PushRepository;

const _uid = 'demo-uid';

void main() {
  group(PushCubit, () {
    late PushRepository pushRepository;
    late StreamController<void> registrations;

    setUp(() {
      pushRepository = _MockPushRepository();
      registrations = StreamController<void>.broadcast();
      addTearDown(registrations.close);
      when(() => pushRepository.registerDevice(any())).thenAnswer((_) async {});
      when(() => pushRepository.keepDeviceRegistered(any()))
          .thenAnswer((_) => registrations.stream);
    });

    PushCubit build() => PushCubit(uid: _uid, pushRepository: pushRepository);

    PushState state(PushStatus status) => PushState(status: status);

    test('starts checking, with no card', () {
      final cubit = build();
      expect(cubit.state, equals(const PushState()));
      expect(cubit.state.showsPrompt, isFalse);
      unawaited(cubit.close());
    });

    group('started', () {
      blocTest<PushCubit, PushState>(
        'saves the token and keeps it fresh when notifications are allowed',
        setUp: () =>
            when(pushRepository.permission)
                .thenAnswer((_) async => PushPermission.allowed),
        build: build,
        act: (cubit) => cubit.started(),
        expect: () => [state(PushStatus.allowed)],
        verify: (_) {
          verify(() => pushRepository.registerDevice(_uid)).called(1);
          verify(() => pushRepository.keepDeviceRegistered(_uid)).called(1);
        },
      );

      for (final permission in [
        PushPermission.notAsked,
        PushPermission.refused,
      ]) {
        blocTest<PushCubit, PushState>(
          'offers the card when the permission is $permission',
          setUp: () =>
              when(pushRepository.permission)
                  .thenAnswer((_) async => permission),
          build: build,
          act: (cubit) => cubit.started(),
          expect: () => [state(PushStatus.offered)],
          verify: (cubit) {
            expect(cubit.state.showsPrompt, isTrue);
            verifyNever(() => pushRepository.registerDevice(any()));
            verifyNever(pushRepository.askPermission);
          },
        );
      }

      blocTest<PushCubit, PushState>(
        'shows nothing when the phone refused for good before',
        setUp: () =>
            when(pushRepository.permission)
                .thenAnswer((_) async => PushPermission.blocked),
        build: build,
        act: (cubit) => cubit.started(),
        expect: () => [state(PushStatus.dismissed)],
      );

      blocTest<PushCubit, PushState>(
        'shows nothing and reports it when the permission cannot be read',
        setUp: () =>
            when(pushRepository.permission)
                .thenThrow(const PushPermissionFailure()),
        build: build,
        act: (cubit) => cubit.started(),
        expect: () => [state(PushStatus.dismissed)],
        errors: () => [isA<PushPermissionFailure>()],
      );

      blocTest<PushCubit, PushState>(
        'stays allowed and reports it when the token cannot be saved',
        setUp: () {
          when(pushRepository.permission)
              .thenAnswer((_) async => PushPermission.allowed);
          when(() => pushRepository.registerDevice(any()))
              .thenThrow(const RegisterDeviceFailure());
        },
        build: build,
        act: (cubit) => cubit.started(),
        expect: () => [state(PushStatus.allowed)],
        errors: () => [isA<RegisterDeviceFailure>()],
      );

      blocTest<PushCubit, PushState>(
        'reports a refreshed token that cannot be saved',
        setUp: () =>
            when(pushRepository.permission)
                .thenAnswer((_) async => PushPermission.allowed),
        build: build,
        act: (cubit) async {
          await cubit.started();
          registrations.addError(const RegisterDeviceFailure());
        },
        expect: () => [state(PushStatus.allowed)],
        errors: () => [isA<RegisterDeviceFailure>()],
      );

      blocTest<PushCubit, PushState>(
        'emits nothing when closed before the permission is read',
        setUp: () => when(pushRepository.permission).thenAnswer((_) async {
          await Future<void>.delayed(Duration.zero);
          return PushPermission.allowed;
        }),
        build: build,
        act: (cubit) {
          unawaited(cubit.started());
          return cubit.close();
        },
        expect: () => <PushState>[],
        verify: (_) => verifyNever(() => pushRepository.registerDevice(any())),
      );

      blocTest<PushCubit, PushState>(
        'emits nothing when closed before a failed read returns',
        setUp: () => when(pushRepository.permission).thenAnswer((_) async {
          await Future<void>.delayed(Duration.zero);
          throw const PushPermissionFailure();
        }),
        build: build,
        act: (cubit) {
          unawaited(cubit.started());
          return cubit.close();
        },
        expect: () => <PushState>[],
      );

      blocTest<PushCubit, PushState>(
        'does not keep the token fresh when closed while saving it',
        setUp: () {
          when(pushRepository.permission)
              .thenAnswer((_) async => PushPermission.allowed);
          when(() => pushRepository.registerDevice(any()))
              .thenAnswer((_) => Future<void>.delayed(Duration.zero));
        },
        build: build,
        act: (cubit) async {
          unawaited(cubit.started());
          await Future<void>.delayed(Duration.zero);
          await cubit.close();
        },
        expect: () => [state(PushStatus.allowed)],
        verify: (_) =>
            verifyNever(() => pushRepository.keepDeviceRegistered(any())),
      );
    });

    group('allowTapped', () {
      blocTest<PushCubit, PushState>(
        'asks, then saves the token when allowed',
        setUp: () =>
            when(pushRepository.askPermission)
                .thenAnswer((_) async => PushPermission.allowed),
        build: build,
        seed: () => state(PushStatus.offered),
        act: (cubit) => cubit.allowTapped(),
        expect: () => [state(PushStatus.requesting), state(PushStatus.allowed)],
        verify: (_) =>
            verify(() => pushRepository.registerDevice(_uid)).called(1),
      );

      blocTest<PushCubit, PushState>(
        'says how to turn them on when the phone refuses without asking',
        setUp: () =>
            when(pushRepository.askPermission)
                .thenAnswer((_) async => PushPermission.blocked),
        build: build,
        seed: () => state(PushStatus.offered),
        act: (cubit) => cubit.allowTapped(),
        expect: () => [state(PushStatus.requesting), state(PushStatus.blocked)],
        verify: (cubit) => expect(cubit.state.showsPrompt, isTrue),
      );

      for (final permission in [
        PushPermission.refused,
        PushPermission.notAsked,
      ]) {
        blocTest<PushCubit, PushState>(
          'hides the card when the answer is $permission',
          setUp: () =>
              when(pushRepository.askPermission)
                  .thenAnswer((_) async => permission),
          build: build,
          seed: () => state(PushStatus.offered),
          act: (cubit) => cubit.allowTapped(),
          expect: () => [
            state(PushStatus.requesting),
            state(PushStatus.dismissed),
          ],
          verify: (_) =>
              verifyNever(() => pushRepository.registerDevice(any())),
        );
      }

      blocTest<PushCubit, PushState>(
        'offers the card again and reports it when the prompt fails',
        setUp: () =>
            when(pushRepository.askPermission)
                .thenThrow(const PushPermissionFailure()),
        build: build,
        seed: () => state(PushStatus.offered),
        act: (cubit) => cubit.allowTapped(),
        expect: () => [state(PushStatus.requesting), state(PushStatus.offered)],
        errors: () => [isA<PushPermissionFailure>()],
      );

      blocTest<PushCubit, PushState>(
        'emits nothing more when closed while the prompt is open',
        setUp: () => when(pushRepository.askPermission).thenAnswer((_) async {
          await Future<void>.delayed(Duration.zero);
          return PushPermission.allowed;
        }),
        build: build,
        act: (cubit) {
          unawaited(cubit.allowTapped());
          return cubit.close();
        },
        expect: () => [state(PushStatus.requesting)],
      );

      blocTest<PushCubit, PushState>(
        'emits nothing more when closed before a failed prompt returns',
        setUp: () => when(pushRepository.askPermission).thenAnswer((_) async {
          await Future<void>.delayed(Duration.zero);
          throw const PushPermissionFailure();
        }),
        build: build,
        act: (cubit) {
          unawaited(cubit.allowTapped());
          return cubit.close();
        },
        expect: () => [state(PushStatus.requesting)],
      );
    });

    group('dismissed', () {
      blocTest<PushCubit, PushState>(
        'hides the card',
        build: build,
        seed: () => state(PushStatus.offered),
        act: (cubit) => cubit.dismissed(),
        expect: () => [state(PushStatus.dismissed)],
        verify: (cubit) => expect(cubit.state.showsPrompt, isFalse),
      );
    });
  });
}
