import 'package:cloud_firestore/cloud_firestore.dart';

/// {@template report_person_document}
/// One person "¿Con quién?" offers, as the `report_people` callable answers:
/// another member of the caller's rondas.
/// {@endtemplate}
class const ReportPersonDocument({
  /// Their uid.
  required final String uid,

  /// Their first name.
  required final String firstName,
}) {
  /// {@macro report_person_document}
  this;

  /// Reads one entry of the callable's `people`.
  ///
  /// Throws a [FormatException] when it has another shape.
  factory fromJson(Object? json) => switch (json) {
    {'uid': final String uid, 'firstName': final String firstName} =>
      ReportPersonDocument(uid: uid, firstName: firstName),
    _ => throw const FormatException('report_people has another shape'),
  };
}

/// {@template report_receipt_document}
/// One `users/{uid}/reports/{id}` document: the reporter's receipt, as
/// `functions/reports.py` writes it. Read by the reporter only.
/// {@endtemplate}
class const ReportReceiptDocument({
  /// The report's id.
  required final String id,

  /// `open` or `withdrawn`.
  required final String status,

  /// When it was sent.
  required final DateTime createdAt,
}) {
  /// {@macro report_receipt_document}
  this;

  /// Reads the receipt [id] from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(String id, Map<String, Object?> json) => switch (json) {
    {'status': final String status, 'createdAt': final Timestamp createdAt} =>
      ReportReceiptDocument(
        id: id,
        status: status,
        createdAt: createdAt.toDate(),
      ),
    _ => throw FormatException('report receipt $id has another shape'),
  };
}

/// {@template report_addition_document}
/// What the reporter added to a report later.
/// {@endtemplate}
class const ReportAdditionDocument({
  /// The words.
  required final String text,

  /// When.
  required final DateTime at,
}) {
  /// {@macro report_addition_document}
  this;
}

/// {@template report_document}
/// One `reports/{id}` document, as `functions/reports.py` writes it. Read by
/// the admin only.
/// {@endtemplate}
class const ReportDocument({
  /// The document id.
  required final String id,

  /// Who sent it.
  required final String reporterUid,

  /// Their first name.
  required final String reporterName,

  /// Who it is about; empty for someone from outside Ronda.
  required final String aboutUid,

  /// Their first name; empty for someone from outside Ronda.
  required final String aboutName,

  /// The ronda's line ("Sábado a la tarde · mate en la rambla"); empty for
  /// none.
  required final String rondaLine,

  /// The tags' ids (`bothered`).
  required final List<String> tags,

  /// The words.
  required final String text,

  /// What the reporter added later, oldest first.
  required final List<ReportAdditionDocument> additions,

  /// `open` or `archived`.
  required final String status,

  /// Whether the reporter withdrew it.
  required final bool withdrawn,

  /// Whether the admin hasn't seen it, or what changed in it, yet.
  required final bool unread,

  /// When it was sent.
  required final DateTime createdAt,
}) {
  /// {@macro report_document}
  this;

  /// Reads the document [id] from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(String id, Map<String, Object?> json) {
    if (json case {
      'reporterUid': final String reporterUid,
      'aboutUid': final String aboutUid,
      'status': final String status,
      'createdAt': final Timestamp createdAt,
    }) {
      return ReportDocument(
        id: id,
        reporterUid: reporterUid,
        reporterName: _text(json['reporterName']),
        aboutUid: aboutUid,
        aboutName: _text(json['aboutName']),
        rondaLine: _text(json['rondaLine']),
        tags: [
          if (json['tags'] case final List<Object?> tags)
            for (final tag in tags)
              if (tag is String) tag,
        ],
        text: _text(json['text']),
        additions: [
          if (json['additions'] case final List<Object?> additions)
            for (final addition in additions)
              if (addition case {
                'text': final String text,
                'at': final Timestamp at,
              })
                ReportAdditionDocument(text: text, at: at.toDate()),
        ],
        status: status,
        withdrawn: json['withdrawnAt'] != null,
        unread: json['unread'] == true,
        createdAt: createdAt.toDate(),
      );
    }
    throw FormatException('reports/$id has another shape');
  }
}

/// {@template avoid_pair_document}
/// One `avoid/{pairId}` document: two people never seated together again
/// ("Separarlos"), as `functions/safety.py` writes it. Read by the admin
/// only.
/// {@endtemplate}
class const AvoidPairDocument({
  /// The document id (`{uidA}_{uidB}`).
  required final String id,

  /// One of the two.
  required final String uidA,

  /// The other.
  required final String uidB,

  /// [uidA]'s first name; empty in pairs written before #71.
  required final String nameA,

  /// [uidB]'s first name; empty in pairs written before #71.
  required final String nameB,

  /// The line of the ronda both sat in when they were separated; `null`
  /// when they sat in none together.
  required final String? togetherLine,
}) {
  /// {@macro avoid_pair_document}
  this;

  /// Reads the document [id] from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(String id, Map<String, Object?> json) => switch (json) {
    {'uidA': final String uidA, 'uidB': final String uidB} => AvoidPairDocument(
      id: id,
      uidA: uidA,
      uidB: uidB,
      nameA: _text(json['nameA']),
      nameB: _text(json['nameB']),
      togetherLine: switch (json['together']) {
        {'line': final String line} => line,
        _ => null,
      },
    ),
    _ => throw FormatException('avoid/$id has another shape'),
  };
}

/// {@template removed_document}
/// One `removed/{uid}` document: someone the admin took out of Ronda
/// ([Sacar de Ronda]), as `functions/removals.py` writes it. Read by the
/// admin only.
/// {@endtemplate}
class const RemovedDocument({
  /// Their uid, the document id.
  required final String uid,

  /// Their first name.
  required final String firstName,

  /// When.
  required final DateTime at,

  /// Where the notice is: `pending`, `sent`, `held`, `unreachable`,
  /// `skipped` or `none`.
  required final String notice,
}) {
  /// {@macro removed_document}
  this;

  /// Reads the document [uid] from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(String uid, Map<String, Object?> json) => switch (json) {
    {'at': final Timestamp at} => RemovedDocument(
      uid: uid,
      firstName: _text(json['firstName']),
      at: at.toDate(),
      notice: _text(json['notice']),
    ),
    _ => throw FormatException('removed/$uid has another shape'),
  };
}

String _text(Object? value) => value is String ? value : '';
