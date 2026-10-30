import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/onboarding/onboarding.dart';

class _MockProfileRepository extends Mock implements ProfileRepository;

class _MockNeedsRepository extends Mock implements NeedsRepository;

const _thursday = Slot(SlotDay.thursday, SlotBand.afternoon);

/// Every question answered, on the read-back.
final _answered = OnboardingState(
  step: OnboardingStep.review,
  pretexts: const {Pretext.mate},
  brings: const {Bring.termo},
  slots: {_thursday},
  barrio: Barrio.solymarNorte,
  ageBand: AgeBand.sixties,
  needs: const {Need.noCar},
  firstName: const FirstName.dirty(' Marta '),
);

/// Invented demo seats (values from data/demo/invented_seat_facts.json).
const _seats = [
  PublishedSeat(
    seatId: 'solymar-sur_mate_sat-afternoon',
    blocksFrom: {'solymar-sur': 0, 'solymar-norte': 9.1},
    hasStairs: false,
    endsAfterDark: false,
    needsCar: false,
  ),
  PublishedSeat(
    seatId: 'solymar-sur_truco_thu-evening',
    blocksFrom: {'solymar-sur': 0, 'solymar-norte': 9.1},
    hasStairs: false,
    endsAfterDark: true,
    needsCar: false,
  ),
  PublishedSeat(
    seatId: 'solymar-norte_mate_sun-afternoon',
    blocksFrom: {'solymar-sur': 9.1, 'solymar-norte': 0},
    hasStairs: false,
    endsAfterDark: false,
    needsCar: false,
  ),
  PublishedSeat(
    seatId: 'lagomar-sur_mate_sat-afternoon',
    blocksFrom: {'solymar-sur': 24.1, 'lagomar-sur': 0},
    hasStairs: true,
    endsAfterDark: false,
    needsCar: true,
  ),
  PublishedSeat(
    seatId: 'el-pinar-norte_caminata_sun-afternoon',
    blocksFrom: {'el-pinar-norte': 0},
    hasStairs: false,
    endsAfterDark: false,
    needsCar: false,
  ),
];

/// [_seats] as the needs filter sees them from solymar-sur: walks measured
/// from that barrio, and a barrio missing from the table read as far.
const _solymarSurFacts = [
  SeatFacts(
    seatId: 'solymar-sur_mate_sat-afternoon',
    walkDistance: WalkDistance.near,
    hasStairs: false,
    endsAfterDark: false,
    needsCar: false,
  ),
  SeatFacts(
    seatId: 'solymar-sur_truco_thu-evening',
    walkDistance: WalkDistance.near,
    hasStairs: false,
    endsAfterDark: true,
    needsCar: false,
  ),
  SeatFacts(
    seatId: 'solymar-norte_mate_sun-afternoon',
    walkDistance: WalkDistance.medium,
    hasStairs: false,
    endsAfterDark: false,
    needsCar: false,
  ),
  SeatFacts(
    seatId: 'lagomar-sur_mate_sat-afternoon',
    walkDistance: WalkDistance.far,
    hasStairs: true,
    endsAfterDark: false,
    needsCar: true,
  ),
  SeatFacts(
    seatId: 'el-pinar-norte_caminata_sun-afternoon',
    walkDistance: WalkDistance.far,
    hasStairs: false,
    endsAfterDark: false,
    needsCar: false,
  ),
];

void main() {
  group(OnboardingCubit, () {
    late ProfileRepository profileRepository;
    late NeedsRepository needsRepository;

    setUpAll(() {
      registerFallbackValue(Needs.none);
      registerFallbackValue(<SeatFacts>[]);
      registerFallbackValue(
        const Profile(
          firstName: '',
          ageBand: AgeBand.sixties,
          barrio: Barrio.shangrila,
          pretexts: {},
          slots: {},
          brings: {},
        ),
      );
    });

    setUp(() {
      profileRepository = _MockProfileRepository();
      needsRepository = _MockNeedsRepository();
      when(() => needsRepository.save(any())).thenAnswer((_) async {});
      when(() => profileRepository.createProfile(any(), any()))
          .thenAnswer((_) async {});
      when(() => profileRepository.publishedSeats())
          .thenAnswer((_) async => _seats);
      when(() => needsRepository.eligibleSeatIds(any(), any()))
          .thenReturn(const []);
      when(
        () => profileRepository.saveEligibleSeatIds(
          uid: any(named: 'uid'),
          seatIds: any(named: 'seatIds'),
        ),
      ).thenAnswer((_) async {});
    });

    OnboardingCubit buildCubit() => OnboardingCubit(
      uid: 'demo-uid',
      profileRepository: profileRepository,
      needsRepository: needsRepository,
    );

    test('starts on the first question with nothing answered', () {
      expect(buildCubit().state, equals(const OnboardingState()));
    });

    group('records', () {
      blocTest<OnboardingCubit, OnboardingState>(
        'every answer',
        build: buildCubit,
        act: (cubit) => cubit
          ..pretextsChanged({Pretext.truco})
          ..bringsChanged({Bring.pan})
          ..slotsChanged({_thursday})
          ..barrioChanged(Barrio.lagomarSur)
          ..ageBandChanged(AgeBand.from18To29)
          ..needToggled(Need.walkALot, marked: true)
          ..needToggled(Need.noCar, marked: true)
          ..needToggled(Need.walkALot, marked: false)
          ..firstNameChanged('Facu'),
        skip: 8,
        expect: () => [
          OnboardingState(
            pretexts: const {Pretext.truco},
            brings: const {Bring.pan},
            slots: {_thursday},
            barrio: Barrio.lagomarSur,
            ageBand: AgeBand.from18To29,
            needs: const {Need.noCar},
            firstName: const FirstName.dirty('Facu'),
          ),
        ],
      );
    });

    group('next', () {
      blocTest<OnboardingCubit, OnboardingState>(
        'does nothing while the open question is unanswered',
        build: buildCubit,
        act: (cubit) => cubit.next(),
        expect: () => const <OnboardingState>[],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'walks the questions in order up to the read-back',
        build: buildCubit,
        act: (cubit) {
          cubit
            ..pretextsChanged({Pretext.mate})
            ..next()
            ..bringsChanged({Bring.termo})
            ..next()
            ..slotsChanged({_thursday})
            ..next()
            ..barrioChanged(Barrio.solymarNorte)
            ..next()
            ..ageBandChanged(AgeBand.sixties)
            ..next()
            ..next()
            ..firstNameChanged('Marta')
            ..next();
        },
        verify: (cubit) {
          expect(cubit.state.step, equals(OnboardingStep.review));
          expect(cubit.state.isComplete, isTrue);
        },
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'returns to the read-back after a "Cambiar"',
        build: buildCubit,
        seed: () => _answered,
        act: (cubit) => cubit
          ..edit(OnboardingStep.barrio)
          ..barrioChanged(Barrio.elPinarSur)
          ..next(),
        expect: () => [
          _answered.copyWith(
            step: OnboardingStep.barrio,
            editingFromReview: true,
          ),
          _answered.copyWith(
            step: OnboardingStep.barrio,
            editingFromReview: true,
            barrio: Barrio.elPinarSur,
          ),
          _answered.copyWith(barrio: Barrio.elPinarSur),
        ],
      );

      for (final (step, state) in [
        (
          OnboardingStep.brings,
          const OnboardingState(step: OnboardingStep.brings),
        ),
        (
          OnboardingStep.slots,
          const OnboardingState(step: OnboardingStep.slots),
        ),
        (
          OnboardingStep.barrio,
          const OnboardingState(step: OnboardingStep.barrio),
        ),
        (
          OnboardingStep.ageBand,
          const OnboardingState(step: OnboardingStep.ageBand),
        ),
        (
          OnboardingStep.firstName,
          const OnboardingState(
            step: OnboardingStep.firstName,
            firstName: FirstName.dirty('4'),
          ),
        ),
      ]) {
        blocTest<OnboardingCubit, OnboardingState>(
          'does not leave ${step.name} unanswered',
          build: buildCubit,
          seed: () => state,
          act: (cubit) => cubit.next(),
          expect: () => const <OnboardingState>[],
        );
      }

      blocTest<OnboardingCubit, OnboardingState>(
        'lets the needs question pass with none marked',
        build: buildCubit,
        seed: () => const OnboardingState(step: OnboardingStep.needs),
        act: (cubit) => cubit.next(),
        expect: () => const [OnboardingState(step: OnboardingStep.firstName)],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'does nothing on the read-back',
        build: buildCubit,
        seed: () => _answered,
        act: (cubit) => cubit.next(),
        expect: () => const <OnboardingState>[],
      );
    });

    group('needsSkipped', () {
      blocTest<OnboardingCubit, OnboardingState>(
        'clears the marked needs and moves on',
        build: buildCubit,
        seed: () => const OnboardingState(
          step: OnboardingStep.needs,
          needs: {Need.noCar},
        ),
        act: (cubit) => cubit.needsSkipped(),
        expect: () => const [
          OnboardingState(step: OnboardingStep.needs),
          OnboardingState(step: OnboardingStep.firstName),
        ],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'does nothing on another step',
        build: buildCubit,
        seed: () => const OnboardingState(
          step: OnboardingStep.firstName,
          needs: {Need.noCar},
        ),
        act: (cubit) => cubit.needsSkipped(),
        expect: () => const <OnboardingState>[],
      );
    });

    group('back', () {
      blocTest<OnboardingCubit, OnboardingState>(
        'does nothing on the first question',
        build: buildCubit,
        act: (cubit) => cubit.back(),
        expect: () => const <OnboardingState>[],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'goes to the previous question, keeping the answers',
        build: buildCubit,
        seed: () => const OnboardingState(
          step: OnboardingStep.slots,
          pretexts: {Pretext.mate},
        ),
        act: (cubit) => cubit.back(),
        expect: () => const [
          OnboardingState(
            step: OnboardingStep.brings,
            pretexts: {Pretext.mate},
          ),
        ],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'goes from the read-back to the last question',
        build: buildCubit,
        seed: () => _answered,
        act: (cubit) => cubit.back(),
        expect: () => [_answered.copyWith(step: OnboardingStep.firstName)],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'returns to the read-back after a "Cambiar"',
        build: buildCubit,
        seed: () => _answered.copyWith(
          step: OnboardingStep.pretexts,
          editingFromReview: true,
        ),
        act: (cubit) => cubit.back(),
        expect: () => [_answered],
      );
    });

    group('edit', () {
      blocTest<OnboardingCubit, OnboardingState>(
        'does nothing away from the read-back',
        build: buildCubit,
        act: (cubit) => cubit.edit(OnboardingStep.barrio),
        expect: () => const <OnboardingState>[],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'does nothing for the read-back itself',
        build: buildCubit,
        seed: () => _answered,
        act: (cubit) => cubit.edit(OnboardingStep.review),
        expect: () => const <OnboardingState>[],
      );
    });

    group('save', () {
      blocTest<OnboardingCubit, OnboardingState>(
        'saves the needs on the phone, then the eligible seat ids, then the '
        'profile without the needs',
        build: buildCubit,
        seed: () => _answered,
        act: (cubit) => cubit.save(),
        expect: () => [
          _answered.copyWith(status: OnboardingStatus.saving),
          _answered.copyWith(status: OnboardingStatus.saved),
        ],
        verify: (_) {
          verifyInOrder([
            () => needsRepository.save(const Needs({Need.noCar})),
            () => profileRepository.publishedSeats(),
            () => profileRepository.saveEligibleSeatIds(
              uid: 'demo-uid',
              seatIds: const [],
            ),
            () => profileRepository.createProfile(
              'demo-uid',
              Profile(
                firstName: 'Marta',
                ageBand: AgeBand.sixties,
                barrio: Barrio.solymarNorte,
                pretexts: const {Pretext.mate},
                slots: {_thursday},
                brings: const {Bring.termo},
              ),
            ),
          ]);
        },
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'emits failure when the needs cannot be saved, without the profile',
        setUp: () {
          when(() => needsRepository.save(any()))
              .thenThrow(Exception('keychain'));
        },
        build: buildCubit,
        seed: () => _answered,
        act: (cubit) => cubit.save(),
        expect: () => [
          _answered.copyWith(status: OnboardingStatus.saving),
          _answered.copyWith(status: OnboardingStatus.failure),
        ],
        verify: (_) {
          verifyNever(() => profileRepository.createProfile(any(), any()));
        },
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'publishes only the near and medium daytime seats for a solymar-sur '
        'member for whom walking a lot and coming back at night are hard',
        setUp: () {
          when(
            () => needsRepository.eligibleSeatIds(
              const Needs({Need.walkALot, Need.returnAfterDark}),
              _solymarSurFacts,
            ),
          ).thenReturn(const [
            'solymar-sur_mate_sat-afternoon',
            'solymar-norte_mate_sun-afternoon',
          ]);
        },
        build: buildCubit,
        seed: () => _answered.copyWith(
          barrio: Barrio.solymarSur,
          needs: const {Need.walkALot, Need.returnAfterDark},
        ),
        act: (cubit) => cubit.save(),
        verify: (cubit) {
          expect(cubit.state.status, equals(OnboardingStatus.saved));
          verify(
            () => profileRepository.saveEligibleSeatIds(
              uid: 'demo-uid',
              seatIds: const [
                'solymar-sur_mate_sat-afternoon',
                'solymar-norte_mate_sun-afternoon',
              ],
            ),
          ).called(1);
        },
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'emits failure and writes no profile when the seats cannot be read',
        setUp: () {
          when(() => profileRepository.publishedSeats())
              .thenThrow(const ReadPublishedSeatsFailure());
        },
        build: buildCubit,
        seed: () => _answered,
        act: (cubit) => cubit.save(),
        expect: () => [
          _answered.copyWith(status: OnboardingStatus.saving),
          _answered.copyWith(status: OnboardingStatus.failure),
        ],
        verify: (_) {
          verifyNever(() => profileRepository.createProfile(any(), any()));
        },
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'emits failure and writes no profile when the eligible ids cannot be '
        'written',
        setUp: () {
          when(
            () => profileRepository.saveEligibleSeatIds(
              uid: any(named: 'uid'),
              seatIds: any(named: 'seatIds'),
            ),
          ).thenThrow(const SaveEligibleSeatIdsFailure());
        },
        build: buildCubit,
        seed: () => _answered,
        act: (cubit) => cubit.save(),
        expect: () => [
          _answered.copyWith(status: OnboardingStatus.saving),
          _answered.copyWith(status: OnboardingStatus.failure),
        ],
        verify: (_) {
          verifyNever(() => profileRepository.createProfile(any(), any()));
        },
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'emits failure when the profile cannot be saved',
        setUp: () {
          when(() => profileRepository.createProfile(any(), any()))
              .thenThrow(const SaveProfileFailure());
        },
        build: buildCubit,
        seed: () => _answered,
        act: (cubit) => cubit.save(),
        expect: () => [
          _answered.copyWith(status: OnboardingStatus.saving),
          _answered.copyWith(status: OnboardingStatus.failure),
        ],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'tries again after a failure',
        build: buildCubit,
        seed: () => _answered.copyWith(status: OnboardingStatus.failure),
        act: (cubit) => cubit.save(),
        expect: () => [
          _answered.copyWith(status: OnboardingStatus.saving),
          _answered.copyWith(status: OnboardingStatus.saved),
        ],
      );

      for (final status in [
        OnboardingStatus.saving,
        OnboardingStatus.saved,
        OnboardingStatus.held,
      ]) {
        blocTest<OnboardingCubit, OnboardingState>(
          'does nothing while ${status.name}',
          build: buildCubit,
          seed: () => _answered.copyWith(status: status),
          act: (cubit) => cubit.save(),
          expect: () => const <OnboardingState>[],
        );
      }

      blocTest<OnboardingCubit, OnboardingState>(
        'does nothing away from the read-back',
        build: buildCubit,
        seed: () => _answered.copyWith(step: OnboardingStep.firstName),
        act: (cubit) => cubit.save(),
        expect: () => const <OnboardingState>[],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'does nothing with an answer missing',
        build: buildCubit,
        seed: () => const OnboardingState(step: OnboardingStep.review),
        act: (cubit) => cubit.save(),
        expect: () => const <OnboardingState>[],
      );
    });

    group('signed out', () {
      OnboardingCubit buildSignedOut() => OnboardingCubit(
        uid: '',
        profileRepository: profileRepository,
        needsRepository: needsRepository,
      );

      setUp(() {
        when(() => profileRepository.holdAnswers(any()))
            .thenAnswer((_) async {});
      });

      blocTest<OnboardingCubit, OnboardingState>(
        'save holds the needs and the answers on the phone, and nothing '
        'leaves it',
        build: buildSignedOut,
        seed: () => _answered,
        act: (cubit) => cubit.save(),
        expect: () => [
          _answered.copyWith(status: OnboardingStatus.saving),
          _answered.copyWith(status: OnboardingStatus.held),
        ],
        verify: (_) {
          verifyInOrder([
            () => needsRepository.save(const Needs({Need.noCar})),
            () => profileRepository.holdAnswers(
              Profile(
                firstName: 'Marta',
                ageBand: AgeBand.sixties,
                barrio: Barrio.solymarNorte,
                pretexts: const {Pretext.mate},
                slots: {_thursday},
                brings: const {Bring.termo},
              ),
            ),
          ]);
          verifyNever(profileRepository.publishedSeats);
          verifyNever(() => profileRepository.createProfile(any(), any()));
        },
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'save emits failure when the phone cannot hold the answers',
        setUp: () {
          when(() => profileRepository.holdAnswers(any()))
              .thenThrow(const HoldOnPhoneFailure());
        },
        build: buildSignedOut,
        seed: () => _answered,
        act: (cubit) => cubit.save(),
        expect: () => [
          _answered.copyWith(status: OnboardingStatus.saving),
          _answered.copyWith(status: OnboardingStatus.failure),
        ],
      );
    });

    group('load', () {
      final held = Profile(
        firstName: 'Marta',
        ageBand: AgeBand.sixties,
        barrio: Barrio.solymarNorte,
        pretexts: const {Pretext.mate},
        slots: {_thursday},
        brings: const {Bring.termo},
      );

      /// [held] and the needs on the read-back, as [load] opens them.
      final opened = OnboardingState(
        step: OnboardingStep.review,
        pretexts: const {Pretext.mate},
        brings: const {Bring.termo},
        slots: {_thursday},
        barrio: Barrio.solymarNorte,
        ageBand: AgeBand.sixties,
        needs: const {Need.noCar},
        firstName: const FirstName.dirty('Marta'),
      );

      setUp(() {
        when(profileRepository.heldAnswers).thenAnswer((_) async => held);
        when(needsRepository.read)
            .thenAnswer((_) async => const Needs({Need.noCar}));
      });

      blocTest<OnboardingCubit, OnboardingState>(
        'signed in, opens the held answers and saves them straight away',
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          opened,
          opened.copyWith(status: OnboardingStatus.saving),
          opened.copyWith(status: OnboardingStatus.saved),
        ],
        verify: (_) {
          verify(() => profileRepository.createProfile('demo-uid', held))
              .called(1);
        },
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'signed out, opens the held answers on the read-back',
        build: () => OnboardingCubit(
          uid: '',
          profileRepository: profileRepository,
          needsRepository: needsRepository,
        ),
        act: (cubit) => cubit.load(),
        expect: () => [opened],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'stays on the first question when nothing is held',
        setUp: () {
          when(profileRepository.heldAnswers).thenAnswer((_) async => null);
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => const <OnboardingState>[],
        verify: (_) {
          verifyNever(needsRepository.read);
        },
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'stays on the first question when the needs cannot be read',
        setUp: () {
          when(needsRepository.read).thenThrow(Exception('keychain'));
        },
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => const <OnboardingState>[],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'does nothing on the recorder',
        build: () => OnboardingCubit(
          uid: 'demo-uid',
          profileRepository: profileRepository,
          needsRepository: needsRepository,
          startWithVoice: true,
        ),
        act: (cubit) => cubit.load(),
        expect: () => const <OnboardingState>[],
        verify: (_) {
          verifyNever(profileRepository.heldAnswers);
        },
      );

      test('emits nothing once closed', () async {
        final cubit = buildCubit();
        final load = cubit.load();
        await cubit.close();
        await load;

        expect(cubit.state, equals(const OnboardingState()));
      });
    });

    group('by voice', () {
      test('opens on the recorder when it starts with voice', () {
        final cubit = OnboardingCubit(
          uid: 'demo-uid',
          profileRepository: profileRepository,
          needsRepository: needsRepository,
          startWithVoice: true,
        );

        expect(cubit.state, equals(const OnboardingState(recording: true)));
      });

      blocTest<OnboardingCubit, OnboardingState>(
        'voiceRead opens the read-back with what was understood',
        build: buildCubit,
        seed: () => const OnboardingState(
          recording: true,
          needs: {Need.noCar},
          brings: {Bring.pan},
        ),
        act: (cubit) => cubit.voiceRead(
          const VoiceSignup(
            firstName: 'Graciela',
            ageBand: '60-69',
            barrio: 'solymar-norte',
            pretexts: ['mate', 'bochas'],
            slots: ['thu-afternoon', 'never'],
            brings: ['termo'],
          ),
        ),
        expect: () => [
          OnboardingState(
            step: OnboardingStep.review,
            pretexts: const {Pretext.mate},
            brings: const {Bring.termo},
            slots: {_thursday},
            barrio: Barrio.solymarNorte,
            ageBand: AgeBand.sixties,
            needs: const {Need.noCar},
            firstName: const FirstName.dirty('Graciela'),
            fromVoice: true,
          ),
        ],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'voiceRead leaves out what was not said',
        build: buildCubit,
        seed: () => const OnboardingState(recording: true),
        act: (cubit) => cubit.voiceRead(const VoiceSignup(pretexts: ['truco'])),
        expect: () => const [
          OnboardingState(
            step: OnboardingStep.review,
            pretexts: {Pretext.truco},
            fromVoice: true,
          ),
        ],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'recordAgain opens the recorder',
        build: buildCubit,
        seed: () => _answered.copyWith(fromVoice: true),
        act: (cubit) => cubit.recordAgain(),
        expect: () => [_answered.copyWith(fromVoice: true, recording: true)],
      );

      blocTest<OnboardingCubit, OnboardingState>(
        'voiceCancelled opens the first question by buttons',
        build: buildCubit,
        seed: () => const OnboardingState(recording: true),
        act: (cubit) => cubit.voiceCancelled(),
        expect: () => const [OnboardingState()],
      );
    });
  });

  group(OnboardingState, () {
    test('isComplete needs every answer but the needs', () {
      expect(_answered.copyWith(needs: const {}).isComplete, isTrue);
      expect(_answered.copyWith(pretexts: const {}).isComplete, isFalse);
      expect(_answered.copyWith(brings: const {}).isComplete, isFalse);
      expect(_answered.copyWith(slots: const {}).isComplete, isFalse);
      expect(
        _answered.copyWith(firstName: const FirstName.dirty()).isComplete,
        isFalse,
      );
      expect(
        const OnboardingState(
          pretexts: {Pretext.mate},
          brings: {Bring.termo},
          firstName: FirstName.dirty('Marta'),
        ).isComplete,
        isFalse,
      );
    });

    test('a save is underway while saving, saved or held', () {
      expect(
        [
          for (final status in OnboardingStatus.values)
            if (status.isUnderway) status,
        ],
        equals([
          OnboardingStatus.saving,
          OnboardingStatus.saved,
          OnboardingStatus.held,
        ]),
      );
    });

    test('questions lists every step but the read-back', () {
      expect(OnboardingStep.questions, hasLength(7));
      expect(OnboardingStep.questions, isNot(contains(OnboardingStep.review)));
    });
    test('coveredIdeas ticks every idea of a complete answer', () {
      expect(_answered.coveredIdeas, equals([true, true, true, true]));
    });

    test('coveredIdeas needs both the name and the barrio first', () {
      expect(
        const OnboardingState(firstName: FirstName.dirty('Graciela'))
            .coveredIdeas,
        equals([false, false, false, false]),
      );
    });
  });
}
