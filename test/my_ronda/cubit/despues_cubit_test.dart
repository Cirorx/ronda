import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/my_ronda/cubit/despues_cubit.dart';
import 'package:ronda_repository/ronda_repository.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  setUpAll(() => registerFallbackValue(DespuesKind.none));

  group(DespuesCubit, () {
    late RondaRepository rondaRepository;

    setUp(() {
      rondaRepository = _MockRondaRepository();
      when(
        () => rondaRepository.setDespues(
          rondaId: any(named: 'rondaId'),
          week: any(named: 'week'),
          kind: any(named: 'kind'),
          what: any(named: 'what'),
          where: any(named: 'where'),
          homeOfUid: any(named: 'homeOfUid'),
          address: any(named: 'address'),
        ),
      ).thenAnswer((_) async {});
    });

    DespuesCubit build() => DespuesCubit(
      rondaId: 'r1',
      week: '2026-W44',
      rondaRepository: rondaRepository,
    );

    test('starts with nothing on its way', () {
      expect(build().state, const DespuesState());
    });

    blocTest<DespuesCubit, DespuesState>(
      'saves a public place with only what it needs',
      build: build,
      act: (cubit) => cubit.save(
        kind: DespuesKind.place,
        what: ' bizcochos ',
        where: 'el café de la esquina',
        homeOfUid: 'demo-001',
        address: 'Av. Central 1234',
      ),
      expect: () => [
        const DespuesState(saving: true),
        const DespuesState(saved: true),
      ],
      verify: (_) => verify(
        () => rondaRepository.setDespues(
          rondaId: 'r1',
          week: '2026-W44',
          kind: DespuesKind.place,
          what: 'bizcochos',
          where: 'el café de la esquina',
        ),
      ).called(1),
    );

    blocTest<DespuesCubit, DespuesState>(
      'saves a home with whose it is and the address',
      build: build,
      act: (cubit) => cubit.save(
        kind: DespuesKind.home,
        what: 'bizcochos',
        where: 'ignored',
        homeOfUid: 'demo-002',
        address: 'Av. Central 1234',
      ),
      verify: (_) => verify(
        () => rondaRepository.setDespues(
          rondaId: 'r1',
          week: '2026-W44',
          kind: DespuesKind.home,
          what: 'bizcochos',
          homeOfUid: 'demo-002',
          address: 'Av. Central 1234',
        ),
      ).called(1),
    );

    blocTest<DespuesCubit, DespuesState>(
      '"Esta semana no" sends no words',
      build: build,
      act: (cubit) => cubit.save(kind: DespuesKind.none, what: 'x'),
      verify: (_) => verify(
        () => rondaRepository.setDespues(
          rondaId: 'r1',
          week: '2026-W44',
          kind: DespuesKind.none,
        ),
      ).called(1),
    );

    blocTest<DespuesCubit, DespuesState>(
      'stops what is missing before it is sent',
      build: build,
      act: (cubit) async {
        await cubit.save(kind: DespuesKind.place, what: 'bizcochos');
        await cubit.save(kind: DespuesKind.home, what: ' ', address: 'x');
      },
      expect: () => [const DespuesState(missing: true)],
      verify: (_) => verifyNever(
        () => rondaRepository.setDespues(
          rondaId: any(named: 'rondaId'),
          week: any(named: 'week'),
          kind: any(named: 'kind'),
        ),
      ),
    );

    blocTest<DespuesCubit, DespuesState>(
      'says why the server refused it',
      setUp: () => when(
        () => rondaRepository.setDespues(
          rondaId: any(named: 'rondaId'),
          week: any(named: 'week'),
          kind: any(named: 'kind'),
          what: any(named: 'what'),
          where: any(named: 'where'),
          homeOfUid: any(named: 'homeOfUid'),
          address: any(named: 'address'),
        ),
      ).thenThrow(const HostsFailure(HostsFailureReason.notPublic)),
      build: build,
      act: (cubit) => cubit.save(kind: DespuesKind.none),
      expect: () => [
        const DespuesState(saving: true),
        const DespuesState(failure: HostsFailureReason.notPublic),
      ],
      errors: () => [isA<HostsFailure>()],
    );

    blocTest<DespuesCubit, DespuesState>(
      'sends once while it is on its way',
      build: build,
      seed: () => const DespuesState(saving: true),
      act: (cubit) => cubit.save(kind: DespuesKind.none),
      expect: () => <DespuesState>[],
    );
  });
}
