import 'package:cuaderno_repository/src/models/cuaderno_entry.dart';
import 'package:equatable/equatable.dart';

/// {@template cuaderno}
/// The person's whole cuaderno, as the phone holds it: their lines, newest
/// first, and the one they chose to bring to the meeting, if any.
/// {@endtemplate}
final class const Cuaderno({
  /// The lines, newest day first.
  final List<CuadernoEntry> entries = const [],

  /// The day of the line chosen to bring to the meeting; `null` when none
  /// is.
  final DateTime? bringDay,
}) extends Equatable {
  /// {@macro cuaderno}
  this;

  /// A cuaderno with nothing in it.
  static const empty = Cuaderno();

  /// The line written on [day], if there is one.
  CuadernoEntry? on(DateTime day) {
    final key = CuadernoEntry.dayKey(day);
    for (final entry in entries) {
      if (entry.key == key) return entry;
    }
    return null;
  }

  /// The line chosen to bring to the meeting; `null` when none is, or when
  /// it was deleted.
  CuadernoEntry? get brought => switch (bringDay) {
    final day? => on(day),
    null => null,
  };

  /// The lines written from [from] to [to], both days included, oldest
  /// first.
  List<CuadernoEntry> between(DateTime from, DateTime to) {
    final first = CuadernoEntry.dayKey(from);
    final last = CuadernoEntry.dayKey(to);
    return [
      for (final entry in entries.reversed)
        if (entry.key.compareTo(first) >= 0 && entry.key.compareTo(last) <= 0)
          entry,
    ];
  }

  @override
  List<Object?> get props => [entries, bringDay];
}
