import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/payoff/payoff.dart';
import 'package:ronda_repository/ronda_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository;

class _MockRondaRepository extends Mock implements RondaRepository;

const _saturday = Slot(SlotDay.saturday, SlotBand.afternoon);
const _tuesday = Slot(SlotDay.tuesday, SlotBand.evening);

final _answers = Profile(
  firstName: 'Marta',
  ageBand: AgeBand.sixties,
  barrio: Barrio.elPinarSur,
  pretexts: const {Pretext.truco, Pretext.mate},
  slots: {_tuesday, _saturday},
  brings: const {Bring.termo},
);

void main() {
  group(PayoffCubit, () {
    late ProfileRepository profileRepository;
    late RondaRepository rondaRepository;

    setUp(() {
      profileRepository = _MockProfileRepository();
      rondaRepository = _MockRondaRepository();
      when(profileRepository.heldAnswers).thenAnswer((_) async => _answers);
    });

    PayoffCubit buildCubit() => PayoffCubit(
      profileRepository: profileRepository,
      rondaRepository: rondaRepository,
    );

    test('starts loading', () {
      expect(buildCubit().state, equals(const PayoffState()));
    });

    group('load', () {
      blocTest<PayoffCubit, PayoffState>(
        "reads the held answers' barrio and shows its demand",
        setUp: () {
          when(() => rondaRepository.cerca('el-pinar-sur')).thenAnswer(
            (_) async => const Cerca(
              barrioId: 'el-pinar-sur',
              bySlot: [
                CercaWaiting(
                  pretextId: 'mate',
                  slotId: 'sat-afternoon',
                  count: 4,
                ),
              ],
            ),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => const [
          PayoffState(
            status: PayoffStatus.ready,
            barrio: Barrio.elPinarSur,
            demand: [
              PayoffDemand(pretext: Pretext.mate, slot: _saturday, count: 4),
            ],
          ),
        ],
      );

      blocTest<PayoffCubit, PayoffState>(
        'is ready with no demand when nobody else signed up',
        setUp: () {
          when(() => rondaRepository.cerca(any()))
              .thenAnswer((_) async => const Cerca(barrioId: 'el-pinar-sur'));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => const [
          PayoffState(status: PayoffStatus.ready, barrio: Barrio.elPinarSur),
        ],
      );

      blocTest<PayoffCubit, PayoffState>(
        'is unavailable when the counts cannot be read',
        setUp: () {
          when(() => rondaRepository.cerca(any()))
              .thenThrow(const CercaFailure());
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => const [
          PayoffState(
            status: PayoffStatus.unavailable,
            barrio: Barrio.elPinarSur,
          ),
        ],
      );

      blocTest<PayoffCubit, PayoffState>(
        'has no answers, and reads no counts, when none are held',
        setUp: () {
          when(profileRepository.heldAnswers).thenAnswer((_) async => null);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => const [PayoffState(status: PayoffStatus.noAnswers)],
        verify: (_) {
          verifyNever(() => rondaRepository.cerca(any()));
        },
      );
    });

    group('once closed', () {
      test('emits nothing when the counts arrive', () async {
        when(() => rondaRepository.cerca(any()))
            .thenAnswer((_) async => const Cerca(barrioId: 'el-pinar-sur'));
        final cubit = buildCubit();
        final load = cubit.load();
        await cubit.close();
        await load;

        expect(cubit.state, equals(const PayoffState()));
      });

      test('emits nothing when the counts fail', () async {
        when(() => rondaRepository.cerca(any()))
            .thenThrow(const CercaFailure());
        final cubit = buildCubit();
        final load = cubit.load();
        await cubit.close();
        await load;

        expect(cubit.state, equals(const PayoffState()));
      });

      test('emits nothing when no answers are held', () async {
        when(profileRepository.heldAnswers).thenAnswer((_) async => null);
        final cubit = buildCubit();
        final load = cubit.load();
        await cubit.close();
        await load;

        expect(cubit.state, equals(const PayoffState()));
      });
    });

    group('demandFor', () {
      test('lists a line per slot of theirs that has a count, in order', () {
        const cerca = Cerca(
          barrioId: 'el-pinar-sur',
          bySlot: [
            CercaWaiting(pretextId: 'mate', slotId: 'sat-afternoon', count: 4),
            CercaWaiting(pretextId: 'mate', slotId: 'tue-evening', count: 2),
            CercaWaiting(pretextId: 'mate', slotId: 'sun-morning', count: 9),
            CercaWaiting(pretextId: 'futbol5', slotId: 'tue-evening', count: 7),
          ],
          byPretext: [CercaWaiting(pretextId: 'mate', count: 12)],
        );

        expect(
          PayoffCubit.demandFor(_answers, cerca),
          equals(const [
            PayoffDemand(pretext: Pretext.mate, slot: _tuesday, count: 2),
            PayoffDemand(pretext: Pretext.mate, slot: _saturday, count: 4),
          ]),
        );
      });

      test("falls back to the pretext's count at any slot", () {
        const cerca = Cerca(
          barrioId: 'el-pinar-sur',
          bySlot: [
            CercaWaiting(pretextId: 'truco', slotId: 'sun-morning', count: 3),
          ],
          byPretext: [
            CercaWaiting(pretextId: 'truco', count: 5),
            CercaWaiting(pretextId: 'caminata', count: 8),
          ],
        );

        expect(
          PayoffCubit.demandFor(_answers, cerca),
          equals(const [PayoffDemand(pretext: Pretext.truco, count: 5)]),
        );
      });

      test('takes the largest count when rondas share a pretext and slot', () {
        const cerca = Cerca(
          barrioId: 'el-pinar-sur',
          bySlot: [
            CercaWaiting(pretextId: 'mate', slotId: 'sat-afternoon', count: 3),
            CercaWaiting(pretextId: 'mate', slotId: 'sat-afternoon', count: 5),
          ],
        );

        expect(
          PayoffCubit.demandFor(_answers, cerca),
          equals(const [
            PayoffDemand(pretext: Pretext.mate, slot: _saturday, count: 5),
          ]),
        );
      });

      test('never shows a count of zero', () {
        const cerca = Cerca(
          barrioId: 'el-pinar-sur',
          bySlot: [
            CercaWaiting(pretextId: 'mate', slotId: 'sat-afternoon', count: 0),
          ],
          byPretext: [
            CercaWaiting(pretextId: 'mate', count: 0),
            CercaWaiting(pretextId: 'truco', count: 0),
          ],
        );

        expect(PayoffCubit.demandFor(_answers, cerca), isEmpty);
      });
    });
  });
}
