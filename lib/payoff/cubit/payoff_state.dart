part of 'payoff_cubit.dart';

/// Where the payoff screen stands.
enum PayoffStatus {
  /// Reading the held answers and the counts.
  loading,

  /// The counts are in; [PayoffState.demand] may be empty ("Sos de los
  /// primeros").
  ready,

  /// The counts couldn't be read (offline, an error): the screen says so
  /// and still leads to sign-in.
  unavailable,

  /// No answers are held on this phone: the questions come first.
  noAnswers,
}

/// {@template payoff_demand}
/// One line of demand: how many neighbours signed up for [pretext], at
/// [slot] when the counts know it.
/// {@endtemplate}
final class const PayoffDemand({
  /// What they signed up for.
  required final Pretext pretext,

  /// How many signed up.
  required final int count,

  /// When, or `null` for a count at any slot.
  final Slot? slot,
}) extends Equatable {
  /// {@macro payoff_demand}
  this;

  @override
  List<Object?> get props => [pretext, count, slot];
}

final class const PayoffState({
  final PayoffStatus status = PayoffStatus.loading,

  /// The barrio the held answers name, once read.
  final Barrio? barrio,

  /// The demand lines; empty when nobody else signed up yet.
  final List<PayoffDemand> demand = const [],
}) extends Equatable {
  @override
  List<Object?> get props => [status, barrio, demand];
}
