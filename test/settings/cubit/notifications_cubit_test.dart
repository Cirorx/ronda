import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda/settings/settings.dart';

class _MockPushRepository extends Mock implements PushRepository;

const _uid = 'demo-uid';

void main() {
  group(NotificationsCubit, () {
    late PushRepository pushRepository;

    setUp(() {
      pushRepository = _MockPushRepository();
      when(() => pushRepository.registerDevice(any())).thenAnswer((_) async {});
      when(pushRepository.clearPromptSnooze).thenAnswer((_) async {});
    });

    NotificationsCubit build() =>
        NotificationsCubit(uid: _uid, pushRepository: pushRepository);

    NotificationsState state(NotificationsStatus status) =>
        NotificationsState(status: status);

    void permissionIs(PushPermission permission) =>
        when(pushRepository.permission).thenAnswer((_) async => permission);

    void answerIs(PushPermission permission) =>
        when(pushRepository.askPermission).thenAnswer((_) async => permission);

    test('starts checking, with no button', () {
      expect(build().state, equals(const NotificationsState()));
      expect(const NotificationsState().canTurnOn, isFalse);
    });

    group('canTurnOn', () {
      for (final (status, expected) in [
        (NotificationsStatus.checking, false),
        (NotificationsStatus.on, false),
        (NotificationsStatus.off, true),
        (NotificationsStatus.asking, true),
        (NotificationsStatus.refused, true),
        (NotificationsStatus.blocked, false),
        (NotificationsStatus.unknown, true),
      ]) {
        test('is $expected when $status', () {
          expect(state(status).canTurnOn, equals(expected));
        });
      }
    });

    group('started', () {
      blocTest<NotificationsCubit, NotificationsState>(
        'says they are on, without saving the token again, when allowed',
        setUp: () => permissionIs(PushPermission.allowed),
        build: build,
        act: (cubit) => cubit.started(),
        expect: () => [state(NotificationsStatus.on)],
        verify: (_) {
          verifyNever(() => pushRepository.registerDevice(any()));
          verifyNever(pushRepository.askPermission);
        },
      );

      for (final permission in [
        PushPermission.notAsked,
        PushPermission.refused,
      ]) {
        blocTest<NotificationsCubit, NotificationsState>(
          'says they are off when the permission is $permission',
          setUp: () => permissionIs(permission),
          build: build,
          act: (cubit) => cubit.started(),
          expect: () => [state(NotificationsStatus.off)],
        );
      }

      blocTest<NotificationsCubit, NotificationsState>(
        'says the phone refused for good when blocked',
        setUp: () => permissionIs(PushPermission.blocked),
        build: build,
        act: (cubit) => cubit.started(),
        expect: () => [state(NotificationsStatus.blocked)],
      );

      blocTest<NotificationsCubit, NotificationsState>(
        'reports a permission that cannot be read',
        setUp: () =>
            when(pushRepository.permission)
                .thenThrow(const PushPermissionFailure()),
        build: build,
        act: (cubit) => cubit.started(),
        expect: () => [state(NotificationsStatus.unknown)],
        errors: () => [isA<PushPermissionFailure>()],
      );

      blocTest<NotificationsCubit, NotificationsState>(
        'saves the token when they were turned on in the phone settings',
        setUp: () => permissionIs(PushPermission.allowed),
        build: build,
        seed: () => state(NotificationsStatus.blocked),
        act: (cubit) => cubit.started(),
        expect: () => [state(NotificationsStatus.on)],
        verify: (_) =>
            verify(() => pushRepository.registerDevice(_uid)).called(1),
      );

      blocTest<NotificationsCubit, NotificationsState>(
        'keeps a "no" just given when the app comes back still off',
        setUp: () => permissionIs(PushPermission.refused),
        build: build,
        seed: () => state(NotificationsStatus.refused),
        act: (cubit) => cubit.started(),
        expect: () => const <NotificationsState>[],
      );

      blocTest<NotificationsCubit, NotificationsState>(
        'does nothing while the system prompt is open',
        build: build,
        seed: () => state(NotificationsStatus.asking),
        act: (cubit) => cubit.started(),
        expect: () => const <NotificationsState>[],
        verify: (_) => verifyNever(pushRepository.permission),
      );

      blocTest<NotificationsCubit, NotificationsState>(
        'emits nothing once closed',
        setUp: () => when(pushRepository.permission).thenAnswer(
          (_) => Future.delayed(Duration.zero, () => PushPermission.allowed),
        ),
        build: build,
        act: (cubit) async {
          final read = cubit.started();
          await cubit.close();
          await read;
        },
        expect: () => const <NotificationsState>[],
      );

      blocTest<NotificationsCubit, NotificationsState>(
        'emits no failure once closed',
        setUp: () => when(pushRepository.permission).thenAnswer(
          (_) => Future.delayed(
            Duration.zero,
            () => throw const PushPermissionFailure(),
          ),
        ),
        build: build,
        act: (cubit) async {
          final read = cubit.started();
          await cubit.close();
          await read;
        },
        expect: () => const <NotificationsState>[],
      );
    });

    group('turnOnTapped', () {
      blocTest<NotificationsCubit, NotificationsState>(
        'forgets "Ahora no", asks, and saves the token when allowed',
        setUp: () => answerIs(PushPermission.allowed),
        build: build,
        seed: () => state(NotificationsStatus.off),
        act: (cubit) => cubit.turnOnTapped(),
        expect: () => [
          state(NotificationsStatus.asking),
          state(NotificationsStatus.on),
        ],
        verify: (_) {
          verifyInOrder([
            pushRepository.clearPromptSnooze,
            pushRepository.askPermission,
            () => pushRepository.registerDevice(_uid),
          ]);
        },
      );

      blocTest<NotificationsCubit, NotificationsState>(
        'still asks when "Ahora no" cannot be forgotten, and reports it',
        setUp: () {
          when(pushRepository.clearPromptSnooze)
              .thenThrow(const SnoozePromptFailure());
          answerIs(PushPermission.allowed);
        },
        build: build,
        act: (cubit) => cubit.turnOnTapped(),
        expect: () => [
          state(NotificationsStatus.asking),
          state(NotificationsStatus.on),
        ],
        errors: () => [isA<SnoozePromptFailure>()],
      );

      blocTest<NotificationsCubit, NotificationsState>(
        'reports a token that cannot be saved, and stays on',
        setUp: () {
          answerIs(PushPermission.allowed);
          when(() => pushRepository.registerDevice(any()))
              .thenThrow(const RegisterDeviceFailure());
        },
        build: build,
        act: (cubit) => cubit.turnOnTapped(),
        expect: () => [
          state(NotificationsStatus.asking),
          state(NotificationsStatus.on),
        ],
        errors: () => [isA<RegisterDeviceFailure>()],
      );

      for (final permission in [
        PushPermission.notAsked,
        PushPermission.refused,
      ]) {
        blocTest<NotificationsCubit, NotificationsState>(
          'says they are still off when the answer is $permission',
          setUp: () => answerIs(permission),
          build: build,
          act: (cubit) => cubit.turnOnTapped(),
          expect: () => [
            state(NotificationsStatus.asking),
            state(NotificationsStatus.refused),
          ],
          verify: (_) =>
              verifyNever(() => pushRepository.registerDevice(any())),
        );
      }

      blocTest<NotificationsCubit, NotificationsState>(
        'says the phone refused for good when the answer is blocked',
        setUp: () => answerIs(PushPermission.blocked),
        build: build,
        act: (cubit) => cubit.turnOnTapped(),
        expect: () => [
          state(NotificationsStatus.asking),
          state(NotificationsStatus.blocked),
        ],
      );

      blocTest<NotificationsCubit, NotificationsState>(
        'reports a prompt that fails',
        setUp: () =>
            when(pushRepository.askPermission)
                .thenThrow(const PushPermissionFailure()),
        build: build,
        act: (cubit) => cubit.turnOnTapped(),
        expect: () => [
          state(NotificationsStatus.asking),
          state(NotificationsStatus.unknown),
        ],
        errors: () => [isA<PushPermissionFailure>()],
      );

      blocTest<NotificationsCubit, NotificationsState>(
        'emits nothing after asking once closed',
        setUp: () => when(pushRepository.askPermission).thenAnswer(
          (_) => Future.delayed(Duration.zero, () => PushPermission.allowed),
        ),
        build: build,
        act: (cubit) async {
          final asking = cubit.turnOnTapped();
          await Future<void>.delayed(Duration.zero);
          await cubit.close();
          await asking;
        },
        expect: () => [state(NotificationsStatus.asking)],
        verify: (_) => verifyNever(() => pushRepository.registerDevice(any())),
      );

      blocTest<NotificationsCubit, NotificationsState>(
        'emits no failure after asking once closed',
        setUp: () => when(pushRepository.askPermission).thenAnswer(
          (_) => Future.delayed(
            Duration.zero,
            () => throw const PushPermissionFailure(),
          ),
        ),
        build: build,
        act: (cubit) async {
          final asking = cubit.turnOnTapped();
          await Future<void>.delayed(Duration.zero);
          await cubit.close();
          await asking;
        },
        expect: () => [state(NotificationsStatus.asking)],
      );
    });
  });
}
