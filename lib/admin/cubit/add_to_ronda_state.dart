part of 'add_to_ronda_cubit.dart';

/// Whether the candidates could be read.
enum AddToRondaStatus { loading, ready, failure }

/// What came of the last "Sumar".
enum AddOutcome {
  /// Nothing yet, or one is running.
  none,

  /// They are in.
  added,

  /// No seat was left.
  full,

  /// They were in already.
  alreadyIn,

  /// Anything else.
  failed,
}

final class const AddToRondaState({
  final AddToRondaStatus status = AddToRondaStatus.loading,

  /// The ronda and who could join it, once read.
  final RondaCandidates? candidates,

  /// The candidate being added, while the call runs.
  final Candidate? adding,

  /// What came of the last add.
  final AddOutcome outcome = AddOutcome.none,

  /// The first name of whoever the last add was for.
  final String lastName = '',

  /// What doesn't match the ronda, after an add.
  final List<CandidateWarning> warnings = const [],
}) extends Equatable {
  /// A copy with these fields changed; [adding] clears unless given.
  AddToRondaState copyWith({
    AddToRondaStatus? status,
    RondaCandidates? candidates,
    Candidate? adding,
    AddOutcome? outcome,
  }) => AddToRondaState(
    status: status ?? this.status,
    candidates: candidates ?? this.candidates,
    adding: adding,
    outcome: outcome ?? this.outcome,
    lastName: lastName,
    warnings: warnings,
  );

  @override
  List<Object?> get props => [
    status,
    candidates,
    adding,
    outcome,
    lastName,
    warnings,
  ];
}
