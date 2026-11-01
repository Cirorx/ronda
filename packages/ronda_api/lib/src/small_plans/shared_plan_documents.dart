import 'package:equatable/equatable.dart';

/// {@template shared_plan_line_document}
/// Another member's plan on the ronda, as it reads on this member's plan
/// card (`functions/shared_plans.py`): who proposes it, what, where and when,
/// and whether this member already joined. Never who else did.
/// {@endtemplate}
final class const SharedPlanLineDocument({
  /// The author's uid, which `join_small_plan` takes.
  required final String id,

  /// The author's first name.
  required final String firstName,

  /// What they want to do, as the phone worded it.
  required final String activity,

  /// Where, with its preposition; empty when [activity] already says it.
  required final String place,

  /// `walk`, `feria`, `library`, `call`, `noPhone` or `other`.
  required final String kind,

  /// The day, `YYYY-MM-DD`.
  required final String date,

  /// The time, `HH:MM`.
  required final String time,

  /// Whether this member said "Me sumo".
  required final bool joined,
}) extends Equatable {
  /// {@macro shared_plan_line_document}
  this;

  /// Reads one line; throws a [FormatException] for any other shape.
  factory fromJson(Object? json) => switch (json) {
    {
      'id': final String id,
      'firstName': final String firstName,
      'activity': final String activity,
      'place': final String place,
      'kind': final String kind,
      'date': final String date,
      'time': final String time,
      'joined': final bool joined,
    } =>
      SharedPlanLineDocument(
        id: id,
        firstName: firstName,
        activity: activity,
        place: place,
        kind: kind,
        date: date,
        time: time,
        joined: joined,
      ),
    _ => throw const FormatException('not a shared plan line'),
  };

  @override
  List<Object?> get props => [
    id,
    firstName,
    activity,
    place,
    kind,
    date,
    time,
    joined,
  ];
}

/// {@template shared_plan_mine_document}
/// This member's own plan, opened to the ronda, with the first names of
/// whoever said "Me sumo".
/// {@endtemplate}
final class const SharedPlanMineDocument({
  /// What they want to do.
  required final String activity,

  /// Where, with its preposition; empty when [activity] already says it.
  required final String place,

  /// The plan's kind.
  required final String kind,

  /// The day, `YYYY-MM-DD`.
  required final String date,

  /// The time, `HH:MM`.
  required final String time,

  /// First names, in the order they joined; empty while nobody has.
  required final List<String> joined,
}) extends Equatable {
  /// {@macro shared_plan_mine_document}
  this;

  /// Reads the plan; throws a [FormatException] for any other shape.
  factory fromJson(Object? json) => switch (json) {
    {
      'activity': final String activity,
      'place': final String place,
      'kind': final String kind,
      'date': final String date,
      'time': final String time,
      'joined': final List<Object?> joined,
    } =>
      SharedPlanMineDocument(
        activity: activity,
        place: place,
        kind: kind,
        date: date,
        time: time,
        joined: [
          for (final name in joined)
            switch (name) {
              final String name => name,
              _ => throw const FormatException('not a first name'),
            },
        ],
      ),
    _ => throw const FormatException('not a shared plan'),
  };

  @override
  List<Object?> get props => [activity, place, kind, date, time, joined];
}

/// {@template shared_plan_card_document}
/// `rondas/{id}/plan_cards/{uid}`: what one member reads of ¿Alguien se
/// suma?: the others' plans, and their own with who joined it. Only that
/// member reads it.
/// {@endtemplate}
final class const SharedPlanCardDocument({
  /// The other members' plans still ahead, soonest first.
  required final List<SharedPlanLineDocument> lines,

  /// This member's own shared plan, if they opened one.
  final SharedPlanMineDocument? mine,
}) extends Equatable {
  /// {@macro shared_plan_card_document}
  this;

  /// Reads the card; throws a [FormatException] for any other shape.
  factory fromJson(Map<String, dynamic> json) => switch (json) {
    {'plans': final List<Object?> plans} => SharedPlanCardDocument(
      lines: [for (final plan in plans) SharedPlanLineDocument.fromJson(plan)],
      mine: switch (json['mine']) {
        null => null,
        final mine => SharedPlanMineDocument.fromJson(mine),
      },
    ),
    _ => throw const FormatException('the plan card has another shape'),
  };

  @override
  List<Object?> get props => [lines, mine];
}
