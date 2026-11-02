import 'package:equatable/equatable.dart';

/// The spec's tags of a report, in its order (docs/PRODUCT.md § Safety).
enum ReportTag {
  /// "Me pidió plata".
  askedForMoney,

  /// "Me molestó".
  bothered,

  /// "Insistió con algo romántico".
  romantic,

  /// "Había un menor".
  minor,

  /// "Quiso ir a un lugar privado".
  privatePlace,

  /// "Otra cosa".
  other,
}

/// {@template report_person}
/// Someone "¿Con quién?" offers: another member of the reporter's rondas.
/// {@endtemplate}
class const ReportPerson({
  /// Their uid.
  required final String uid,

  /// Their first name.
  required final String firstName,
}) extends Equatable {
  /// {@macro report_person}
  this;

  @override
  List<Object?> get props => [uid, firstName];
}

/// {@template report_receipt}
/// What the reporter keeps of a report: that it arrived, and whether they
/// withdrew it. Never what the admin did with it.
/// {@endtemplate}
class const ReportReceipt({
  /// The report's id.
  required final String id,

  /// When it was sent.
  required final DateTime createdAt,

  /// Whether the reporter withdrew it ("Retirar").
  final bool withdrawn = false,
}) extends Equatable {
  /// {@macro report_receipt}
  this;

  @override
  List<Object?> get props => [id, createdAt, withdrawn];
}

/// {@template report_addition}
/// What the reporter added to a report later.
/// {@endtemplate}
class const ReportAddition({
  /// The words.
  required final String text,

  /// When.
  required final DateTime at,
}) extends Equatable {
  /// {@macro report_addition}
  this;

  @override
  List<Object?> get props => [text, at];
}

/// {@template report}
/// One report, as the admin reads it.
/// {@endtemplate}
class const Report({
  /// Its id.
  required final String id,

  /// Who sent it.
  required final String reporterUid,

  /// Their first name.
  required final String reporterName,

  /// Who it is about; empty for someone from outside Ronda.
  required final String aboutUid,

  /// Their first name; empty for someone from outside Ronda.
  required final String aboutName,

  /// When it was sent.
  required final DateTime createdAt,

  /// The ronda's line, in the server's es-419; empty for none.
  final String rondaLine = '',

  /// The tags the reporter picked, in the spec's order.
  final List<ReportTag> tags = const [],

  /// The words.
  final String text = '',

  /// What the reporter added later, oldest first.
  final List<ReportAddition> additions = const [],

  /// Whether the admin archived it ("Archivar").
  final bool archived = false,

  /// Whether the reporter withdrew it: it stays, marked «retirado».
  final bool withdrawn = false,

  /// Whether the admin hasn't seen it, or what changed in it, yet.
  final bool unread = false,
}) extends Equatable {
  /// {@macro report}
  this;

  /// Whether it is about someone from outside Ronda ("Alguien de afuera").
  bool get aboutOutsider => aboutUid.isEmpty;

  @override
  List<Object?> get props => [
    id,
    reporterUid,
    reporterName,
    aboutUid,
    aboutName,
    createdAt,
    rondaLine,
    tags,
    text,
    additions,
    archived,
    withdrawn,
    unread,
  ];
}
