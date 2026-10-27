part of 'onboarding_cubit.dart';

/// The screens of onboarding by buttons, in order.
enum OnboardingStep {
  /// "¿Qué te gustaría hacer?"
  pretexts,

  /// "¿Qué podés llevar o enseñar?"
  brings,

  /// "¿Cuándo podés?"
  slots,

  /// "¿En qué barrio estás?"
  barrio,

  /// "¿Qué edad tenés, más o menos?"
  ageBand,

  /// "¿Hay algo que te complique ir?" (optional)
  needs,

  /// "¿Cómo te llamás?"
  firstName,

  /// The read-back, with "Está bien, guardalo".
  review;

  /// The questions, without the read-back.
  static final List<OnboardingStep> questions = values
      .where((step) => step != review)
      .toList();
}

/// Where saving stands.
enum OnboardingStatus {
  /// Answering the questions.
  editing,

  /// "Está bien, guardalo" was tapped and the save is in flight.
  saving,

  /// Saved; the router moves on once the profile arrives.
  saved,

  /// The save failed; the read-back offers it again.
  failure,
}

final class const OnboardingState({
  final OnboardingStep step = OnboardingStep.pretexts,
  final Set<Pretext> pretexts = const {},
  final Set<Bring> brings = const {},
  final Set<Slot> slots = const {},
  final Barrio? barrio,
  final AgeBand? ageBand,
  final Set<Need> needs = const {},
  final FirstName firstName = const FirstName.pure(),

  /// Whether the open step was reached with "Cambiar" on the read-back, so
  /// "Seguir" returns there.
  final bool editingFromReview = false,
  final OnboardingStatus status = OnboardingStatus.editing,
}) extends Equatable {
  /// Whether the open step has what it needs for "Seguir".
  bool get canContinue => switch (step) {
    OnboardingStep.pretexts => pretexts.isNotEmpty,
    OnboardingStep.brings => brings.isNotEmpty,
    OnboardingStep.slots => slots.isNotEmpty,
    OnboardingStep.barrio => barrio != null,
    OnboardingStep.ageBand => ageBand != null,
    OnboardingStep.needs => true,
    OnboardingStep.firstName => firstName.isValid,
    OnboardingStep.review => false,
  };

  /// Whether every answer the profile needs is in.
  bool get isComplete =>
      pretexts.isNotEmpty &&
      brings.isNotEmpty &&
      slots.isNotEmpty &&
      barrio != null &&
      ageBand != null &&
      firstName.isValid;

  OnboardingState copyWith({
    OnboardingStep? step,
    Set<Pretext>? pretexts,
    Set<Bring>? brings,
    Set<Slot>? slots,
    Barrio? barrio,
    AgeBand? ageBand,
    Set<Need>? needs,
    FirstName? firstName,
    bool? editingFromReview,
    OnboardingStatus? status,
  }) => OnboardingState(
    step: step ?? this.step,
    pretexts: pretexts ?? this.pretexts,
    brings: brings ?? this.brings,
    slots: slots ?? this.slots,
    barrio: barrio ?? this.barrio,
    ageBand: ageBand ?? this.ageBand,
    needs: needs ?? this.needs,
    firstName: firstName ?? this.firstName,
    editingFromReview: editingFromReview ?? this.editingFromReview,
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => [
    step,
    pretexts,
    brings,
    slots,
    barrio,
    ageBand,
    needs,
    firstName,
    editingFromReview,
    status,
  ];
}
