import 'package:equatable/equatable.dart';

/// {@template voice_signup}
/// What was understood from a voice note, for the read-back.
///
/// Values are the stored ids (`60-69`, `solymar-norte`, `tue-afternoon`),
/// which `profile_repository`'s models read with `fromId`; this repository
/// doesn't import another repository. `null` or empty means the person
/// didn't say it, and the read-back asks for it.
/// {@endtemplate}
class const VoiceSignup({
  /// The first name.
  final String? firstName,

  /// The age band id.
  final String? ageBand,

  /// The barrio id.
  final String? barrio,

  /// Pretext ids.
  final List<String> pretexts = const [],

  /// Slot ids.
  final List<String> slots = const [],

  /// Bring ids.
  final List<String> brings = const [],
}) extends Equatable {
  /// {@macro voice_signup}
  this;

  /// Whether nothing at all was understood.
  bool get isEmpty =>
      firstName == null &&
      ageBand == null &&
      barrio == null &&
      pretexts.isEmpty &&
      slots.isEmpty &&
      brings.isEmpty;

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
