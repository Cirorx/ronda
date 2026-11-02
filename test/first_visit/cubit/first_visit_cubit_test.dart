import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/first_visit/first_visit.dart';
import 'package:ronda_repository/ronda_repository.dart';

import '../fixtures.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

const _uid = 'demo-105';

void main() {
  group(FirstVisitCubit, () {
    late RondaRepository repository;

    setUp(() {
      repository = _MockRondaRepository();
    });

    FirstVisitCubit build({DateTime? now, String uid = _uid}) =>
        FirstVisitCubit(
          uid: uid,
          rondaRepository: repository,
          now: () => now ?? DateTime(2026, 11, 3, 10),
        );

    void visit(FirstVisit? visit) =>
        when(() => repository.watchFirstVisit(any()))
            .thenAnswer((_) => Stream.value(visit));

    test('starts loading, with nothing to show', () {
      final state = build().state;

      expect(state.status, FirstVisitStatus.loading);
      expect(state.card, isNull);
      expect(state.toChoose, isEmpty);
      expect(state.waitingFor, isEmpty);
    });

    group('subscribe', () {
      blocTest<FirstVisitCubit, FirstVisitState>(
        'shows the newcomer their card two days before the meeting',
        setUp: () =>
            visit(FirstVisit(rondaId: 'r1', mine: FirstVisitFixtures.open)),
        build: build,
        act: (cubit) => cubit.subscribe(),
        expect: () => [
          FirstVisitState(
            status: FirstVisitStatus.ready,
            card: FirstVisitFixtures.open,
          ),
        ],
      );

      blocTest<FirstVisitCubit, FirstVisitState>(
        'keeps the card back until then',
        setUp: () =>
            visit(FirstVisit(rondaId: 'r1', mine: FirstVisitFixtures.open)),
        build: () => build(now: DateTime(2026, 11, 2, 23)),
        act: (cubit) => cubit.subscribe(),
        expect: () => [const FirstVisitState(status: FirstVisitStatus.ready)],
      );

      blocTest<FirstVisitCubit, FirstVisitState>(
        'shows the card and the questions through the meeting day, then '
        'none',
        setUp: () => visit(
          FirstVisit(
            rondaId: 'r1',
            mine: FirstVisitFixtures.open,
            toChoose: [FirstVisitFixtures.open],
          ),
        ),
        build: () => build(now: DateTime(2026, 11, 6, 8)),
        act: (cubit) => cubit.subscribe(),
        expect: () => [const FirstVisitState(status: FirstVisitStatus.ready)],
      );

      blocTest<FirstVisitCubit, FirstVisitState>(
        'gives a host their newcomers and a waiter what someone else picked',
        setUp: () => visit(
          FirstVisit(
            rondaId: 'r1',
            toChoose: [FirstVisitFixtures.open],
            waitingFor: [FirstVisitFixtures.picked],
          ),
        ),
        build: () => build(uid: 'demo-102', now: DateTime(2026, 10, 30)),
        act: (cubit) => cubit.subscribe(),
        expect: () => [
          FirstVisitState(
            status: FirstVisitStatus.ready,
            toChoose: [FirstVisitFixtures.open],
            waitingFor: [FirstVisitFixtures.picked],
          ),
        ],
      );

      blocTest<FirstVisitCubit, FirstVisitState>(
        'asks no "No puedo" of a host who picked themself',
        setUp: () => visit(
          FirstVisit(rondaId: 'r1', waitingFor: [FirstVisitFixtures.picked]),
        ),
        build: () => build(uid: 'demo-101'),
        act: (cubit) => cubit.subscribe(),
        expect: () => [const FirstVisitState(status: FirstVisitStatus.ready)],
      );

      blocTest<FirstVisitCubit, FirstVisitState>(
        'shows nothing outside a ronda',
        setUp: () => visit(null),
        build: build,
        act: (cubit) => cubit.subscribe(),
        expect: () => [const FirstVisitState(status: FirstVisitStatus.ready)],
      );

      blocTest<FirstVisitCubit, FirstVisitState>(
        'fails quietly when the stream errors',
        setUp: () => when(() => repository.watchFirstVisit(any())).thenAnswer(
          (_) => Stream.error(const WelcomeFailure(WelcomeFailureReason.other)),
        ),
        build: build,
        act: (cubit) => cubit.subscribe(),
        expect: () => [const FirstVisitState(status: FirstVisitStatus.failure)],
        errors: () => [isA<WelcomeFailure>()],
      );
    });

    group('picked', () {
      setUp(() {
        when(
          () => repository.setWelcome(
            rondaId: any(named: 'rondaId'),
            newcomerUid: any(named: 'newcomerUid'),
            waiterUid: any(named: 'waiterUid'),
            sign: any(named: 'sign'),
          ),
        ).thenAnswer((_) async {});
      });

      blocTest<FirstVisitCubit, FirstVisitState>(
        'saves the pick and the trimmed sign',
        build: build,
        act: (cubit) => cubit.picked(
          FirstVisitFixtures.open,
          waiterUid: 'demo-102',
          sign: '  tiene el termo verde ',
        ),
        expect: () => [
          const FirstVisitState(save: WelcomeSaveStatus.saving),
          const FirstVisitState(save: WelcomeSaveStatus.saved),
        ],
        verify: (_) => verify(
          () => repository.setWelcome(
            rondaId: 'r1',
            newcomerUid: 'demo-105',
            waiterUid: 'demo-102',
            sign: 'tiene el termo verde',
          ),
        ).called(1),
      );

      blocTest<FirstVisitCubit, FirstVisitState>(
        'says why the gates held the line',
        setUp: () => when(
          () => repository.setWelcome(
            rondaId: any(named: 'rondaId'),
            newcomerUid: any(named: 'newcomerUid'),
            waiterUid: any(named: 'waiterUid'),
            sign: any(named: 'sign'),
          ),
        ).thenThrow(const WelcomeFailure(WelcomeFailureReason.voseo)),
        build: build,
        act: (cubit) => cubit.picked(
          FirstVisitFixtures.open,
          waiterUid: 'demo-102',
          sign: 'tienes el termo',
        ),
        expect: () => [
          const FirstVisitState(save: WelcomeSaveStatus.saving),
          const FirstVisitState(
            save: WelcomeSaveStatus.failed,
            failure: WelcomeFailureReason.voseo,
          ),
        ],
        errors: () => [isA<WelcomeFailure>()],
      );

      blocTest<FirstVisitCubit, FirstVisitState>(
        'sends nothing while one is on its way',
        build: build,
        seed: () => const FirstVisitState(save: WelcomeSaveStatus.saving),
        act: (cubit) => cubit.picked(
          FirstVisitFixtures.open,
          waiterUid: 'demo-102',
          sign: '',
        ),
        expect: () => <FirstVisitState>[],
      );
    });

    blocTest<FirstVisitCubit, FirstVisitState>(
      'declined hands the choice back',
      setUp: () => when(
        () => repository.declineWelcome(
          rondaId: any(named: 'rondaId'),
          newcomerUid: any(named: 'newcomerUid'),
        ),
      ).thenAnswer((_) async {}),
      build: build,
      act: (cubit) => cubit.declined(FirstVisitFixtures.picked),
      expect: () => [
        const FirstVisitState(save: WelcomeSaveStatus.saving),
        const FirstVisitState(save: WelcomeSaveStatus.saved),
      ],
      verify: (_) => verify(
        () => repository.declineWelcome(rondaId: 'r1', newcomerUid: 'demo-105'),
      ).called(1),
    );

    blocTest<FirstVisitCubit, FirstVisitState>(
      'sheetOpened forgets the last save',
      build: build,
      seed: () => const FirstVisitState(
        save: WelcomeSaveStatus.failed,
        failure: WelcomeFailureReason.money,
      ),
      act: (cubit) => cubit.sheetOpened(),
      expect: () => [const FirstVisitState()],
    );

    for (final (name, finish) in <(String, void Function(Completer<void>))>[
      (
        'a failure',
        (call) => call.completeError(
          const WelcomeFailure(WelcomeFailureReason.passed),
        ),
      ),
      ('a save', (call) => call.complete()),
    ]) {
      test('$name that lands after close emits nothing', () async {
        final call = Completer<void>();
        when(
          () => repository.declineWelcome(
            rondaId: any(named: 'rondaId'),
            newcomerUid: any(named: 'newcomerUid'),
          ),
        ).thenAnswer((_) => call.future);
        final cubit = build();
        final pending = cubit.declined(FirstVisitFixtures.picked);
        await cubit.close();
        finish(call);
        await pending;

        expect(cubit.state.save, WelcomeSaveStatus.saving);
      });
    }
  });
}
