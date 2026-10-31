part of 'donde_queda_cubit.dart';

/// Whether the game has been read.
enum DondeQuedaLoad {
  /// Reading.
  loading,

  /// Read; [DondeQuedaState.week] holds it.
  ready,

  /// It couldn't be read; the card shows nothing rather than an error.
  failure,
}

/// What the card shows of ¿Dónde queda?.
final class const DondeQuedaState({
  final DondeQuedaLoad status = DondeQuedaLoad.loading,

  /// This week's game and last week's answer, once read.
  final DondeQuedaWeek? week,

  /// "Esta semana no" is on its way.
  final bool passing = false,

  /// The last "Esta semana no" didn't go through.
  final bool passFailed = false,
}) extends Equatable {
  /// A copy with the given fields changed.
  DondeQuedaState copyWith({bool? passing, bool? passFailed}) =>
      DondeQuedaState(
        status: status,
        week: week,
        passing: passing ?? this.passing,
        passFailed: passFailed ?? this.passFailed,
      );

  @override
  List<Object?> get props => [status, week, passing, passFailed];
}
