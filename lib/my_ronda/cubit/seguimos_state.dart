part of 'seguimos_cubit.dart';

/// Whether the ¿seguimos? card has anything to show.
enum SeguimosCardStatus {
  /// Reading.
  loading,

  /// The member hasn't been asked: no card.
  none,

  /// [SeguimosState.seguimos] is their question and what came of it.
  ready,

  /// It couldn't be read.
  failure,
}

/// An answer or a choice on the ¿seguimos? card.
enum SeguimosPick {
  /// "Sí".
  yes,

  /// "No".
  no,

  /// "Sumarte a otro ya".
  join,

  /// "Esperar dos semanas más".
  wait,
}

final class const SeguimosState({
  final SeguimosCardStatus status = SeguimosCardStatus.loading,
  final Seguimos? seguimos,

  /// The answer or the choice on its way to the server, if one is.
  final SeguimosPick? saving,

  /// The last one didn't reach the server.
  final bool saveFailed = false,

  /// The server said the question had already closed.
  final bool closed = false,

  /// "Cambiar" was tapped: the question shows again.
  final bool changing = false,
}) extends Equatable {
  /// Whether the card asks "¿Seguimos?": open and not answered yet, or
  /// changing the answer.
  bool get asks =>
      (seguimos?.open ?? false) && (seguimos?.myAnswer == null || changing);

  SeguimosState copyWith({
    SeguimosPick? Function()? saving,
    bool? saveFailed,
    bool? closed,
    bool? changing,
  }) => SeguimosState(
    status: status,
    seguimos: seguimos,
    saving: saving == null ? this.saving : saving(),
    saveFailed: saveFailed ?? this.saveFailed,
    closed: closed ?? this.closed,
    changing: changing ?? this.changing,
  );

  @override
  List<Object?> get props => [
    status,
    seguimos,
    saving,
    saveFailed,
    closed,
    changing,
  ];
}
