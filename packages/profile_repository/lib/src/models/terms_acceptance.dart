import 'package:equatable/equatable.dart';

/// {@template terms_acceptance}
/// The conditions a person accepted by tapping a welcome door: which
/// version, and when.
/// {@endtemplate}
class const TermsAcceptance({
  /// The version of the conditions the welcome screen linked.
  required final String version,

  /// When the person tapped the door.
  required final DateTime acceptedAt,
}) extends Equatable {
  /// {@macro terms_acceptance}
  this;

  @override
  List<Object?> get props => [version, acceptedAt];
}
