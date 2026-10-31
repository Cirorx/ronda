import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:donde_queda_repository/donde_queda_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/donde_queda/cubit/donde_queda_cubit.dart';

import '../fixtures.dart';

class _MockDondeQuedaRepository extends Mock implements DondeQuedaRepository;

void main() {
  group(DondeQuedaCubit, () {
    late DondeQuedaRepository repository;
    late StreamController<DondeQuedaWeek> weeks;

    final myTurn = DondeQuedaWeek(game: DondeQuedaFixtures.game());

    setUp(() {
      repository = _MockDondeQuedaRepository();
      weeks = StreamController();
      when(
        () => repository.watch(
          rondaId: DondeQuedaFixtures.rondaId,
          uid: DondeQuedaFixtures.uid,
        ),
      ).thenAnswer((_) => weeks.stream);
    });

    DondeQuedaCubit build() => DondeQuedaCubit(
      rondaId: DondeQuedaFixtures.rondaId,
      uid: DondeQuedaFixtures.uid,
      dondeQuedaRepository: repository,
    );

    test('starts loading', () {
      expect(build().state, const DondeQuedaState());
    });

    blocTest<DondeQuedaCubit, DondeQuedaState>(
      'follows the game',
      build: build,
      act: (cubit) {
        cubit.subscribe();
        weeks.add(myTurn);
      },
      expect: () => [
        DondeQuedaState(status: DondeQuedaLoad.ready, week: myTurn),
      ],
    );

    blocTest<DondeQuedaCubit, DondeQuedaState>(
      'says when it could not be read',
      build: build,
      act: (cubit) {
        cubit.subscribe();
        weeks.addError(Exception('denied'));
      },
      expect: () => const [DondeQuedaState(status: DondeQuedaLoad.failure)],
      errors: () => [isException],
    );

    group('passTapped', () {
      DondeQuedaCubit ready(DondeQuedaWeek week) =>
          build()
            ..emit(DondeQuedaState(status: DondeQuedaLoad.ready, week: week));

      blocTest<DondeQuedaCubit, DondeQuedaState>(
        'passes the turn',
        setUp: () => when(
          () => repository.pass(
            rondaId: DondeQuedaFixtures.rondaId,
            week: DondeQuedaFixtures.week,
          ),
        ).thenAnswer((_) async {}),
        build: () => ready(myTurn),
        act: (cubit) => cubit.passTapped(),
        expect: () => [
          DondeQuedaState(
            status: DondeQuedaLoad.ready,
            week: myTurn,
            passing: true,
          ),
          DondeQuedaState(status: DondeQuedaLoad.ready, week: myTurn),
        ],
      );

      blocTest<DondeQuedaCubit, DondeQuedaState>(
        'says nothing when the turn had already moved on',
        setUp: () => when(
          () => repository.pass(
            rondaId: any(named: 'rondaId'),
            week: any(named: 'week'),
          ),
        ).thenThrow(const NotYourTurnFailure()),
        build: () => ready(myTurn),
        act: (cubit) => cubit.passTapped(),
        expect: () => [
          DondeQuedaState(
            status: DondeQuedaLoad.ready,
            week: myTurn,
            passing: true,
          ),
          DondeQuedaState(status: DondeQuedaLoad.ready, week: myTurn),
        ],
      );

      blocTest<DondeQuedaCubit, DondeQuedaState>(
        'says when it failed',
        setUp: () => when(
          () => repository.pass(
            rondaId: any(named: 'rondaId'),
            week: any(named: 'week'),
          ),
        ).thenThrow(const DondeQuedaFailure()),
        build: () => ready(myTurn),
        act: (cubit) => cubit.passTapped(),
        expect: () => [
          DondeQuedaState(
            status: DondeQuedaLoad.ready,
            week: myTurn,
            passing: true,
          ),
          DondeQuedaState(
            status: DondeQuedaLoad.ready,
            week: myTurn,
            passFailed: true,
          ),
        ],
        errors: () => [isA<DondeQuedaFailure>()],
      );

      blocTest<DondeQuedaCubit, DondeQuedaState>(
        'does nothing when it is not their turn, or already passing',
        build: () => ready(DondeQuedaWeek(game: DondeQuedaFixtures.open())),
        act: (cubit) async {
          await cubit.passTapped();
          cubit.emit(cubit.state.copyWith(passing: true));
          await cubit.passTapped();
          final empty = build();
          await empty.passTapped();
          await empty.close();
        },
        expect: () => [
          DondeQuedaState(
            status: DondeQuedaLoad.ready,
            week: DondeQuedaWeek(game: DondeQuedaFixtures.open()),
            passing: true,
          ),
        ],
      );
    });

    test('stops following when closed', () async {
      final cubit = build()..subscribe();
      await cubit.close();

      expect(weeks.hasListener, isFalse);
    });
  });
}
