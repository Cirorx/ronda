part of 'acta_cubit.dart';

/// Whether the acta can show.
enum ActaStatus {
  /// Reading.
  loading,

  /// [ActaState.acta] is the ronda's newest week.
  ready,

  /// The acta couldn't be read.
  failure,
}

/// Where [Algo estuvo mal] stands.
enum ActaReport {
  /// Not tapped.
  none,

  /// On its way.
  sending,

  /// Recorded for the admin.
  sent,

  /// It didn't reach the server.
  failed,
}

final class const ActaState({
  final ActaStatus status = ActaStatus.loading,
  final Acta acta = const Acta(),
  final ActaReport report = ActaReport.none,
}) extends Equatable {
  @override
  List<Object?> get props => [status, acta, report];
}
