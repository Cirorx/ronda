part of 'small_plan_choose_cubit.dart';

/// Where the sheet is.
enum SmallPlanStep {
  /// The three ideas and "Decilo vos".
  ideas,

  /// "Contanos qué te gustaría hacer": the microphone and the text field.
  say,

  /// Recording; [SmallPlanChooseState.elapsed] counts up to the limit.
  recording,

  /// Uploading, transcribing and shaping what was said.
  reading,

  /// "¿Es esto?": [SmallPlanChooseState.read] holds the plan.
  review,
}

/// Whether the ideas could be had.
enum SmallPlanIdeas { loading, ready, failure }

final class const SmallPlanChooseState({
  final SmallPlanStep step = SmallPlanStep.ideas,
  final SmallPlanIdeas ideas = SmallPlanIdeas.loading,
  final List<SmallPlanSuggestion> suggestions = const [],

  /// What was typed.
  final PlanText text = const PlanText.pure(),

  /// "Listo" was tapped with the field empty or too long.
  final bool textTried = false,

  /// How long the note has been recording.
  final Duration elapsed = Duration.zero,

  /// The last [SmallPlanChooseCubit.waveformLength] levels heard, newest
  /// last, each from 0 (silence) to 1.
  final List<double> levels = const [],

  /// How many levels have been heard since recording started.
  final int heard = 0,

  /// Whether the microphone has heard nothing for
  /// [SmallPlanChooseCubit.silentAfter].
  final bool silent = false,

  /// The plan made of what was said, at [SmallPlanStep.review].
  final SmallPlanRead? read,

  /// Why what was said was left out.
  final PlanDropReason? dropped,

  /// What failed.
  final SmallPlanFailureKind? failure,

  /// What the server answered when it failed; for the error log, never
  /// shown.
  final String? failureCode,

  /// The plan the member chose: the sheet closes with it.
  final SmallPlan? chosen,
}) extends Equatable {
  /// A copy with the given fields changed; a function for each field that
  /// may become `null`.
  SmallPlanChooseState copyWith({
    SmallPlanStep? step,
    SmallPlanIdeas? ideas,
    List<SmallPlanSuggestion>? suggestions,
    PlanText? text,
    bool? textTried,
    Duration? elapsed,
    List<double>? levels,
    int? heard,
    bool? silent,
    SmallPlanRead? Function()? read,
    PlanDropReason? Function()? dropped,
    SmallPlanFailureKind? Function()? failure,
    String? Function()? failureCode,
    SmallPlan? Function()? chosen,
  }) => SmallPlanChooseState(
    step: step ?? this.step,
    ideas: ideas ?? this.ideas,
    suggestions: suggestions ?? this.suggestions,
    text: text ?? this.text,
    textTried: textTried ?? this.textTried,
    elapsed: elapsed ?? this.elapsed,
    levels: levels ?? this.levels,
    heard: heard ?? this.heard,
    silent: silent ?? this.silent,
    read: read == null ? this.read : read(),
    dropped: dropped == null ? this.dropped : dropped(),
    failure: failure == null ? this.failure : failure(),
    failureCode: failureCode == null ? this.failureCode : failureCode(),
    chosen: chosen == null ? this.chosen : chosen(),
  );

  @override
  List<Object?> get props => [
    step,
    ideas,
    suggestions,
    text,
    textTried,
    elapsed,
    levels,
    heard,
    silent,
    read,
    dropped,
    failure,
    failureCode,
    chosen,
  ];
}
