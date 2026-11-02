import 'package:equatable/equatable.dart';
import 'package:safety_repository/src/models/report.dart';

/// {@template separated_pair}
/// Two people never seated together again ("Separarlos").
/// {@endtemplate}
class const SeparatedPair({
  /// The pair's id (`{uidA}_{uidB}`).
  required final String id,

  /// One of the two.
  required final String uidA,

  /// The other.
  required final String uidB,

  /// [uidA]'s first name; empty for pairs set before the queue.
  final String nameA = '',

  /// [uidB]'s first name; empty for pairs set before the queue.
  final String nameB = '',

  /// The line of the ronda both sat in when they were separated, where they
  /// stay until the next grouping; `null` when they sat in none together.
  final String? togetherLine,
}) extends Equatable {
  /// {@macro separated_pair}
  this;

  /// Whether this pair is [a] and [b], in either order.
  bool joins(String a, String b) =>
      (uidA == a && uidB == b) || (uidA == b && uidB == a);

  @override
  List<Object?> get props => [id, uidA, uidB, nameA, nameB, togetherLine];
}

/// Where the notice of "Sacar de Ronda" is.
enum RemovalNotice {
  /// Waiting for 09:00.
  pending,

  /// It reached at least one of their phones.
  sent,

  /// A gate held it.
  held,

  /// No phone took it.
  unreachable,

  /// The functions emulator sends nothing.
  skipped,

  /// They sat in no ronda, so there was nothing to tell.
  none,
}

/// {@template removed_person}
/// Someone the admin took out of Ronda ("Sacar de Ronda").
/// {@endtemplate}
class const RemovedPerson({
  /// Their uid.
  required final String uid,

  /// Their first name.
  required final String firstName,

  /// When.
  required final DateTime at,

  /// Where their notice is.
  final RemovalNotice notice = RemovalNotice.none,
}) extends Equatable {
  /// {@macro removed_person}
  this;

  @override
  List<Object?> get props => [uid, firstName, at, notice];
}

/// {@template safety_queue}
/// Everything the admin's queue shows: the reports, newest first, the pairs
/// kept apart and who is out of Ronda.
/// {@endtemplate}
class const SafetyQueue({
  final List<Report> reports = const [],
  final List<SeparatedPair> separated = const [],
  final List<RemovedPerson> removed = const [],
}) extends Equatable {
  /// {@macro safety_queue}
  this;

  @override
  List<Object?> get props => [reports, separated, removed];
}
