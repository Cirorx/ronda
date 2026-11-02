import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/my_data/my_data.dart';
import 'package:ronda_repository/ronda_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository;

class _MockNeedsRepository extends Mock implements NeedsRepository;

class _MockRondaRepository extends Mock implements RondaRepository;

// Invented demo data.
final _profile = Profile(
  firstName: 'Marta',
  ageBand: AgeBand.sixties,
  barrio: Barrio.cordon,
  pretexts: const {Pretext.mate},
  slots: {const Slot(SlotDay.saturday, SlotBand.afternoon)},
  brings: const {Bring.termo},
);

const _week = ThisWeek(
  rondaId: 'r1',
  pretextId: 'mate',
  barrioId: 'cordon',
  slotDayId: 'sat',
  slotBandId: 'afternoon',
  myBrings: [],
);

void main() {
  group(MyDataCubit, () {
    late ProfileRepository profileRepository;
    late NeedsRepository needsRepository;
    late RondaRepository rondaRepository;

    setUpAll(() {
      registerFallbackValue(_profile);
      registerFallbackValue(Needs.none);
    });

    setUp(() {
      profileRepository = _MockProfileRepository();
      needsRepository = _MockNeedsRepository();
      rondaRepository = _MockRondaRepository();
      when(() => profileRepository.watchProfile('demo-uid'))
          .thenAnswer((_) => Stream.value(_profile));
      when(() => rondaRepository.watchThisWeek('demo-uid'))
          .thenAnswer((_) => Stream.value(null));
      when(needsRepository.read).thenAnswer((_) async => Needs.none);
      when(profileRepository.publishedSeats).thenAnswer(
        (_) async => const [
          PublishedSeat(
            seatId: 'cordon_mate_sat-afternoon',
            blocksFrom: {'cordon': 0},
            hasStairs: false,
            endsAfterDark: false,
            needsCar: false,
          ),
          PublishedSeat(
            seatId: 'centro_mate_sat-afternoon',
            blocksFrom: {'centro': 0, 'cordon': 20},
            hasStairs: false,
            endsAfterDark: false,
            needsCar: false,
          ),
        ],
      );
      when(() => needsRepository.eligibleSeatIds(any(), any())).thenAnswer(
        (invocation) => [
          for (final seat
              in invocation.positionalArguments[1] as List<SeatFacts>)
            if (seat.walkDistance != WalkDistance.far) seat.seatId,
        ],
      );
      when(
        () => profileRepository.saveEligibleSeatIds(
          uid: any(named: 'uid'),
          seatIds: any(named: 'seatIds'),
        ),
      ).thenAnswer((_) async {});
      when(() => profileRepository.updateProfile(any(), any()))
          .thenAnswer((_) async {});
    });

    MyDataCubit build() => MyDataCubit(
      uid: 'demo-uid',
      profileRepository: profileRepository,
      needsRepository: needsRepository,
      rondaRepository: rondaRepository,
    );

    final loaded = MyDataState.fromProfile(_profile, seated: false);

    group('load', () {
      blocTest<MyDataCubit, MyDataState>(
        'opens the saved profile',
        build: build,
        act: (cubit) => cubit.load(),
        expect: () => [const MyDataState(), loaded],
      );

      blocTest<MyDataCubit, MyDataState>(
        'knows a member who sits in a ronda',
        setUp: () =>
            when(() => rondaRepository.watchThisWeek('demo-uid'))
                .thenAnswer((_) => Stream.value(_week)),
        build: build,
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [MyDataState.fromProfile(_profile, seated: true)],
      );

      blocTest<MyDataCubit, MyDataState>(
        'treats one who left, or a ronda it cannot read, as not seated',
        setUp: () => when(() => rondaRepository.watchThisWeek('demo-uid'))
            .thenAnswer(
              (_) => Stream.error(const RsvpFailure(RsvpFailureReason.other)),
            ),
        build: build,
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [loaded],
      );

      blocTest<MyDataCubit, MyDataState>(
        'fails without a profile or when it cannot be read',
        setUp: () =>
            when(() => profileRepository.watchProfile('demo-uid'))
                .thenAnswer((_) => Stream.fromIterable([null])),
        build: build,
        act: (cubit) async {
          await cubit.load();
          when(() => profileRepository.watchProfile('demo-uid'))
              .thenAnswer((_) => Stream.error(Exception('unavailable')));
          await cubit.load();
        },
        expect: () => [
          const MyDataState(),
          const MyDataState(status: MyDataStatus.loadFailure),
          const MyDataState(),
          const MyDataState(status: MyDataStatus.loadFailure),
        ],
      );
    });

    group('edits', () {
      blocTest<MyDataCubit, MyDataState>(
        'every answer',
        build: build,
        seed: () => loaded,
        act: (cubit) => cubit
          ..firstNameChanged('Marta Inés')
          ..ageBandChanged(AgeBand.seventies)
          ..pretextsChanged(const {Pretext.truco})
          ..slotsChanged({const Slot(SlotDay.sunday, SlotBand.morning)})
          ..bringsChanged(const {Bring.pan}),
        verify: (cubit) => expect(
          cubit.state.profile,
          Profile(
            firstName: 'Marta Inés',
            ageBand: AgeBand.seventies,
            barrio: Barrio.cordon,
            pretexts: const {Pretext.truco},
            slots: {const Slot(SlotDay.sunday, SlotBand.morning)},
            brings: const {Bring.pan},
          ),
        ),
      );

      blocTest<MyDataCubit, MyDataState>(
        'casa, trabajo and their neighbours',
        build: build,
        seed: () => loaded,
        act: (cubit) => cubit
          ..homeNeighboursChanged(neighbours: true)
          ..workNeighboursChanged(neighbours: true)
          ..workChanged(Barrio.cordon)
          ..workChanged(Barrio.centro)
          ..workNeighboursChanged(neighbours: true)
          ..homeChanged(Barrio.palermo),
        verify: (cubit) {
          expect(
            cubit.state.home,
            const Anchor(barrio: Barrio.palermo, neighbours: true),
          );
          expect(
            cubit.state.work,
            const Anchor(barrio: Barrio.centro, neighbours: true),
          );
          expect(cubit.state.changesMatching, isTrue);
        },
      );

      blocTest<MyDataCubit, MyDataState>(
        'moving casa onto trabajo drops trabajo, and trabajo can go',
        build: build,
        seed: () => loaded,
        act: (cubit) => cubit
          ..workChanged(Barrio.centro)
          ..homeChanged(Barrio.centro)
          ..workChanged(Barrio.cordon)
          ..workRemoved(),
        verify: (cubit) {
          expect(cubit.state.home?.barrio, Barrio.centro);
          expect(cubit.state.work, isNull);
        },
      );

      blocTest<MyDataCubit, MyDataState>(
        'does nothing to neighbours before there is a barrio',
        build: build,
        act: (cubit) => cubit.homeNeighboursChanged(neighbours: true),
        expect: () => <MyDataState>[],
      );

      test('an unchanged profile changes no matching; a slot does', () {
        expect(loaded.changesMatching, isFalse);
        expect(const MyDataState().changesMatching, isFalse);
        expect(
          loaded.copyWith(slots: const {}).changesMatching,
          isFalse,
          reason: 'incomplete answers make no profile',
        );
        expect(
          loaded
              .copyWith(slots: {const Slot(SlotDay.monday, SlotBand.evening)})
              .changesMatching,
          isTrue,
        );
      });
    });

    group('save', () {
      final withWork = Profile(
        firstName: 'Marta',
        ageBand: AgeBand.sixties,
        barrio: Barrio.cordon,
        pretexts: const {Pretext.mate},
        slots: {const Slot(SlotDay.saturday, SlotBand.afternoon)},
        brings: const {Bring.termo},
        work: const Anchor(barrio: Barrio.centro),
      );

      blocTest<MyDataCubit, MyDataState>(
        'writes the seat ids from casa and trabajo, then the profile',
        build: build,
        seed: () => loaded,
        act: (cubit) async {
          cubit.workChanged(Barrio.centro);
          await cubit.save();
        },
        skip: 1,
        expect: () => [
          isA<MyDataState>().having(
            (s) => s.status,
            'status',
            MyDataStatus.saving,
          ),
          isA<MyDataState>()
              .having((s) => s.status, 'status', MyDataStatus.saved)
              .having((s) => s.saved, 'saved', withWork),
        ],
        verify: (_) {
          verifyInOrder([
            () => profileRepository.saveEligibleSeatIds(
              uid: 'demo-uid',
              seatIds: [
                'cordon_mate_sat-afternoon',
                'centro_mate_sat-afternoon',
              ],
            ),
            () => profileRepository.updateProfile('demo-uid', withWork),
          ]);
        },
      );

      blocTest<MyDataCubit, MyDataState>(
        'fails without writing the profile when the ids fail',
        setUp: () => when(
          () => profileRepository.saveEligibleSeatIds(
            uid: any(named: 'uid'),
            seatIds: any(named: 'seatIds'),
          ),
        ).thenThrow(const SaveEligibleSeatIdsFailure()),
        build: build,
        seed: () => loaded,
        act: (cubit) => cubit.save(),
        expect: () => [
          loaded.copyWith(status: MyDataStatus.saving),
          loaded.copyWith(status: MyDataStatus.saveFailure),
        ],
        verify: (_) =>
            verifyNever(() => profileRepository.updateProfile(any(), any())),
      );

      blocTest<MyDataCubit, MyDataState>(
        'does nothing while an answer is missing or a save runs',
        build: build,
        seed: () => loaded.copyWith(brings: const {}),
        act: (cubit) async {
          await cubit.save();
          cubit.emit(loaded.copyWith(status: MyDataStatus.saving));
          await cubit.save();
        },
        expect: () => [loaded.copyWith(status: MyDataStatus.saving)],
      );
    });
  });
}
