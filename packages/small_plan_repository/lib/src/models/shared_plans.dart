import 'package:equatable/equatable.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:small_plan_repository/src/models/small_plan.dart';
import 'package:small_plan_repository/src/models/small_plan_suggestion.dart';

/// Why a plan was held back from the ronda, in the words the screen turns
/// into a plain sentence. The plan stays private on the phone.
enum ShareHoldReason {
  /// The plan's time has passed, or is too far ahead.
  past,

  /// Outside 09:00 to 21:00.
  time,

  /// An emoji or a form Ronda doesn't use.
  words,

  /// It mentions money.
  money,

  /// It looks like an address or a home.
  address,

  /// It carries a phone number.
  phone,

  /// It names no public place.
  place,

  /// Anything else: a topic Ronda's small plans don't carry.
  other;

  /// The reason the server named, or [other] for one this app doesn't know.
  static ShareHoldReason fromName(String name) =>
      ShareHoldReason.values.asNameMap()[name] ?? other;
}

/// {@template shared_plan_held}
/// A plan was not opened to the ronda, for [reason].
/// {@endtemplate}
class const SharedPlanHeld(final ShareHoldReason reason) implements Exception {
  /// {@macro shared_plan_held}
  this;

  @override
  String toString() => 'SharedPlanHeld(${reason.name})';
}

/// {@template shared_plan_line}
/// Another member's plan on the ronda: "Ana propone: …", with [Me sumo].
/// {@endtemplate}
final class const SharedPlanLine({
  /// The author's uid, to join by.
  required final String authorUid,

  /// The author's first name.
  required final String firstName,

  /// What they want to do, as their phone worded it.
  required final String activity,

  /// Where, with its preposition; `null` when [activity] says it.
  required final String? place,

  /// The plan's kind.
  required final SmallPlanKind kind,

  /// When, on the phone's clock.
  required final DateTime at,

  /// Whether this member already said "Me sumo".
  required final bool joined,
}) extends Equatable {
  /// {@macro shared_plan_line}
  this;

  @override
  List<Object?> get props => [
    authorUid,
    firstName,
    activity,
    place,
    kind,
    at,
    joined,
  ];
}

/// {@template shared_plan_mine}
/// This member's own plan, opened to the ronda, and the first names of whoever
/// said "Me sumo". [joined] is empty while nobody has, and nothing is shown
/// then.
/// {@endtemplate}
final class const SharedPlanMine({
  /// When, on the phone's clock.
  required final DateTime at,

  /// First names, in the order they joined.
  required final List<String> joined,
}) extends Equatable {
  /// {@macro shared_plan_mine}
  this;

  @override
  List<Object?> get props => [at, joined];
}

/// {@template shared_plans}
/// What ¿Alguien se suma? shows a member: the others' plans still ahead,
/// and their own plan if they opened it.
/// {@endtemplate}
final class const SharedPlans({
  /// The others' plans, soonest first.
  final List<SharedPlanLine> lines = const [],

  /// This member's own shared plan.
  final SharedPlanMine? mine,
}) extends Equatable {
  /// {@macro shared_plans}
  this;

  /// Reads a card, leaving out what is already past at [now].
  ///
  /// Throws a [FormatException] for a date or time it can't read.
  factory fromDocument(SharedPlanCardDocument? card, DateTime now) {
    if (card == null) return const SharedPlans();
    final lines = [
      for (final line in card.lines)
        if (SmallPlanSuggestion.parseWhen(line.date, line.time) case final at
            when at.isAfter(now))
          SharedPlanLine(
            authorUid: line.id,
            firstName: line.firstName,
            activity: line.activity,
            place: line.place.isEmpty ? null : line.place,
            kind: SmallPlanKind.fromName(line.kind),
            at: at,
            joined: line.joined,
          ),
    ];
    final own = card.mine;
    final at = own == null
        ? null
        : SmallPlanSuggestion.parseWhen(own.date, own.time);
    return SharedPlans(
      lines: lines,
      mine: own != null && at!.isAfter(now)
          ? SharedPlanMine(at: at, joined: own.joined)
          : null,
    );
  }

  @override
  List<Object?> get props => [lines, mine];
}
