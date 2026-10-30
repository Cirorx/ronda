part of 'seguimos_counts_cubit.dart';

/// Whether the counts could be read.
enum SeguimosCountsStatus { loading, ready, failure }

final class const SeguimosCountsState({
  final SeguimosCountsStatus status = SeguimosCountsStatus.loading,

  /// One entry per ronda that has been asked.
  final List<SeguimosCounts> rondas = const [],
}) extends Equatable {
  @override
  List<Object?> get props => [status, rondas];
}
