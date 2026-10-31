import 'package:equatable/equatable.dart';

/// {@template cuaderno_entry}
/// One line the person wrote about their barrio on one day: "El jacarandá
/// de la esquina floreció." At most one per day.
/// {@endtemplate}
final class const CuadernoEntry({
  /// The day it was written, a date at midnight (local).
  required final DateTime day,

  /// The line: one line of text.
  required final String text,
}) extends Equatable {
  /// {@macro cuaderno_entry}
  this;

  /// How long a line may be.
  static const maxLength = 280;

  /// [day] as `2026-10-30`: how the phone keeps it, and one day's one key.
  static String dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// This entry's day as [dayKey] says it.
  String get key => dayKey(day);

  @override
  List<Object?> get props => [day, text];
}
