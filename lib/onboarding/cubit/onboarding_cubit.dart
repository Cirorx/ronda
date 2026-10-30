import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/onboarding/models/models.dart';

part 'onboarding_state.dart';

/// Onboarding: by buttons, one question per step, or by voice, a recording
/// read into the same answers; then the read-back and the save.
///
/// The profile goes to `users/{uid}` through [ProfileRepository]; the needs
/// stay on this phone through [NeedsRepository] and never reach the profile.
/// Only the seat ids they let through leave the phone, to
/// `users/{uid}/private/eligible`. Where the person goes after saving is the
/// router's call: it follows the profile, not this cubit.
///
/// Signed out (no uid), "Está bien, guardalo" holds the answers on this
/// phone instead ([OnboardingStatus.held]), and the payoff and sign-in come
/// next. Once someone signs in, [load] finds them and saves them.
class OnboardingCubit extends Cubit<OnboardingState> {
  new({
    required this._uid,
    required this._profileRepository,
    required this._needsRepository,
    bool startWithVoice = false,
  }) : super(OnboardingState(recording: startWithVoice));

  /// The signed-in person's uid, or empty while nobody is signed in.
  final String _uid;
  final ProfileRepository _profileRepository;
  final NeedsRepository _needsRepository;

  bool get _signedIn => _uid.isNotEmpty;

  /// Opens the answers held on this phone, if any, on the read-back; for
  /// someone signed in, saves them straight away. Does nothing on the
  /// recorder, or when nothing is held.
  Future<void> load() async {
    if (state.recording) return;
    final Profile? held;
    final Needs needs;
    try {
      held = await _profileRepository.heldAnswers();
      if (held == null) return;
      needs = await _needsRepository.read();
    } on Exception {
      // Unreadable needs would save a filter they never chose: ask again.
      return;
    }
    if (isClosed) return;
    emit(
      OnboardingState(
        step: OnboardingStep.review,
        pretexts: held.pretexts,
        brings: held.brings,
        slots: held.slots,
        barrio: held.barrio,
        ageBand: held.ageBand,
        needs: needs.values,
        firstName: FirstName.dirty(held.firstName),
      ),
    );
    if (_signedIn) await save();
  }

  /// What a voice note said: the answers it understood replace the ones
  /// held, and the read-back opens. Ids nobody stores are dropped.
  void voiceRead(VoiceSignup signup) => emit(
    OnboardingState(
      step: OnboardingStep.review,
      pretexts: {for (final id in signup.pretexts) ?Pretext.fromId(id)},
      brings: {for (final id in signup.brings) ?Bring.fromId(id)},
      slots: {for (final id in signup.slots) ?Slot.fromId(id)},
      barrio: Barrio.fromId(signup.barrio),
      ageBand: AgeBand.fromId(signup.ageBand),
      needs: state.needs,
      firstName: switch (signup.firstName) {
        final name? => FirstName.dirty(name),
        null => const FirstName.pure(),
      },
      fromVoice: true,
    ),
  );

  /// "Grabar de nuevo" on the voice read-back: the recorder opens again.
  void recordAgain() => emit(state.copyWith(recording: true));

  /// "Cancelar" or "Prefiero tocar botones" on the recorder: the questions
  /// by buttons, from the first one.
  void voiceCancelled() => emit(const OnboardingState());

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

  /// "Está bien, guardalo": the needs on this phone first, then the seat ids
  /// they allow, then the profile, whose arrival moves the router on.
  ///
  /// Any step failing fails the save and writes no profile, so the person
  /// stays on the read-back and "Está bien, guardalo" runs every step again:
  /// the solver can't seat someone whose eligible ids never arrived.
  ///
  /// Signed out, it keeps the needs and the answers on this phone instead,
  /// and nothing leaves it: the seats are read only once signed in.
  Future<void> save() async {
    final OnboardingState(:ageBand, :barrio, :status) = state;
    if (state.step != OnboardingStep.review || !state.isComplete) return;
    if (ageBand == null || barrio == null) return;
    if (status.isUnderway) return;
    emit(state.copyWith(status: OnboardingStatus.saving));
    final needs = Needs(state.needs);
    final answers = Profile(
      firstName: state.firstName.name,
      ageBand: ageBand,
      barrio: barrio,
      pretexts: state.pretexts,
      slots: state.slots,
      brings: state.brings,
    );
    try {
      await _needsRepository.save(needs);
      if (!_signedIn) {
        await _profileRepository.holdAnswers(answers);
        emit(state.copyWith(status: OnboardingStatus.held));
        return;
      }
      await _publishEligibleSeatIds(needs, barrio);
      await _profileRepository.createProfile(_uid, answers);
      emit(state.copyWith(status: OnboardingStatus.saved));
    } on Exception {
      emit(state.copyWith(status: OnboardingStatus.failure));
    }
  }

  /// Filters the published seats with [needs] on this phone, measuring each
  /// walk from [barrio], and writes only the ids that pass.
  ///
  /// Pretext and slot are not filtered here: the solver matches those
  /// against the profile.
  Future<void> _publishEligibleSeatIds(Needs needs, Barrio barrio) async {
    final seats = await _profileRepository.publishedSeats();
    final facts = [
      for (final seat in seats)
        SeatFacts(
          seatId: seat.seatId,
          walkDistance: WalkDistance.forMember(
            memberBarrio: barrio.id,
            blocksFrom: seat.blocksFrom,
          ),
          hasStairs: seat.hasStairs,
          endsAfterDark: seat.endsAfterDark,
          needsCar: seat.needsCar,
        ),
    ];
    await _profileRepository.saveEligibleSeatIds(
      uid: _uid,
      seatIds: _needsRepository.eligibleSeatIds(needs, facts),
    );
  }
}
