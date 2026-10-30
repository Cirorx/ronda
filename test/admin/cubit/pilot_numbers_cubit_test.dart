import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda_repository/ronda_repository.dart';

import '../fixtures.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  group(PilotNumbersCubit, () {
    late RondaRepository rondaRepository;

    setUp(() => rondaRepository = _MockRondaRepository());

    PilotNumbersCubit build() =>
        PilotNumbersCubit(rondaRepository: rondaRepository);

    test('starts loading', () {
      expect(build().state, const PilotNumbersState());
    });

    blocTest<PilotNumbersCubit, PilotNumbersState>(
      'counts them',
      setUp: () =>
          when(rondaRepository.pilotNumbers)
              .thenAnswer((_) async => PilotFixtures.numbers),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const PilotNumbersState(),
        PilotNumbersState(
          status: PilotNumbersStatus.ready,
          numbers: PilotFixtures.numbers,
        ),
      ],
    );

    blocTest<PilotNumbersCubit, PilotNumbersState>(
      'keeps the last numbers when counting again fails',
      setUp: () =>
          when(rondaRepository.pilotNumbers)
              .thenThrow(const ProposalsFailure(ProposalsFailureReason.other)),
      build: build,
      seed: () => PilotNumbersState(
        status: PilotNumbersStatus.ready,
        numbers: PilotFixtures.numbers,
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        PilotNumbersState(numbers: PilotFixtures.numbers),
        PilotNumbersState(
          status: PilotNumbersStatus.failure,
          numbers: PilotFixtures.numbers,
        ),
      ],
      errors: () => [isA<ProposalsFailure>()],
    );

    blocTest<PilotNumbersCubit, PilotNumbersState>(
      'is forbidden for anyone but the admin',
      setUp: () => when(rondaRepository.pilotNumbers)
          .thenThrow(const ProposalsFailure(ProposalsFailureReason.forbidden)),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const PilotNumbersState(),
        const PilotNumbersState(status: PilotNumbersStatus.forbidden),
      ],
      errors: () => [isA<ProposalsFailure>()],
    );
  });
}
