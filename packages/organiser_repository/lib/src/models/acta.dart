import 'package:equatable/equatable.dart';

/// {@template acta_line}
/// One line of "Lo que hizo el programa": what the organiser did, in the
/// server's es-419, and whether the host decided it.
/// {@endtemplate}
class const ActaLine({
  /// The line's id.
  required final String id,

  /// When it happened.
  required final DateTime at,

  /// What happened.
  required final String summary,

  /// Whether the host decided it (their pick), not the program.
  required final bool byHost,
}) extends Equatable {
  /// {@macro acta_line}
  this;

  @override
  List<Object?> get props => [id, at, summary, byHost];
}

/// {@template acta}
/// A ronda's acta for its newest week with any: the lines in the order
/// they happened. [week] is `null` while the program has done nothing.
/// {@endtemplate}
class const Acta({
  /// The meeting's ISO week (`2026-W45`) the lines are about.
  final String? week,

  /// The week's lines, oldest first.
  final List<ActaLine> lines = const [],
}) extends Equatable {
  /// {@macro acta}
  this;

  @override
  List<Object?> get props => [week, lines];
}
