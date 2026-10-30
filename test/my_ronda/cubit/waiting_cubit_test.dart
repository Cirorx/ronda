import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/my_ronda/cubit/waiting_cubit.dart';
import 'package:ronda_repository/ronda_repository.dart';

import '../fixtures.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  setUpAll(() => registerFallbackValue(WaitlistChoice.join));

  group(WaitingCubit, () {
    late RondaRepository rondaRepository;
    late StreamController<Waiting?> lists;

    setUp(() {
      rondaRepository = _MockRondaRepository();
      lists = StreamController<Waiting?>.broadcast();
      addTearDown(lists.close);
      when(() => rondaRepository.watchWaiting(MyRondaFixtures.uid))
          .thenAnswer((_) => lists.stream);
      when(() => rondaRepository.chooseAfterWaitlist(any()))
          .thenAnswer((_) async {});
    });

    WaitingCubit build() => WaitingCubit(
      uid: MyRondaFixtures.uid,
      rondaRepository: rondaRepository,
    );

    final didntFill = WaitingState(
      status: WaitingCardStatus.ready,
      waiting: MyRondaFixtures.waiting(status: WaitingStatus.didntFill),
    );

    test('starts loading', () {
      expect(build().state, const WaitingState());
    });

    group('subscribe', () {
      blocTest<WaitingCubit, WaitingState>(
        'shows the list, or nothing while the person waits on none',
        build: build,
        act: (cubit) async {
          cubit.subscribe();
          lists.add(MyRondaFixtures.waiting());
          await Future<void>.delayed(Duration.zero);
          lists.add(null);
        },
        expect: () => [
          const WaitingState(),
          WaitingState(
            status: WaitingCardStatus.ready,
            waiting: MyRondaFixtures.waiting(),
          ),
          const WaitingState(status: WaitingCardStatus.none),
        ],
      );

      blocTest<WaitingCubit, WaitingState>(
        'says so when the list cannot be read',
        build: build,
        act: (cubit) {
          cubit.subscribe();
          lists.addError(const RsvpFailure(RsvpFailureReason.other));
        },
        expect: () => [
          const WaitingState(),
          const WaitingState(status: WaitingCardStatus.failure),
        ],
        errors: () => [isA<RsvpFailure>()],
      );
    });

    group('the pick', () {
      blocTest<WaitingCubit, WaitingState>(
        'joins another ronda',
        build: build,
        seed: () => didntFill,
        act: (cubit) => cubit.joinTapped(),
        expect: () => [didntFill.copyWith(saving: true), didntFill],
        verify: (_) => verify(
          () => rondaRepository.chooseAfterWaitlist(WaitlistChoice.join),
        ).called(1),
      );

      blocTest<WaitingCubit, WaitingState>(
        'waits two weeks more',
        build: build,
        seed: () => didntFill,
        act: (cubit) => cubit.waitTapped(),
        verify: (_) => verify(
          () => rondaRepository.chooseAfterWaitlist(WaitlistChoice.wait),
        ).called(1),
      );

      blocTest<WaitingCubit, WaitingState>(
        'does nothing without a list or while a pick is on its way',
        build: build,
        seed: () => didntFill.copyWith(saving: true),
        act: (cubit) async {
          await cubit.joinTapped();
          cubit.emit(const WaitingState());
          await cubit.waitTapped();
        },
        expect: () => [const WaitingState()],
        verify: (_) =>
            verifyNever(() => rondaRepository.chooseAfterWaitlist(any())),
      );

      blocTest<WaitingCubit, WaitingState>(
        'says it was not saved when it fails',
        setUp: () =>
            when(() => rondaRepository.chooseAfterWaitlist(any()))
                .thenThrow(const RsvpFailure(RsvpFailureReason.passed)),
        build: build,
        seed: () => didntFill,
        act: (cubit) => cubit.waitTapped(),
        expect: () => [
          didntFill.copyWith(saving: true),
          didntFill.copyWith(saveFailed: true),
        ],
        errors: () => [isA<RsvpFailure>()],
      );

      test('emits nothing once closed while picking', () async {
        final picked = Completer<void>();
        when(() => rondaRepository.chooseAfterWaitlist(any()))
            .thenAnswer((_) => picked.future);
        final cubit = build()..emit(didntFill);
        final picking = cubit.joinTapped();
        await cubit.close();
        picked.complete();
        await picking;

        final failing = build()..emit(didntFill);
        when(() => rondaRepository.chooseAfterWaitlist(any())).thenAnswer(
          (_) => Future.delayed(
            Duration.zero,
            () => throw const RsvpFailure(RsvpFailureReason.other),
          ),
        );
        final failed = failing.waitTapped();
        await failing.close();
        await failed;
        expect(failing.state.saving, isTrue);
      });
    });
  });
}
