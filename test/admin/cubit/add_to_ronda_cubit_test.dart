import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda_repository/ronda_repository.dart';

import '../fixtures.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  group(AddToRondaCubit, () {
    late RondaRepository rondaRepository;
    final candidates = PilotFixtures.candidates();
    final after = PilotFixtures.candidates(
      taken: 4,
      people: const [PilotFixtures.gabi],
    );

    setUp(() {
      rondaRepository = _MockRondaRepository();
      when(() => rondaRepository.rondaCandidates('r1'))
          .thenAnswer((_) async => candidates);
    });

    AddToRondaCubit build() =>
        AddToRondaCubit(rondaRepository: rondaRepository, rondaId: 'r1');

    final ready = AddToRondaState(
      status: AddToRondaStatus.ready,
      candidates: candidates,
    );

    test('starts loading', () {
      expect(build().state, const AddToRondaState());
    });

    blocTest<AddToRondaCubit, AddToRondaState>(
      'reads who could join',
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [const AddToRondaState(), ready],
    );

    blocTest<AddToRondaCubit, AddToRondaState>(
      'fails when they cannot be read',
      setUp: () =>
          when(() => rondaRepository.rondaCandidates('r1'))
              .thenThrow(const ProposalsFailure(ProposalsFailureReason.other)),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const AddToRondaState(),
        const AddToRondaState(status: AddToRondaStatus.failure),
      ],
      errors: () => [isA<ProposalsFailure>()],
    );

    blocTest<AddToRondaCubit, AddToRondaState>(
      'adds someone in no ronda without moving anyone, then reads again',
      setUp: () {
        when(() => rondaRepository.addToRonda(rondaId: 'r1', uid: 'eva'))
            .thenAnswer(
              (_) async => const AddedToRonda(
                rondaId: 'r1',
                uid: 'eva',
                warnings: [CandidateWarning.seat],
              ),
            );
        when(() => rondaRepository.rondaCandidates('r1'))
            .thenAnswer((_) async => after);
      },
      build: build,
      seed: () => ready,
      act: (cubit) => cubit.add(PilotFixtures.eva),
      expect: () {
        final added = AddToRondaState(
          status: AddToRondaStatus.ready,
          candidates: candidates,
          outcome: AddOutcome.added,
          lastName: 'Eva',
          warnings: const [CandidateWarning.seat],
        );
        return [
          AddToRondaState(
            status: AddToRondaStatus.ready,
            candidates: candidates,
            adding: PilotFixtures.eva,
          ),
          added,
          added.copyWith(status: AddToRondaStatus.loading),
          added.copyWith(candidates: after),
        ];
      },
    );

    blocTest<AddToRondaCubit, AddToRondaState>(
      'moves someone out of the ronda they are in',
      setUp: () =>
          when(
            () => rondaRepository.addToRonda(
              rondaId: 'r1',
              uid: 'gabi',
              move: true,
            ),
          ).thenAnswer(
            (_) async =>
                const AddedToRonda(rondaId: 'r1', uid: 'gabi', warnings: []),
          ),
      build: build,
      seed: () => ready,
      act: (cubit) => cubit.add(PilotFixtures.gabi),
      verify: (_) => verify(
        () =>
            rondaRepository.addToRonda(rondaId: 'r1', uid: 'gabi', move: true),
      ).called(1),
    );

    blocTest<AddToRondaCubit, AddToRondaState>(
      'adds one at a time',
      build: build,
      seed: () => ready.copyWith(adding: PilotFixtures.eva),
      act: (cubit) => cubit.add(PilotFixtures.gabi),
      expect: () => <AddToRondaState>[],
    );

    final refusals = {
      ProposalsFailureReason.full: AddOutcome.full,
      ProposalsFailureReason.alreadyIn: AddOutcome.alreadyIn,
      ProposalsFailureReason.other: AddOutcome.failed,
    };
    for (final MapEntry(key: reason, value: outcome) in refusals.entries) {
      blocTest<AddToRondaCubit, AddToRondaState>(
        'says $outcome when the server refuses with $reason',
        setUp: () =>
            when(() => rondaRepository.addToRonda(rondaId: 'r1', uid: 'eva'))
                .thenThrow(ProposalsFailure(reason)),
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.add(PilotFixtures.eva),
        skip: 1,
        expect: () => [
          AddToRondaState(
            status: AddToRondaStatus.ready,
            candidates: candidates,
            outcome: outcome,
            lastName: 'Eva',
          ),
        ],
        errors: () => [isA<ProposalsFailure>()],
      );
    }
  });
}
