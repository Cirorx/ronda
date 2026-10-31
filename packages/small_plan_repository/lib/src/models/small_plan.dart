import 'package:equatable/equatable.dart';

/// What a small plan is about: the five suggestions, and [other] for what a
/// member said that fits none of them.
enum SmallPlanKind {
  /// A walk, on a route nearby.
  walk,

  /// The feria.
  feria,

  /// The branch library.
  library,

  /// Calling someone they haven't talked to in a while.
  call,

  /// An afternoon without the phone.
  noPhone,

  /// Anything else the member said.
  other;

  /// The kind the server named, or `other` for a name this app doesn't know.
  static SmallPlanKind fromName(String name) =>
      SmallPlanKind.values.asNameMap()[name] ?? other;
}

/// {@template small_plan}
/// One small plan for the week: a [kind] of thing to do, [at] (a day and
/// a time on the phone's clock), and where. The [activity] is the member's
/// own phrase when they said it; it is `null` for a suggestion, which the
/// screen words from its [kind] and [place].
///
/// It lives on the phone only (`SmallPlanRepository`); the server never
/// stores it.
/// {@endtemplate}
class const SmallPlan({
  required final SmallPlanKind kind,
  required final DateTime at,
  final String? place,
  final String? activity,
}) extends Equatable {
  /// {@macro small_plan}
  this;

  /// Reads a stored plan; throws a [FormatException] for any other shape.
  factory fromJson(Object? json) => switch (json) {
    {'kind': final String kind, 'at': final String at} => SmallPlan(
      kind: SmallPlanKind.fromName(kind),
      at: DateTime.parse(at),
      place: switch (json['place']) {
        final String place => place,
        _ => null,
      },
      activity: switch (json['activity']) {
        final String activity => activity,
        _ => null,
      },
    ),
    _ => throw const FormatException('not a small plan'),
  };

  /// The plan as it is stored.
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'at': at.toIso8601String(),
    'place': ?place,
    'activity': ?activity,
  };

  @override
  List<Object?> get props => [kind, at, place, activity];
}
