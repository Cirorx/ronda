part of 'ronda_setup_cubit.dart';

/// Whether the rondas could be read.
enum RondaSetupStatus { loading, ready, forbidden, failure }

final class const RondaSetupState({
  final RondaSetupStatus status = RondaSetupStatus.loading,

  /// Every ronda that still meets.
  final List<RondaSetup> rondas = const [],

  /// A save is on its way.
  final bool saving = false,

  /// Why the last save failed, while its sheet is open.
  final HostsFailureReason? saveFailure,
}) extends Equatable {
  RondaSetupState copyWith({
    bool? saving,
    HostsFailureReason? Function()? saveFailure,
  }) => RondaSetupState(
    status: status,
    rondas: rondas,
    saving: saving ?? this.saving,
    saveFailure: saveFailure == null ? this.saveFailure : saveFailure(),
  );

  @override
  List<Object?> get props => [status, rondas, saving, saveFailure];
}
