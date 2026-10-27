import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:needs_repository/needs_repository.dart';
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

void main() {
  group(OnboardingCubit, () {
    late ProfileRepository profileRepository;
    late NeedsRepository needsRepository;

    setUpAll(() {
      registerFallbackValue(Needs.none);
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
        'saves the needs on the phone, then the profile without them',
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

      for (final status in [OnboardingStatus.saving, OnboardingStatus.saved]) {
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

    test('questions lists every step but the read-back', () {
      expect(OnboardingStep.questions, hasLength(7));
      expect(OnboardingStep.questions, isNot(contains(OnboardingStep.review)));
    });
  });
}
