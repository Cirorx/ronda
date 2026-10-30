import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:ronda_api/src/organiser/organiser_documents.dart';

/// {@template organiser_api}
/// The organiser agent's records and callables (`functions/rain.py`,
/// `functions/organiser/`):
/// - the admin's trace: `agent_runs/{id}` and their steps, and the members'
///   [Algo estuvo mal] taps (`acta/{rondaId}/flags/{uid}`);
/// - a ronda's acta, read by its members, and the tap itself;
/// - a rain proposal, read by its host, and the `answer_move` callable;
/// - the admin's `run_job` for the rain check.
///
/// The rules decide who reads what (`rules/organiser.test.js`).
/// [functions] must be built with
/// `FirebaseFunctions.instanceFor(region: RondaApi.region)`.
/// {@endtemplate}
class const OrganiserApi({
  /// The Firestore instance every read goes through.
  required final FirebaseFirestore firestore,

  /// The callables' client, in Ronda's region.
  required final FirebaseFunctions functions,
}) {
  /// {@macro organiser_api}
  this;

  /// The callable that records the host's pick.
  static const answerMoveCallable = 'answer_move';

  /// The admin's callable that runs one scheduled job now.
  static const runJobCallable = 'run_job';

  /// The rain check's job name.
  static const rainCheckJob = 'rain_check';

  /// How many runs the trace lists.
  static const runsShown = 10;

  /// How many acta lines are read, newest first: a few weeks' worth.
  static const actaLinesRead = 40;

  /// The newest runs, newest first, now and on every change.
  Stream<List<AgentRunDocument>> watchRuns() => firestore
      .collection('agent_runs')
      .orderBy('startedAt', descending: true)
      .limit(runsShown)
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            AgentRunDocument.fromJson(doc.id, doc.data()),
        ],
      );

  /// Run [runId]'s steps in order, now and as each one lands.
  Stream<List<AgentStepDocument>> watchSteps(String runId) => firestore
      .collection('agent_runs/$runId/steps')
      .orderBy('n')
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            AgentStepDocument.fromJson(doc.data()),
        ],
      );

  /// How many members of ronda [rondaId] tapped [Algo estuvo mal], now and
  /// on every change. Admin only.
  Stream<int> watchFlagCount(String rondaId) => firestore
      .collection('acta/$rondaId/flags')
      .snapshots()
      .map((snapshot) => snapshot.size);

  /// Ronda [rondaId]'s newest acta lines, newest first.
  Stream<List<ActaEntryDocument>> watchActa(String rondaId) => firestore
      .collection('acta/$rondaId/entries')
      .orderBy('ts', descending: true)
      .limit(actaLinesRead)
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            ActaEntryDocument.fromJson(doc.id, doc.data()),
        ],
      );

  /// Records that member [uid] tapped [Algo estuvo mal] on ronda
  /// [rondaId]'s acta for [week], at the server's time.
  Future<void> flagActa({
    required String rondaId,
    required String uid,
    required String week,
  }) => firestore.doc('acta/$rondaId/flags/$uid').set({
    'week': week,
    'at': FieldValue.serverTimestamp(),
  });

  /// Ronda [rondaId]'s rain proposal for [week]; `null` while there is none.
  Stream<MoveDocument?> watchMove(String rondaId, String week) => firestore
      .doc('rondas/$rondaId/moves/$week')
      .snapshots()
      .map(
        (snapshot) => switch (snapshot.data()) {
          final data? => MoveDocument.fromJson(data),
          null => null,
        },
      );

  /// Sends the host's [choice] for ronda [rondaId]'s [week]: `decided` the
  /// first time, `already` after; and how many members it reached.
  ///
  /// Throws a [FirebaseFunctionsException] when the call fails.
  Future<({String status, int sent})> answerMove({
    required String rondaId,
    required String week,
    required String choice,
  }) async {
    final result = await functions
        .httpsCallable(answerMoveCallable)
        .call<Map<Object?, Object?>>({
          'rondaId': rondaId,
          'week': week,
          'choice': choice,
        });
    return switch (result.data) {
      {'status': final String status, 'sent': final int sent} => (
        status: status,
        sent: sent,
      ),
      _ => throw const FormatException('answer_move returned another shape'),
    };
  }

  /// Runs the rain check now for every ronda's next meeting, or as if it
  /// were [at]; returns the job's counts. Admin only.
  ///
  /// Throws a [FirebaseFunctionsException] when the call fails.
  Future<Map<String, int>> runRainCheck({DateTime? at}) async {
    final result = await functions
        .httpsCallable(runJobCallable)
        .call<Map<Object?, Object?>>({
          'name': rainCheckJob,
          'force': true,
          // The callable needs an offset: UTC's `Z` carries one.
          if (at != null) 'now': at.toUtc().toIso8601String(),
        });
    return {
      for (final MapEntry(:key, :value) in result.data.entries)
        if ((key, value) case (final String key, final int value)) key: value,
    };
  }
}
