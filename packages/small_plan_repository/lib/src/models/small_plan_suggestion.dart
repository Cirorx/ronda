import 'package:equatable/equatable.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:small_plan_repository/src/models/small_plan.dart';

/// {@template small_plan_suggestion}
/// One of the three ideas Ronda offers: a [kind] of thing, the free public
/// [place] for it when it has one, and the day and time found for it, dry
/// when it is outdoors ([dry] is `null` when there is no forecast).
/// {@endtemplate}
class const SmallPlanSuggestion({
  required final String id,
  required final SmallPlanKind kind,
  required final DateTime at,
  required final bool outdoor,
  final String? place,
  final bool? dry,
}) extends Equatable {
  /// {@macro small_plan_suggestion}
  this;

  /// The suggestion in the callable's wire shape.
  factory fromDocument(SmallPlanSuggestionDocument document) =>
      SmallPlanSuggestion(
        id: document.id,
        kind: SmallPlanKind.fromName(document.kind),
        at: parseWhen(document.date, document.time),
        outdoor: document.outdoor,
        place: document.place,
        dry: document.dry,
      );

  /// A day (`YYYY-MM-DD`) and a time (`HH:MM`) as one local [DateTime].
  /// Throws a [FormatException] for anything else.
  static DateTime parseWhen(String date, String time) {
    final day = DateTime.tryParse(date);
    final clock = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(time);
    if (day == null || clock == null) {
      throw FormatException('not a day and a time: $date $time');
    }
    return DateTime(
      day.year,
      day.month,
      day.day,
      int.parse(clock[1]!),
      int.parse(clock[2]!),
    );
  }

  /// What choosing this suggestion makes: the plan, with the words left to
  /// the screen.
  SmallPlan get plan => SmallPlan(kind: kind, at: at, place: place);

  @override
  List<Object?> get props => [id, kind, at, outdoor, place, dry];
}
