import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:ronda_api/src/rondas/bench_documents.dart';
import 'package:ronda_api/src/rondas/cerca_document.dart';
import 'package:ronda_api/src/rondas/hosts_documents.dart';
import 'package:ronda_api/src/rondas/pilot_numbers_document.dart';
import 'package:ronda_api/src/rondas/ronda_documents.dart';
import 'package:ronda_api/src/rondas/seguimos_documents.dart';

/// {@template rondas_api}
/// A member's side of their ronda: which ronda they are in, the ronda, their
/// own member document, "who's coming" to the upcoming meeting and their own
/// answer, plus the `answer_rsvp` callable. Also the admin's `run_job`, and
/// Cerca tuyo's public counts, which anyone may read signed in or not.
///
/// The rules let a member read only their own ronda, its view of the week
/// and their own answer; the raw answers stay on the server.
/// [functions] must be built with
/// `FirebaseFunctions.instanceFor(region: RondaApi.region)`.
/// {@endtemplate}
class const RondasApi({
  /// The Firestore instance every read goes through.
  required final FirebaseFirestore firestore,

  /// The callables' client, in Ronda's region.
  required final FirebaseFunctions functions,
}) {
  /// {@macro rondas_api}
  this;

  /// The callable that records "voy" or "esta no".
  static const answerRsvpCallable = 'answer_rsvp';

  /// The admin's callable that runs one scheduled job now.
  static const runJobCallable = 'run_job';

  /// The admin's callable that counts the pilot's numbers.
  static const pilotNumbersCallable = 'pilot_numbers';

  /// The callable that records a ¿seguimos? answer or, below the floor, the
  /// member's choice.
  static const answerSeguimosCallable = 'answer_seguimos';

  /// The callable that records one "Vino" or "No vino".
  static const recordAttendanceCallable = 'record_attendance';

  /// The admin's callable that lists every ronda's place, hour and hosts.
  static const rondaSetupsCallable = 'ronda_setups';

  /// The admin's callable that sets a ronda's place, hour and hosts.
  static const setRondaSetupCallable = 'set_ronda_setup';

  /// The callable that answers an offer of a freed seat.
  static const answerBenchOfferCallable = 'answer_bench_offer';

  /// The callable that records the pick after a waiting list didn't fill.
  static const answerWaitlistCallable = 'answer_waitlist';

  /// The offers of freed seats made to [uid] (`users/{uid}/offers`), now and
  /// on every change. Only [uid] reads them.
  Stream<List<BenchOfferDocument>> watchOffers(String uid) => firestore
      .collection('users')
      .doc(uid)
      .collection('offers')
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            BenchOfferDocument.fromJson(doc.id, doc.data()),
        ],
      );

  /// Answers offer [offerId]: [take] is "Lo tomo", otherwise "Esta vez no".
  ///
  /// Throws a [FirebaseFunctionsException] when the call fails:
  /// `failed-precondition` once the offer is over.
  Future<void> answerBenchOffer({
    required String offerId,
    required bool take,
  }) async {
    await functions.httpsCallable(answerBenchOfferCallable).call<Object?>({
      'offerId': offerId,
      'take': take,
    });
  }

  /// [uid]'s waiting card (`waiting/{uid}`); `null` while they wait on no
  /// list.
  Stream<WaitingDocument?> watchWaiting(String uid) =>
      _watch('waiting/$uid', WaitingDocument.fromJson);

  /// Records the caller's [choice] (`join` or `wait`) after their waiting
  /// list didn't fill.
  ///
  /// Throws a [FirebaseFunctionsException] when the call fails.
  Future<void> answerWaitlist(String choice) async {
    await functions.httpsCallable(answerWaitlistCallable).call<Object?>({
      'choice': choice,
    });
  }

  /// The ids of the rondas [uid] is in (`users/{uid}/rondas`), now and on
  /// every change.
  Stream<List<String>> watchRondaIds(String uid) => firestore
      .collection('users')
      .doc(uid)
      .collection('rondas')
      .snapshots()
      .map((snapshot) => [for (final doc in snapshot.docs) doc.id]);

  /// `rondas/{id}` now and on every change; `null` while it doesn't exist.
  Stream<RondaDocument?> watchRonda(String id) =>
      _watch('rondas/$id', (json) => RondaDocument.fromJson(id, json));

  /// `rondas/{rondaId}/members/{uid}`; `null` while it doesn't exist.
  Stream<MemberDocument?> watchMember(String rondaId, String uid) =>
      _watch('rondas/$rondaId/members/$uid', MemberDocument.fromJson);

  /// `rondas/{rondaId}/views/week`; `null` until the server first writes it.
  Stream<WeekViewDocument?> watchWeekView(String rondaId) =>
      _watch('rondas/$rondaId/views/week', WeekViewDocument.fromJson);

  /// `rondas/{rondaId}/answers/{uid}`; `null` until the member answers.
  Stream<AnswerDocument?> watchAnswer(String rondaId, String uid) =>
      _watch('rondas/$rondaId/answers/$uid', AnswerDocument.fromJson);

  /// `rondas/{rondaId}/seguimos/{uid}`: the member's own ¿seguimos?;
  /// `null` until they are asked.
  Stream<SeguimosDocument?> watchSeguimos(String rondaId, String uid) =>
      _watch('rondas/$rondaId/seguimos/$uid', SeguimosDocument.fromJson);

  /// Every ronda's ¿seguimos? counts (`seguimos_counts`), now and on every
  /// change, by ronda id. Admin only.
  Stream<List<SeguimosCountsDocument>> watchSeguimosCounts() => firestore
      .collection('seguimos_counts')
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            SeguimosCountsDocument.fromJson(doc.id, doc.data()),
        ],
      );

  /// `cerca/{barrio}` once, or `null` when the barrio has no counts yet.
  /// Anyone may `get` it, signed in or not.
  Future<CercaDocument?> readCerca(String barrio) async =>
      switch ((await firestore.doc('cerca/$barrio').get()).data()) {
        final data? => CercaDocument.fromJson(barrio, data),
        null => null,
      };

  /// Ronda [rondaId]'s attendance roll for [week]
  /// (`rondas/{rondaId}/rolls/{week}`); `null` while there is none. Its
  /// hosts and the admin only.
  Stream<RollDocument?> watchRoll(String rondaId, String week) =>
      _watch('rondas/$rondaId/rolls/$week', RollDocument.fromJson);

  /// Records whether [uid] [came] to ronda [rondaId]'s meeting of [week]
  /// (`record_attendance`). The ronda's hosts or the admin.
  ///
  /// Throws a [FirebaseFunctionsException] when the call fails.
  Future<void> recordAttendance({
    required String rondaId,
    required String week,
    required String uid,
    required bool came,
  }) async {
    await functions.httpsCallable(recordAttendanceCallable).call<Object?>({
      'rondaId': rondaId,
      'week': week,
      'uid': uid,
      'came': came,
    });
  }

  /// Every ronda that still meets, with its place, hour, hosts and members
  /// (`ronda_setups`). Admin only.
  ///
  /// Throws a [FirebaseFunctionsException] when the call fails, and a
  /// [FormatException] for another shape.
  Future<List<RondaSetupDocument>> rondaSetups() async {
    final result = await functions
        .httpsCallable(rondaSetupsCallable)
        .call<Map<Object?, Object?>>();
    return switch (result.data) {
      {'rondas': final List<Object?> rows} => [
        for (final row in rows) RondaSetupDocument.fromJson(row),
      ],
      _ => throw const FormatException('ronda_setups returned another shape'),
    };
  }

  /// Sets ronda [rondaId]'s public place ([placeName] and [placeLandmark]),
  /// [hour] and hosts at once (`set_ronda_setup`); a `null` takes each one
  /// away. Admin only.
  ///
  /// Throws a [FirebaseFunctionsException] when the call fails:
  /// `failed-precondition` when the place looks like a home or an address.
  Future<void> setRondaSetup({
    required String rondaId,
    String? placeName,
    String? placeLandmark,
    String? hour,
    String? anfitrionUid,
    String? colaUid,
  }) async {
    await functions.httpsCallable(setRondaSetupCallable).call<Object?>({
      'rondaId': rondaId,
      'place': placeName == null
          ? null
          : {'name': placeName, 'landmark': placeLandmark ?? ''},
      'hour': hour,
      'anfitrion': anfitrionUid ?? '',
      'cola': colaUid ?? '',
    });
  }

  Stream<T?> _watch<T>(String path, T Function(Map<String, Object?>) read) =>
      firestore
          .doc(path)
          .snapshots()
          .map(
            (snapshot) => switch (snapshot.data()) {
              final data? => read(data),
              null => null,
            },
          );

  /// Records the caller's [answer] (`yes` or `no`) for ronda [rondaId]'s
  /// upcoming meeting; returns the week it answered. [week], when given,
  /// must still be the upcoming meeting's. [pauseWeeks] (2, with `no`)
  /// pauses the member through the meeting after next.
  ///
  /// Throws a [FirebaseFunctionsException] when the call fails.
  Future<String> answerRsvp({
    required String rondaId,
    required String answer,
    String? week,
    int? pauseWeeks,
  }) async {
    final result = await functions
        .httpsCallable(answerRsvpCallable)
        .call<Map<Object?, Object?>>({
          'rondaId': rondaId,
          'answer': answer,
          'week': ?week,
          'pauseWeeks': ?pauseWeeks,
        });
    return switch (result.data) {
      {'week': final String week} => week,
      _ => throw const FormatException('answer_rsvp returned no week'),
    };
  }

  /// Records the caller's ¿seguimos? [answer] (`yes` or `no`) for ronda
  /// [rondaId] while the question is open, or, below the floor, their
  /// [choice] (`join` or `wait`). Pass exactly one.
  ///
  /// Throws a [FirebaseFunctionsException] when the call fails.
  Future<void> answerSeguimos({
    required String rondaId,
    String? answer,
    String? choice,
  }) async {
    await functions.httpsCallable(answerSeguimosCallable).call<Object?>({
      'rondaId': rondaId,
      'answer': ?answer,
      'choice': ?choice,
    });
  }

  /// Runs scheduled job [name] now; with [force] it skips the job's own
  /// timing. Returns the job's counts. Admin only.
  ///
  /// Throws a [FirebaseFunctionsException] when the call fails.
  Future<Map<String, int>> runJob(String name, {bool force = false}) async {
    final result = await functions
        .httpsCallable(runJobCallable)
        .call<Map<Object?, Object?>>({'name': name, 'force': force});
    return {
      for (final MapEntry(:key, :value) in result.data.entries)
        if ((key, value) case (final String key, final int value)) key: value,
    };
  }

  /// The pilot's numbers, counted now. Admin only.
  ///
  /// Throws a [FirebaseFunctionsException] when the call fails, and a
  /// [FormatException] for an answer of another shape.
  Future<PilotNumbersDocument> pilotNumbers() async {
    final result = await functions
        .httpsCallable(pilotNumbersCallable)
        .call<Object?>();
    return PilotNumbersDocument.fromJson(result.data);
  }
}
