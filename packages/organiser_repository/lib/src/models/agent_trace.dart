import 'package:equatable/equatable.dart';

/// How a run of the organiser ended, or that it is still going.
enum AgentRunStatus {
  /// Still going: its steps are landing.
  running,

  /// The model answered in words at the end.
  done,

  /// It hit the step cap.
  capped,

  /// It stopped on its own: a call came back wrong twice, or the ronda had
  /// nobody to propose to.
  stopped,

  /// The model or a service failed.
  failed,

  /// A status this app doesn't know yet.
  other,
}

/// {@template agent_run}
/// One run of the organiser agent: which ronda and week, how it is going,
/// and its last words.
/// {@endtemplate}
class const AgentRun({
  /// The run's id.
  required final String id,

  /// The ronda it was about.
  required final String rondaId,

  /// The meeting's ISO week (`2026-W45`).
  required final String week,

  /// How it is going.
  required final AgentRunStatus status,

  /// When it started, on its own clock (the admin may set it).
  required final DateTime startedAt,

  /// Whether the admin ran it by hand.
  required final bool forced,

  /// The model it started on.
  required final String model,

  /// The model's last words, plain text; empty until it is done.
  required final String note,
}) extends Equatable {
  /// {@macro agent_run}
  this;

  @override
  List<Object?> get props => [
    id,
    rondaId,
    week,
    status,
    startedAt,
    forced,
    model,
    note,
  ];
}

/// What one step of a run is.
enum AgentStepKind {
  /// One answer of the model.
  model,

  /// One tool call.
  tool,

  /// One message to one person, sent or held by the gates.
  message,

  /// The host's pick, or the deadline passing without one.
  host,

  /// A note from the run itself.
  note,

  /// Why the run stopped early.
  stop,

  /// A kind this app doesn't know yet.
  other,
}

/// What became of a message.
enum MessageOutcome {
  /// At least one of the person's phones took it: "Salió".
  sent,

  /// A gate stopped it: "Frenado".
  held,

  /// No phone took it.
  unreachable,

  /// The functions emulator sends nothing.
  skipped,

  /// Not a message.
  none,
}

/// Who decided a step, as the trace labels it (`functions/organiser/trace.py`).
enum StepAuthor {
  /// A rule in code: the gates, who is on a bench, what happens on expiry.
  code,

  /// The model's judgement: a turn, or a tool it chose to call.
  model,

  /// A person: the host's pick, or an answer to an offer.
  person,

  /// A step written before the label, or a label this app doesn't know.
  unknown,
}

/// {@template agent_step}
/// One step of a run. Which fields mean something depends on [kind]; the
/// rest are empty. The words are the server's es-419, shown as they are.
/// {@endtemplate}
class const AgentStep({
  /// Its place in the run, from 1.
  required final int n,

  /// When it happened.
  required final DateTime at,

  /// What kind of step it is.
  required final AgentStepKind kind,

  /// Who decided it.
  final StepAuthor by = StepAuthor.unknown,

  /// The tool called, or the tools a model turn called, joined.
  final String tool = '',

  /// The tool's arguments besides the reason, as JSON.
  final String arguments = '',

  /// Why the model called it.
  final String reason = '',

  /// What came of it, or a note, or why the run stopped.
  final String summary = '',

  /// Whether the tool refused the call or the call didn't fit.
  final bool refused = false,

  /// How long it took.
  final Duration latency = Duration.zero,

  /// The model that answered.
  final String model = '',

  /// A message's recipient's first name.
  final String toName = '',

  /// Whether a message went to the host.
  final bool toHost = false,

  /// A message's words, exactly as they went or would have.
  final String text = '',

  /// What became of a message.
  final MessageOutcome outcome = MessageOutcome.none,

  /// Why a gate held a message (`fuera de horario`).
  final String heldBecause = '',

  /// When a message held at night could go out.
  final DateTime? releaseAt,
}) extends Equatable {
  /// {@macro agent_step}
  this;

  @override
  List<Object?> get props => [
    n,
    at,
    kind,
    by,
    tool,
    arguments,
    reason,
    summary,
    refused,
    latency,
    model,
    toName,
    toHost,
    text,
    outcome,
    heldBecause,
    releaseAt,
  ];
}
