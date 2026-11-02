import 'package:equatable/equatable.dart';
import 'package:profile_repository/src/models/barrio.dart';

/// Which of a member's barrios an [Anchor] is.
enum AnchorKind {
  /// Casa: where they live. Every profile has it.
  home,

  /// Trabajo: where they work. Optional, and never shown to anyone else.
  work,
}

/// {@template anchor}
/// A barrio a member meets from: casa, or trabajo. With [neighbours] it
/// also reaches the barrios next to it, 1.5 times the walk (the solver's
/// `NEIGHBOURS_REACH`); without, the walk a ronda in it already has.
///
/// Ronda is "a few blocks from home", so a member has at most two.
/// {@endtemplate}
class const Anchor({
  /// The barrio.
  required final Barrio barrio,

  /// Whether it reaches its neighbouring barrios too.
  final bool neighbours = false,
}) extends Equatable {
  /// {@macro anchor}
  this;

  /// How much farther an anchor with its neighbours reaches.
  static const neighboursReach = 1.5;

  /// The farthest walk from this anchor to a seat, between barrio centroids:
  /// [Barrio.walkBlocks], times [neighboursReach] with the neighbours.
  num get reachBlocks =>
      neighbours ? barrio.walkBlocks * neighboursReach : barrio.walkBlocks;

  /// This anchor with [neighbours] switched as given.
  Anchor withNeighbours({required bool neighbours}) =>
      Anchor(barrio: barrio, neighbours: neighbours);

  @override
  List<Object?> get props => [barrio, neighbours];
}
