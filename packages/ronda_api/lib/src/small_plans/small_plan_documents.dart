import 'package:equatable/equatable.dart';

/// {@template small_plan_suggestion_document}
/// One suggestion from `suggest_small_plans`: a kind of thing to do, the
/// free public place for it when it has one, and the day and time the server
/// found for it. The app writes the sentence, in the phone's language.
/// {@endtemplate}
final class const SmallPlanSuggestionDocument({
  /// The suggestion's id within one answer, such as `walk-1`.
  required final String id,

  /// `walk`, `feria`, `library`, `call` or `noPhone`.
  required final String kind,

  /// The day, `YYYY-MM-DD`.
  required final String date,

  /// The time, `HH:MM`.
  required final String time,

  /// Whether it happens outdoors.
  required final bool outdoor,

  /// The place's name with its article ("la Plaza de los Aromos"), or
  /// `null` for a suggestion with no place.
  final String? place,

  /// Whether the forecast calls that day dry: `null` when there is no
  /// forecast or the plan is indoors.
  final bool? dry,
}) extends Equatable {
  /// {@macro small_plan_suggestion_document}
  this;

  /// Reads one suggestion; throws a [FormatException] for any other shape.
  factory fromJson(Object? json) => switch (json) {
    {
      'id': final String id,
      'kind': final String kind,
      'date': final String date,
      'time': final String time,
      'outdoor': final bool outdoor,
    } =>
      SmallPlanSuggestionDocument(
        id: id,
        kind: kind,
        date: date,
        time: time,
        outdoor: outdoor,
        place: switch (json['place']) {
          final String place => place,
          _ => null,
        },
        dry: switch (json['dry']) {
          final bool dry => dry,
          _ => null,
        },
      ),
    _ => throw const FormatException('not a small plan suggestion'),
  };

  @override
  List<Object?> get props => [id, kind, date, time, outdoor, place, dry];
}

/// {@template shaped_small_plan_document}
/// The plan `shape_small_plan` made of what the member said: [activity] in
/// their words, a [date] and a [time], and the place if they named one.
/// {@endtemplate}
final class const ShapedSmallPlanDocument({
  /// What they want to do, in a short phrase.
  required final String activity,

  /// The day, `YYYY-MM-DD`.
  required final String date,

  /// The time, `HH:MM`.
  required final String time,

  /// `walk`, `feria`, `library`, `call`, `noPhone` or `other`.
  required final String kind,

  /// Whether it happens outdoors.
  required final bool outdoor,

  /// Whether the day moved from the one they named, because it rains.
  required final bool moved,

  /// Where, as they said it, with its preposition.
  final String? place,

  /// Whether the forecast calls that day dry; `null` when it has no word.
  final bool? dry,
}) extends Equatable {
  /// {@macro shaped_small_plan_document}
  this;

  /// Reads the plan; throws a [FormatException] for any other shape.
  factory fromJson(Object? json) => switch (json) {
    {
      'activity': final String activity,
      'date': final String date,
      'time': final String time,
      'kind': final String kind,
      'outdoor': final bool outdoor,
      'moved': final bool moved,
    } =>
      ShapedSmallPlanDocument(
        activity: activity,
        date: date,
        time: time,
        kind: kind,
        outdoor: outdoor,
        moved: moved,
        place: switch (json['place']) {
          final String place => place,
          _ => null,
        },
        dry: switch (json['dry']) {
          final bool dry => dry,
          _ => null,
        },
      ),
    _ => throw const FormatException('not a shaped small plan'),
  };

  @override
  List<Object?> get props => [
    activity,
    date,
    time,
    kind,
    outdoor,
    moved,
    place,
    dry,
  ];
}

/// What `shape_small_plan` answered.
sealed class SmallPlanAnswer extends Equatable {
  /// An answer.
  const new();

  /// Reads the answer: `{plan}` or `{rejected}`; a [FormatException] for any
  /// other shape.
  factory fromJson(Object? json) => switch (json) {
    {'plan': final Object? plan} => SmallPlanShaped(
      ShapedSmallPlanDocument.fromJson(plan),
    ),
    {'rejected': final String reason} => SmallPlanRejected(reason),
    _ => throw const FormatException('shape_small_plan returned no answer'),
  };
}

/// {@template small_plan_shaped}
/// The member's words became a [plan].
/// {@endtemplate}
final class const SmallPlanShaped(final ShapedSmallPlanDocument plan)
    extends SmallPlanAnswer {
  /// {@macro small_plan_shaped}
  this;

  @override
  List<Object?> get props => [plan];
}

/// {@template small_plan_rejected}
/// The plan was dropped: [reason] is `health`, `diet`, `money`, `people` or
/// `unclear`.
/// {@endtemplate}
final class const SmallPlanRejected(final String reason)
    extends SmallPlanAnswer {
  /// {@macro small_plan_rejected}
  this;

  @override
  List<Object?> get props => [reason];
}
