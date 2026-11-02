import 'package:equatable/equatable.dart';
import 'package:ronda/onboarding/cubit/onboarding_cubit.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// {@template onboarding_screen}
/// Which onboarding screen is open: the recorder, what a voice note left
/// out, or a step opened with "Cambiar" on the read-back or on the way
/// through.
/// {@endtemplate}
final class const OnboardingScreen({
  /// The open step, or `null` for the recorder.
  final OnboardingStep? step,

  /// Whether [step] was opened with "Cambiar" on the read-back.
  final bool editing = false,

  /// Whether this is the screen of what a voice note left out
  /// ([OnboardingState.gaps]), before the read-back.
  final bool gaps = false,
}) extends Equatable {
  /// {@macro onboarding_screen}
  this;

  /// The screen [state] shows.
  factory of(OnboardingState state) => switch (state) {
    OnboardingState(recording: true) => const OnboardingScreen(),
    OnboardingState(:final gaps) when gaps.isNotEmpty => const OnboardingScreen(
      step: OnboardingStep.review,
      gaps: true,
    ),
    _ => OnboardingScreen(step: state.step, editing: state.editingFromReview),
  };

  /// The question's number among the questions, from 1, or `null` on the
  /// read-back, the recorder and what a voice note left out.
  int? get questionNumber => switch (step) {
    _ when gaps => null,
    null || OnboardingStep.review => null,
    final step => OnboardingStep.questions.indexOf(step) + 1,
  };

  /// Whether coming here from [previous] moves forward (a [StepSwitcher]'s
  /// direction): on to a later step,
  /// into a "Cambiar", into the recorder or out of it, into what a voice
  /// note left out or on from it. Back is the other
  /// way, and so is leaving a "Cambiar" for the read-back, as a pushed
  /// screen closes.
  bool isForwardFrom(OnboardingScreen previous) {
    final (from, to) = (previous.step, step);
    if (from == null || to == null) return true;
    if (gaps != previous.gaps) return true;
    if (editing != previous.editing) return editing;
    return to.index > from.index;
  }

  @override
  List<Object?> get props => [step, editing, gaps];
}
