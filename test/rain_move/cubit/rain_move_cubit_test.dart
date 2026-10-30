import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:organiser_repository/organiser_repository.dart';
import 'package:ronda/rain_move/rain_move.dart';

class _MockOrganiserRepository extends Mock implements OrganiserRepository;

final _move = RainMove(
  title: 'El jueves puede llover',
  forecast: 'Jueves 16:00 · lluvia 80%.',
  options: const [
    RainOption(
      choice: MoveChoice.covered,
      label: 'Al Salón Comunal',
      message: 'Nos vemos en el Salón Comunal.',
    ),
    RainOption(
      choice: MoveChoice.asIs,
      label: 'Vamos igual',
      message: 'Igual.',
    ),
  ],
  recipients: 3,
  deadline: DateTime(2026, 11, 4, 21),
  status: RainMoveStatus.pending,
  standIn: false,
);

void main() {
  group(RainMoveCubit, () {
    late OrganiserRepository repository;

    setUpAll(() => registerFallbackValue(MoveChoice.asIs));

    setUp(() {
      repository = _MockOrganiserRepository();
      when(() => repository.watchMove('r1', '2026-W45'))
          .thenAnswer((_) => Stream.value(_move));
    });

    RainMoveCubit build() => RainMoveCubit(
      rondaId: 'r1',
      week: '2026-W45',
      organiserRepository: repository,
    );

    final ready = RainMoveState(status: RainMoveViewStatus.ready, move: _move);
    final picked = RainMoveState(
      status: RainMoveViewStatus.ready,
      move: _move,
      selected: MoveChoice.covered,
    );

    test('starts loading', () {
      expect(build().state, const RainMoveState());
    });

    blocTest<RainMoveCubit, RainMoveState>(
      'follows the proposal',
      build: build,
      act: (cubit) => cubit.subscribe(),
      expect: () => [const RainMoveState(), ready],
    );

    blocTest<RainMoveCubit, RainMoveState>(
      'says when there is none',
      setUp: () =>
          when(() => repository.watchMove('r1', '2026-W45'))
              .thenAnswer((_) => Stream.value(null)),
      build: build,
      act: (cubit) => cubit.subscribe(),
      expect: () => const [
        RainMoveState(),
        RainMoveState(status: RainMoveViewStatus.none),
      ],
    );

    for (final (reason, status) in [
      (OrganiserFailureReason.forbidden, RainMoveViewStatus.forbidden),
      (OrganiserFailureReason.other, RainMoveViewStatus.failure),
    ]) {
      blocTest<RainMoveCubit, RainMoveState>(
        'a ${reason.name} read shows as ${status.name}',
        setUp: () =>
            when(() => repository.watchMove('r1', '2026-W45'))
                .thenAnswer((_) => Stream.error(OrganiserFailure(reason))),
        build: build,
        act: (cubit) => cubit.subscribe(),
        expect: () => [const RainMoveState(), RainMoveState(status: status)],
        errors: () => [isA<OrganiserFailure>()],
      );
    }

    blocTest<RainMoveCubit, RainMoveState>(
      "a tap shows that option's message",
      build: build,
      seed: () => ready,
      act: (cubit) => cubit.optionTapped(MoveChoice.covered),
      expect: () => [picked],
      verify: (cubit) => expect(
        cubit.state.selectedOption!.message,
        'Nos vemos en el Salón Comunal.',
      ),
    );

    blocTest<RainMoveCubit, RainMoveState>(
      'sends the tapped option',
      setUp: () => when(
        () => repository.answerMove(
          rondaId: 'r1',
          week: '2026-W45',
          choice: MoveChoice.covered,
        ),
      ).thenAnswer((_) async => const MoveAnswer(sent: 3, already: false)),
      build: build,
      seed: () => picked,
      act: (cubit) => cubit.sendTapped(),
      expect: () => [
        RainMoveState(
          status: RainMoveViewStatus.ready,
          move: _move,
          selected: MoveChoice.covered,
          sending: RainMoveSending.sending,
        ),
        picked,
      ],
    );

    for (final (reason, sending) in [
      (OrganiserFailureReason.late, RainMoveSending.late),
      (OrganiserFailureReason.other, RainMoveSending.failed),
    ]) {
      blocTest<RainMoveCubit, RainMoveState>(
        'a ${reason.name} answer shows as ${sending.name}',
        setUp: () => when(
          () => repository.answerMove(
            rondaId: any(named: 'rondaId'),
            week: any(named: 'week'),
            choice: MoveChoice.covered,
          ),
        ).thenThrow(OrganiserFailure(reason)),
        build: build,
        seed: () => picked,
        act: (cubit) => cubit.sendTapped(),
        skip: 1,
        expect: () => [
          RainMoveState(
            status: RainMoveViewStatus.ready,
            move: _move,
            selected: MoveChoice.covered,
            sending: sending,
          ),
        ],
        errors: () => [isA<OrganiserFailure>()],
      );
    }

    blocTest<RainMoveCubit, RainMoveState>(
      'sends nothing without a tapped option, or twice',
      build: build,
      seed: () => ready,
      act: (cubit) async {
        await cubit.sendTapped();
        cubit.emit(
          RainMoveState(
            status: RainMoveViewStatus.ready,
            move: _move,
            selected: MoveChoice.asIs,
            sending: RainMoveSending.sending,
          ),
        );
        await cubit.sendTapped();
      },
      verify: (_) => verifyNever(
        () => repository.answerMove(
          rondaId: any(named: 'rondaId'),
          week: any(named: 'week'),
          choice: any(named: 'choice'),
        ),
      ),
    );
  });
}
