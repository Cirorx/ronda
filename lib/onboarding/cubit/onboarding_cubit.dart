import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/onboarding/models/models.dart';

part 'onboarding_state.dart';

/// Onboarding by buttons: one question per step, a read-back, and the save.
///
/// The profile goes to `users/{uid}` through [ProfileRepository]; the needs
/// stay on this phone through [NeedsRepository] and never reach the profile.
/// Where the person goes after saving is the router's call: it follows the
/// profile, not this cubit.
class OnboardingCubit extends Cubit<OnboardingState> {
  new({
    required this._uid,
    required this._profileRepository,
    required this._needsRepository,
  }) : super(const OnboardingState());

  final String _uid;
  final ProfileRepository _profileRepository;
  final NeedsRepository _needsRepository;

  /// What the person would like to do.
  void pretextsChanged(Set<Pretext> pretexts) =>
      emit(state.copyWith(pretexts: pretexts));

  /// What the person brings or teaches.
  void bringsChanged(Set<Bring> brings) => emit(state.copyWith(brings: brings));

  /// When the person can.
  void slotsChanged(Set<Slot> slots) => emit(state.copyWith(slots: slots));

  /// The person's barrio.
  void barrioChanged(Barrio barrio) => emit(state.copyWith(barrio: barrio));

  /// The person's age band.
  void ageBandChanged(AgeBand ageBand) =>
      emit(state.copyWith(ageBand: ageBand));

  /// Marks or unmarks one thing that makes it hard to go.
  void needToggled(Need need, {required bool marked}) => emit(
    state.copyWith(
      needs: marked ? {...state.needs, need} : ({...state.needs}..remove(need)),
    ),
  );

  /// The first name as typed.
  void firstNameChanged(String value) =>
      emit(state.copyWith(firstName: FirstName.dirty(value)));

  /// "Seguir": the next question, or back to the read-back after a
  /// "Cambiar". Does nothing while the open step is unanswered.
  void next() {
    if (!state.canContinue) return;
    emit(
      state.copyWith(
        step: state.editingFromReview
            ? OnboardingStep.review
            : OnboardingStep.values[state.step.index + 1],
        editingFromReview: false,
      ),
    );
  }

  /// "Saltear" on the needs step: none marked, and on.
  void needsSkipped() {
    if (state.step != OnboardingStep.needs) return;
    emit(state.copyWith(needs: const {}));
    next();
  }

  /// Back one question, or back to the read-back after a "Cambiar". Does
  /// nothing on the first question.
  void back() {
    if (state.editingFromReview) {
      emit(
        state.copyWith(step: OnboardingStep.review, editingFromReview: false),
      );
      return;
    }
    if (state.step.index == 0) return;
    emit(state.copyWith(step: OnboardingStep.values[state.step.index - 1]));
  }

  /// "Cambiar" on the read-back: opens [step]; "Seguir" comes back.
  void edit(OnboardingStep step) {
    if (state.step != OnboardingStep.review) return;
    if (step == OnboardingStep.review) return;
    emit(state.copyWith(step: step, editingFromReview: true));
  }

  /// "Está bien, guardalo": the needs on this phone first, then the profile,
  /// whose arrival moves the router on.
  Future<void> save() async {
    final OnboardingState(:ageBand, :barrio, :status) = state;
    if (state.step != OnboardingStep.review || !state.isComplete) return;
    if (ageBand == null || barrio == null) return;
    if (status case OnboardingStatus.saving || OnboardingStatus.saved) return;
    emit(state.copyWith(status: OnboardingStatus.saving));
    try {
      final needs = Needs(state.needs);
      await _needsRepository.save(needs);
      await _publishEligibleSeatIds(needs);
      await _profileRepository.createProfile(
        _uid,
        Profile(
          firstName: state.firstName.name,
          ageBand: ageBand,
          barrio: barrio,
          pretexts: state.pretexts,
          slots: state.slots,
          brings: state.brings,
        ),
      );
      emit(state.copyWith(status: OnboardingStatus.saved));
    } on Exception {
      emit(state.copyWith(status: OnboardingStatus.failure));
    }
  }

  /// The seam for #20: filter the seats with [needs] on this phone and
  /// write only the eligible seat ids to `users/{uid}/private/eligible`.
  /// It runs after the needs are saved and before the profile, so the
  /// router can't leave onboarding before the ids are written.
  Future<void> _publishEligibleSeatIds(Needs needs) async {}
}
