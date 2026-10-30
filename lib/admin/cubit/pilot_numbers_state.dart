part of 'pilot_numbers_cubit.dart';

/// Where the pilot's numbers stand.
enum PilotNumbersStatus {
  /// Counting.
  loading,

  /// Counted: [PilotNumbersState.numbers] holds them.
  ready,

  /// The account has no admin claim.
  forbidden,

  /// The count failed for another reason.
  failure,
}

final class const PilotNumbersState({
  final PilotNumbersStatus status = PilotNumbersStatus.loading,

  /// The last numbers counted, if any.
  final PilotNumbers? numbers,
}) extends Equatable {
  @override
  List<Object?> get props => [status, numbers];
}
