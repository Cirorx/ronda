import 'package:equatable/equatable.dart';
import 'package:profile_repository/src/models/age_band.dart';
import 'package:profile_repository/src/models/anchor.dart';
import 'package:profile_repository/src/models/barrio.dart';
import 'package:profile_repository/src/models/bring.dart';
import 'package:profile_repository/src/models/pretext.dart';
import 'package:profile_repository/src/models/slot.dart';

/// {@template profile}
/// What Ronda keeps of a member ("lo que traés"): first name, age band,
/// barrio (casa, and trabajo if they gave one), when they can, what they'd
/// like to do and what they bring. Others only ever see the first name, the
/// age band and what they bring.
///
/// Needs are not here: they live only on the phone (`needs_repository`).
/// {@endtemplate}
class const Profile({
  /// The first name people know them by.
  required final String firstName,

  /// Their age band.
  required final AgeBand ageBand,

  /// Casa: the barrio they live in.
  required final Barrio barrio,

  /// What they'd like to do.
  required final Set<Pretext> pretexts,

  /// When they can.
  required final Set<Slot> slots,

  /// What they bring or teach.
  required final Set<Bring> brings,

  /// Whether casa reaches its neighbouring barrios too.
  final bool barrioNeighbours = false,

  /// Trabajo, when they gave one: a second barrio to meet from.
  final Anchor? work,
}) extends Equatable {
  /// {@macro profile}
  this;

  /// Casa as an [Anchor].
  Anchor get home => Anchor(barrio: barrio, neighbours: barrioNeighbours);

  /// The barrios they meet from: casa, then trabajo when it is another one.
  List<Anchor> get anchors => [
    home,
    if (work case final work? when work.barrio != barrio) work,
  ];

  @override
  List<Object?> get props => [
    firstName,
    ageBand,
    barrio,
    pretexts,
    slots,
    brings,
    barrioNeighbours,
    work,
  ];
}
