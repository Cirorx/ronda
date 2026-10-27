import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// {@template terms_record}
/// The `terms` map of `users/{uid}`: which version of the conditions the
/// person accepted, and when they tapped a welcome door.
/// {@endtemplate}
class const TermsRecord({
  /// The version of the conditions shown on the welcome screen.
  required final String version,

  /// When the person accepted them. Stored as a Firestore `Timestamp`.
  required final DateTime acceptedAt,
}) extends Equatable {
  /// {@macro terms_record}
  this;

  /// Reads the wire map, or returns `null` when it isn't one.
  static TermsRecord? fromJson(Object? json) => switch (json) {
    {'version': final String version, 'acceptedAt': final Timestamp at} =>
      TermsRecord(version: version, acceptedAt: at.toDate()),
    _ => null,
  };

  /// The wire map.
  Map<String, Object> toJson() => {
    'version': version,
    'acceptedAt': Timestamp.fromDate(acceptedAt),
  };

  @override
  List<Object?> get props => [version, acceptedAt];
}

/// {@template user_document}
/// `users/{uid}` as it is stored. Every field is optional on the wire: the
/// terms arrive first, the profile when onboarding is saved.
///
/// Never carries needs, mood, audio, address, cédula or birth date
/// (`docs/ARCHITECTURE.md` § Data model).
/// {@endtemplate}
class const UserDocument({
  /// The first name the person gave.
  final String? firstName,

  /// The age band id (`60-69`).
  final String? ageBand,

  /// The barrio id (`solymar-norte`).
  final String? barrio,

  /// Slot ids (`sat-afternoon`).
  final List<String> slots = const [],

  /// Pretext ids (`mate`, `truco`).
  final List<String> pretexts = const [],

  /// What the person brings or teaches, as ids (`termo`).
  final List<String> brings = const [],

  /// The conditions the person accepted.
  final TermsRecord? terms,

  /// When the profile was saved; set by the server.
  final DateTime? createdAt,
}) extends Equatable {
  /// {@macro user_document}
  this;

  /// Reads a `users/{uid}` snapshot's data, skipping fields of the wrong
  /// type.
  factory fromJson(Map<String, Object?> json) => UserDocument(
    firstName: _string(json['firstName']),
    ageBand: _string(json['ageBand']),
    barrio: _string(json['barrio']),
    slots: _strings(json['slots']),
    pretexts: _strings(json['pretexts']),
    brings: _strings(json['brings']),
    terms: TermsRecord.fromJson(json['terms']),
    createdAt: switch (json['createdAt']) {
      final Timestamp at => at.toDate(),
      _ => null,
    },
  );

  static String? _string(Object? value) => value is String ? value : null;

  static List<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];

  @override
  List<Object?> get props => [
    firstName,
    ageBand,
    barrio,
    slots,
    pretexts,
    brings,
    terms,
    createdAt,
  ];
}
