import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/ronda_setup/ronda_setup.dart';
import 'package:ronda_repository/ronda_repository.dart';

import '../fixtures.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  group('hourChoices', () {
    test('every half hour with an hour of the band left', () {
      expect(hourChoices('morning'), [
        '09:00',
        '09:30',
        '10:00',
        '10:30',
        '11:00',
      ]);
      expect(hourChoices('afternoon').first, '14:00');
      expect(hourChoices('afternoon').last, '17:00');
      expect(hourChoices('evening'), ['19:00', '19:30', '20:00']);
      expect(hourChoices('late'), isEmpty);
    });
  });

  group(RondaSetupCubit, () {
    late RondaRepository repository;

    setUp(() {
      repository = _MockRondaRepository();
      when(repository.rondaSetups)
          .thenAnswer((_) async => const [SetupFixtures.bare]);
    });

    RondaSetupCubit build() => RondaSetupCubit(rondaRepository: repository);

    When<Future<void>> saves() => when(
      () => repository.setRondaSetup(
        rondaId: any(named: 'rondaId'),
        placeName: any(named: 'placeName'),
        placeLandmark: any(named: 'placeLandmark'),
        hour: any(named: 'hour'),
        anfitrionUid: any(named: 'anfitrionUid'),
        colaUid: any(named: 'colaUid'),
      ),
    );

    blocTest<RondaSetupCubit, RondaSetupState>(
      'reads every ronda',
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const RondaSetupState(),
        const RondaSetupState(
          status: RondaSetupStatus.ready,
          rondas: [SetupFixtures.bare],
        ),
      ],
    );

    blocTest<RondaSetupCubit, RondaSetupState>(
      'is forbidden for anyone but the admin',
      setUp: () =>
          when(repository.rondaSetups)
              .thenThrow(const HostsFailure(HostsFailureReason.forbidden)),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const RondaSetupState(),
        const RondaSetupState(status: RondaSetupStatus.forbidden),
      ],
      errors: () => [isA<HostsFailure>()],
    );

    blocTest<RondaSetupCubit, RondaSetupState>(
      'fails on anything else',
      setUp: () =>
          when(repository.rondaSetups)
              .thenThrow(const HostsFailure(HostsFailureReason.other)),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const RondaSetupState(),
        const RondaSetupState(status: RondaSetupStatus.failure),
      ],
      errors: () => [isA<HostsFailure>()],
    );

    blocTest<RondaSetupCubit, RondaSetupState>(
      'saves, then reads every ronda again',
      setUp: () => saves().thenAnswer((_) async {}),
      build: build,
      seed: () => const RondaSetupState(
        status: RondaSetupStatus.ready,
        rondas: [SetupFixtures.bare],
      ),
      act: (cubit) => cubit.save(
        rondaId: 'r1',
        placeName: 'la plaza',
        hour: '16:00',
        anfitrionUid: 'demo-101',
      ),
      expect: () => [
        const RondaSetupState(
          status: RondaSetupStatus.ready,
          rondas: [SetupFixtures.bare],
          saving: true,
        ),
        const RondaSetupState(
          status: RondaSetupStatus.ready,
          rondas: [SetupFixtures.bare],
        ),
      ],
      verify: (_) => verify(
        () => repository.setRondaSetup(
          rondaId: 'r1',
          placeName: 'la plaza',
          hour: '16:00',
          anfitrionUid: 'demo-101',
        ),
      ).called(1),
    );

    blocTest<RondaSetupCubit, RondaSetupState>(
      'says why a save failed until the sheet closes',
      setUp: () =>
          saves().thenThrow(const HostsFailure(HostsFailureReason.notPublic)),
      build: build,
      seed: () => const RondaSetupState(status: RondaSetupStatus.ready),
      act: (cubit) async {
        await cubit.save(rondaId: 'r1', placeName: 'x');
        cubit.sheetClosed();
      },
      expect: () => [
        const RondaSetupState(status: RondaSetupStatus.ready, saving: true),
        const RondaSetupState(
          status: RondaSetupStatus.ready,
          saveFailure: HostsFailureReason.notPublic,
        ),
        const RondaSetupState(status: RondaSetupStatus.ready),
      ],
      errors: () => [isA<HostsFailure>()],
    );

    blocTest<RondaSetupCubit, RondaSetupState>(
      'ignores a save while one is on its way',
      build: build,
      seed: () => const RondaSetupState(saving: true),
      act: (cubit) => cubit.save(rondaId: 'r1'),
      expect: () => <RondaSetupState>[],
    );
  });
}
