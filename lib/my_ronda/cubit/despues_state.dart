part of 'despues_cubit.dart';

/// A field of the después sheet that a kind needs filled.
enum DespuesField {
  /// "¿Qué hay?".
  what,

  /// "¿Dónde?", for a public place.
  where,

  /// "Dirección", for someone's home.
  address,
}

final class const DespuesState({
  /// It is on its way.
  final bool saving = false,

  /// It was saved: the sheet closes.
  final bool saved = false,

  /// A field it needs is empty.
  final bool missing = false,

  /// Why the server refused it.
  final HostsFailureReason? failure,
}) extends Equatable {
  @override
  List<Object?> get props => [saving, saved, missing, failure];
}
