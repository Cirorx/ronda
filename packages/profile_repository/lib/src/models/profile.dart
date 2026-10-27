import 'package:equatable/equatable.dart';
import 'package:profile_repository/src/models/age_band.dart';
import 'package:profile_repository/src/models/barrio.dart';
import 'package:profile_repository/src/models/bring.dart';
import 'package:profile_repository/src/models/pretext.dart';
import 'package:profile_repository/src/models/slot.dart';

/// {@template profile}
/// What Ronda keeps of a member ("lo que traés"): first name, age band,
/// barrio, when they can, what they'd like to do and what they bring.
///
/// Needs are not here: they live only on the phone (`needs_repository`).
/// {@endtemplate}
class const Profile({
  /// The first name people know them by.
  required final String firstName,

  /// Their age band.
  required final AgeBand ageBand,

  /// Their barrio.
  required final Barrio barrio,

  /// What they'd like to do.
  required final Set<Pretext> pretexts,

  /// When they can.
  required final Set<Slot> slots,

  /// What they bring or teach.
  required final Set<Bring> brings,
}) extends Equatable {
  /// {@macro profile}
  this;

  @override
  List<Object?> get props => [
    firstName,
    ageBand,
    barrio,
    pretexts,
    slots,
    brings,
  ];
}
