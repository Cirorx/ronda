import 'package:cloud_firestore/cloud_firestore.dart';

/// {@template agent_run_document}
/// One `agent_runs/{id}` document: a run of the organiser agent, as
/// `functions/organiser/trace.py` writes it. Admin only.
/// {@endtemplate}
class const AgentRunDocument({
  /// The document id (`{rondaId}_{week}_rain`).
  required final String id,

  /// The job that ran it (`rain_check`).
  required final String job,

  /// The ronda it was about.
  required final String rondaId,

  /// The meeting's ISO week (`2026-W45`).
  required final String week,

  /// `running`, `done`, `capped`, `stopped` or `failed`.
  required final String status,

  /// When it started, on the run's clock.
  required final DateTime startedAt,

  /// Whether the admin ran it by hand.
  required final bool forced,

  /// The model it started on.
  required final String model,

  /// The model's last words, plain text.
  required final String note,
}) {
  /// {@macro agent_run_document}
  this;

  /// Reads the document [id] from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(String id, Map<String, Object?> json) {
    if (json case {
      'job': final String job,
      'rondaId': final String rondaId,
      'week': final String week,
      'status': final String status,
      'startedAt': final Timestamp startedAt,
    }) {
      return AgentRunDocument(
        id: id,
        job: job,
        rondaId: rondaId,
        week: week,
        status: status,
        startedAt: startedAt.toDate(),
        forced: json['forced'] == true,
        model: _text(json['model']),
        note: _text(json['note']),
      );
    }
    throw FormatException('agent_runs/$id has another shape');
  }
}

/// {@template agent_step_document}
/// One `agent_runs/{id}/steps/{n}` document. Which fields a step carries
/// depends on its [kind] (`model`, `tool`, `message`, `host`, `note`,
/// `stop`); the others read as empty.
/// {@endtemplate}
class const AgentStepDocument({
  /// Its place in the run, from 1.
  required final int n,

  /// When it happened, on the run's clock.
  required final DateTime ts,

  /// What kind of step it is.
  required final String kind,

  /// Who decided it: `code`, `model` or `person`; empty in runs older than
  /// the label.
  final String by = '',

  /// The tool called (`get_forecast`).
  final String tool = '',

  /// The tool's arguments besides the reason, as JSON.
  final String argsSummary = '',

  /// Why the model called it.
  final String reason = '',

  /// What came of it, in es-419.
  final String resultSummary = '',

  /// `ok`, `refused`, `invalid` or `held`.
  final String status = '',

  /// How long it took.
  final int latencyMs = 0,

  /// The model that answered.
  final String model = '',

  /// The tools a model turn called.
  final List<String> toolCalls = const [],

  /// What a model turn said, plain text.
  final String content = '',

  /// A message's recipient role (`host` or `member`).
  final String toRole = '',

  /// A message's recipient first name.
  final String toName = '',

  /// A message's title.
  final String title = '',

  /// A message's text, exactly as it went (or would have).
  final String text = '',

  /// `allowed` or `blocked`.
  final String gate = '',

  /// The gate that held a message (`quiet_hours`).
  final String gateName = '',

  /// Why, in es-419 (`fuera de horario`).
  final String gateReason = '',

  /// When a message held at night could go out.
  final DateTime? releaseAt,

  /// `sent`, `held`, `unreachable` or `skipped`.
  final String outcome = '',

  /// Why a run stopped early.
  final String why = '',

  /// A note from the run itself.
  final String note = '',
}) {
  /// {@macro agent_step_document}
  this;

  /// Reads a step from its [json] data.
  ///
  /// Throws a [FormatException] when `n`, `ts` or `kind` is missing.
  factory fromJson(Map<String, Object?> json) {
    if (json case {
      'n': final int n,
      'ts': final Timestamp ts,
      'kind': final String kind,
    }) {
      return AgentStepDocument(
        n: n,
        ts: ts.toDate(),
        kind: kind,
        by: _text(json['by']),
        tool: _text(json['tool']),
        argsSummary: _text(json['argsSummary']),
        reason: _text(json['reason']),
        resultSummary: _text(json['resultSummary']),
        status: _text(json['status']),
        latencyMs: switch (json['latencyMs']) {
          final num ms => ms.round(),
          _ => 0,
        },
        model: _text(json['model']),
        toolCalls: switch (json['toolCalls']) {
          final List<Object?> calls => [...calls.whereType<String>()],
          _ => const [],
        },
        content: _text(json['content']),
        toRole: _text(json['toRole']),
        toName: _text(json['toName']),
        title: _text(json['title']),
        text: _text(json['text']),
        gate: _text(json['gate']),
        gateName: _text(json['gateName']),
        gateReason: _text(json['gateReason']),
        releaseAt: switch (json['releaseAt']) {
          final Timestamp at => at.toDate(),
          _ => null,
        },
        outcome: _text(json['outcome']),
        why: _text(json['why']),
        note: _text(json['note']),
      );
    }
    throw const FormatException('an agent step has another shape');
  }
}

/// {@template acta_entry_document}
/// One `acta/{rondaId}/entries/{id}` line: what the organiser did, in
/// es-419, for the ronda's members.
/// {@endtemplate}
class const ActaEntryDocument({
  /// The document id.
  required final String id,

  /// The meeting's ISO week.
  required final String week,

  /// When it happened.
  required final DateTime ts,

  /// The tool or step it reports (`get_forecast`, `host_choice`).
  required final String tool,

  /// The line members read.
  required final String summary,

  /// `agent` or `host`.
  required final String decidedBy,
}) {
  /// {@macro acta_entry_document}
  this;

  /// Reads the line [id] from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(String id, Map<String, Object?> json) {
    if (json case {
      'week': final String week,
      'ts': final Timestamp ts,
      'tool': final String tool,
      'summary': final String summary,
      'decidedBy': final String decidedBy,
    }) {
      return ActaEntryDocument(
        id: id,
        week: week,
        ts: ts.toDate(),
        tool: tool,
        summary: summary,
        decidedBy: decidedBy,
      );
    }
    throw FormatException('acta entry $id has another shape');
  }
}

/// {@template move_document}
/// `rondas/{id}/moves/{week}`: the organiser's rain proposal to the host,
/// as `functions/organiser/moves.py` writes it. Read by its host only.
/// {@endtemplate}
class const MoveDocument({
  /// The meeting's ISO week.
  required final String week,

  /// The push the host got: "El jueves puede llover".
  required final String title,

  /// Its text: "Jueves 16:00 · lluvia 80%. …".
  required final String body,

  /// The choices, each with the message members get.
  required final List<MoveOptionDocument> options,

  /// How many members the pick reaches.
  required final int recipients,

  /// When the plan stays as it is: 21:00 the evening before.
  required final DateTime deadline,

  /// `pending`, `decided` or `expired`.
  required final String status,

  /// Whether the host is standing in, with no anfitrión set yet.
  required final bool hostFallback,

  /// The option picked, once decided.
  final String? choice,

  /// How many members it reached, once decided.
  final int? sent,
}) {
  /// {@macro move_document}
  this;

  /// Reads the proposal from its [json] data.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Map<String, Object?> json) {
    if (json case {
      'week': final String week,
      'title': final String title,
      'body': final String body,
      'options': final List<Object?> options,
      'recipients': final int recipients,
      'deadline': final Timestamp deadline,
      'status': final String status,
    }) {
      return MoveDocument(
        week: week,
        title: title,
        body: body,
        options: [
          for (final option in options) MoveOptionDocument.fromJson(option),
        ],
        recipients: recipients,
        deadline: deadline.toDate(),
        status: status,
        hostFallback: json['hostFallback'] == true,
        choice: switch (json['choice']) {
          final String choice => choice,
          _ => null,
        },
        sent: switch (json['sent']) {
          final int sent => sent,
          _ => null,
        },
      );
    }
    throw const FormatException('a move has another shape');
  }
}

/// {@template move_option_document}
/// One choice in a rain proposal: `covered`, `postpone` or `asIs`.
/// {@endtemplate}
class const MoveOptionDocument({
  /// `covered`, `postpone` or `asIs`.
  required final String id,

  /// The button: "Al Salón Comunal de El Pinar".
  required final String label,

  /// The one message members get if it is picked.
  required final String message,
}) {
  /// {@macro move_option_document}
  this;

  /// Reads one option.
  ///
  /// Throws a [FormatException] when a field is missing or has another type.
  factory fromJson(Object? json) {
    if (json case {
      'id': final String id,
      'label': final String label,
      'message': final String message,
    }) {
      return MoveOptionDocument(id: id, label: label, message: message);
    }
    throw const FormatException('a move option has another shape');
  }
}

String _text(Object? value) => value is String ? value : '';
