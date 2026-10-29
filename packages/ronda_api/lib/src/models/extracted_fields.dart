import 'package:equatable/equatable.dart';

/// {@template extracted_fields}
/// What the `extract` callable read from a voice note, in its wire shape:
/// the same ids `users/{uid}` stores, `null` or empty for what the person
/// didn't say.
/// {@endtemplate}
class const ExtractedFields({
  /// The first name the person said.
  final String? firstName,

  /// The age band id (`60-69`).
  final String? ageBand,

  /// The barrio id (`solymar-norte`).
  final String? barrio,

  /// Pretext ids (`mate`).
  final List<String> pretexts = const [],

  /// Slot ids (`tue-afternoon`).
  final List<String> slots = const [],

  /// Bring ids (`termo`).
  final List<String> brings = const [],
}) extends Equatable {
  /// {@macro extracted_fields}
  this;

  /// Reads the callable's answer, skipping fields of the wrong type.
  factory fromJson(Map<Object?, Object?> json) => ExtractedFields(
    firstName: _string(json['firstName']),
    ageBand: _string(json['ageBand']),
    barrio: _string(json['barrio']),
    pretexts: _strings(json['pretexts']),
    slots: _strings(json['slots']),
    brings: _strings(json['brings']),
  );

  static String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static List<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];

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
