import 'package:firebase_core/firebase_core.dart';
import 'package:organiser_repository/organiser_repository.dart';
import 'package:ronda_api/ronda_api.dart';

/// {@template organiser_repository}
/// The organiser agent, as the app sees it:
/// - for the admin, its runs and their steps as they land (the trace), the
///   members' [Algo estuvo mal] taps, and the rain check run by hand;
/// - for a ronda's members, the acta, "Lo que hizo el programa";
/// - for the host, the rain proposal and their pick.
///
/// Every failure is an [OrganiserFailure].
/// {@endtemplate}
class OrganiserRepository {
  /// {@macro organiser_repository}
  const new({required this._organiserApi});

  final OrganiserApi _organiserApi;

  /// The newest runs, newest first, now and on every change.
  Stream<List<AgentRun>> watchRuns() => _guarded(
    _organiserApi.watchRuns().map(
      (runs) => [for (final run in runs) run.toRun()],
    ),
  );

  /// Run [runId]'s steps in order, now and as each one lands.
  Stream<List<AgentStep>> watchSteps(String runId) => _guarded(
    _organiserApi
        .watchSteps(runId)
        .map((steps) => [for (final step in steps) step.toStep()]),
  );

  /// How many members of ronda [rondaId] tapped [Algo estuvo mal].
  Stream<int> watchFlagCount(String rondaId) =>
      _guarded(_organiserApi.watchFlagCount(rondaId));

  /// Ronda [rondaId]'s acta for its newest week with any lines.
  Stream<Acta> watchActa(String rondaId) => _guarded(
    _organiserApi.watchActa(rondaId).map((entries) {
      if (entries.isEmpty) return const Acta();
      final week = entries.first.week;
      return Acta(
        week: week,
        lines: [
          for (final entry in entries.reversed)
            if (entry.week == week)
              ActaLine(
                id: entry.id,
                at: entry.ts,
                summary: entry.summary,
                byHost: entry.decidedBy == 'host',
              ),
        ],
      );
    }),
  );

  /// Records that member [uid] found something wrong in ronda [rondaId]'s
  /// acta for [week], for the admin.
  ///
  /// Throws an [OrganiserFailure].
  Future<void> reportActa({
    required String rondaId,
    required String uid,
    required String week,
  }) => _guard(
    () => _organiserApi.flagActa(rondaId: rondaId, uid: uid, week: week),
  );

  /// Ronda [rondaId]'s rain proposal for [week]; `null` while there is none.
  Stream<RainMove?> watchMove(String rondaId, String week) => _guarded(
    _organiserApi.watchMove(rondaId, week).map((move) => move?.toMove()),
  );

  /// Sends the host's [choice] for ronda [rondaId]'s [week] to the members,
  /// once.
  ///
  /// Throws an [OrganiserFailure]: [OrganiserFailureReason.late] once the
  /// deadline passed.
  Future<MoveAnswer> answerMove({
    required String rondaId,
    required String week,
    required MoveChoice choice,
  }) => _guard(() async {
    final result = await _organiserApi.answerMove(
      rondaId: rondaId,
      week: week,
      choice: choice.name,
    );
    return MoveAnswer(sent: result.sent, already: result.status == 'already');
  });

  /// Runs the rain check now for every ronda's next meeting, or as if it
  /// were [at] (the gates still apply at that hour). Admin only.
  ///
  /// Throws an [OrganiserFailure].
  Future<RainCheckResult> runRainCheck({DateTime? at}) => _guard(() async {
    final counts = await _organiserApi.runRainCheck(at: at);
    return RainCheckResult(
      checked: counts['checked'] ?? 0,
      failed: counts['failed'] ?? 0,
    );
  });

  static Stream<T> _guarded<T>(Stream<T> stream) => stream.handleError(
    (Object error) => throw _failure(error),
    test: (error) => error is Exception,
  );

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on Exception catch (error) {
      throw _failure(error);
    }
  }

  static OrganiserFailure _failure(Object error) =>
      OrganiserFailure(switch (error) {
        FirebaseException(code: 'permission-denied' || 'unauthenticated') =>
          OrganiserFailureReason.forbidden,
        FirebaseException(code: 'failed-precondition') =>
          OrganiserFailureReason.late,
        _ => OrganiserFailureReason.other,
      });
}

extension on AgentRunDocument {
  AgentRun toRun() => AgentRun(
    id: id,
    rondaId: rondaId,
    week: week,
    status: AgentRunStatus.values.firstWhere(
      (value) => value.name == status,
      orElse: () => AgentRunStatus.other,
    ),
    startedAt: startedAt,
    forced: forced,
    model: model,
    note: note,
  );
}

extension on AgentStepDocument {
  AgentStep toStep() => AgentStep(
    n: n,
    at: ts,
    kind: AgentStepKind.values.firstWhere(
      (value) => value.name == kind,
      orElse: () => AgentStepKind.other,
    ),
    tool: kind == 'model' ? toolCalls.join(', ') : tool,
    arguments: argsSummary,
    reason: reason,
    summary: switch (kind) {
      'model' => content,
      'stop' => why,
      'note' => note,
      _ => resultSummary,
    },
    refused: status == 'refused' || status == 'invalid',
    latency: Duration(milliseconds: latencyMs),
    model: model,
    toName: toName,
    toHost: toRole == 'host',
    text: text,
    outcome: MessageOutcome.values.firstWhere(
      (value) => value.name == outcome,
      orElse: () => MessageOutcome.none,
    ),
    heldBecause: gateReason,
    releaseAt: releaseAt,
  );
}

extension on MoveDocument {
  RainMove toMove() => RainMove(
    title: title,
    forecast: body,
    options: [
      for (final option in options)
        if (_choice(option.id) case final choice?)
          RainOption(
            choice: choice,
            label: option.label,
            message: option.message,
          ),
    ],
    recipients: recipients,
    deadline: deadline,
    status: RainMoveStatus.values.firstWhere(
      (value) => value.name == status,
      orElse: () => RainMoveStatus.expired,
    ),
    standIn: hostFallback,
    choice: _choice(choice),
    sent: sent,
  );

  static MoveChoice? _choice(String? id) =>
      MoveChoice.values.where((value) => value.name == id).firstOrNull;
}
