import 'package:equatable/equatable.dart';

/// A weekday, Monday first.
enum SlotDay {
  /// Monday.
  monday('mon'),

  /// Tuesday.
  tuesday('tue'),

  /// Wednesday.
  wednesday('wed'),

  /// Thursday.
  thursday('thu'),

  /// Friday.
  friday('fri'),

  /// Saturday.
  saturday('sat'),

  /// Sunday.
  sunday('sun');

  new(this.id);

  /// The first part of a slot id (`thu`).
  final String id;
}

/// A time band of the day.
enum SlotBand {
  /// Mañana: 9 to 12.
  morning('morning'),

  /// Tarde: 14 to 18.
  afternoon('afternoon'),

  /// Noche: 19 to 21.
  evening('evening');

  new(this.id);

  /// The second part of a slot id (`afternoon`).
  final String id;
}

/// {@template slot}
/// A weekday plus a time band ("día y horario"): when a ronda meets.
/// {@endtemplate}
class const Slot(
  /// The weekday.
  final SlotDay day,

  /// The time band.
  final SlotBand band,
) extends Equatable {
  /// {@macro slot}
  this;

  /// The stored id, `{day}-{band}` (`thu-afternoon`), the same one the
  /// solver reads.
  String get id => '${day.id}-${band.id}';

  /// The slot stored as [id], or `null` for an unknown id.
  static Slot? fromId(String id) => _byId[id];

  static final Map<String, Slot> _byId = {
    for (final day in SlotDay.values)
      for (final band in SlotBand.values)
        '${day.id}-${band.id}': Slot(day, band),
  };

  @override
  List<Object?> get props => [day, band];
}
