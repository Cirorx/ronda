import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:ronda_api/src/safety/safety_documents.dart';

/// {@template safety_api}
/// Contar algo que pasó and the admin's queue (`functions/reports.py`,
/// `safety.py`, `removals.py`):
/// - for a member, who "¿Con quién?" offers, sending a report, adding to it
///   and "Retirar", over the callables, and their own receipts in
///   Firestore;
/// - for the admin, the reports, who is kept apart and who is out of Ronda
///   in Firestore, the unread count, and the callables that act on them.
///
/// The rules decide who reads what (`firebase/tests/reports.test.js`,
/// `firebase/tests/admin.test.js`). [functions] must be built with
/// `FirebaseFunctions.instanceFor(region: RondaApi.region)`.
/// {@endtemplate}
class const SafetyApi({
  /// The Firestore instance every read goes through.
  required final FirebaseFirestore firestore,

  /// The callables' client, in Ronda's region.
  required final FirebaseFunctions functions,
}) {
  /// {@macro safety_api}
  this;

  /// The callable for "¿Con quién?".
  static const peopleCallable = 'report_people';

  /// The callable that sends a report.
  static const sendCallable = 'send_report';

  /// The callable that adds to one.
  static const addCallable = 'add_to_report';

  /// The callable for "Retirar".
  static const withdrawCallable = 'withdraw_report';

  /// The admin's callable that reads, archives or reopens a report.
  static const reviewCallable = 'review_report';

  /// The admin's "Separarlos".
  static const separateCallable = 'separate_pair';

  /// The admin's [Juntarlos de nuevo].
  static const joinAgainCallable = 'join_pair_again';

  /// The admin's [Sacar de Ronda].
  static const removeCallable = 'remove_from_ronda';

  /// The admin's [Dejar entrar de nuevo].
  static const letBackInCallable = 'let_back_in';

  /// The other members of the caller's rondas, by first name.
  Future<List<ReportPersonDocument>> people() async {
    final result = await functions
        .httpsCallable(peopleCallable)
        .call<Object?>(<String, Object?>{});
    return switch (result.data) {
      {'people': final List<Object?> people} => [
        for (final person in people) ReportPersonDocument.fromJson(person),
      ],
      _ => throw const FormatException('report_people has another shape'),
    };
  }

  /// Sends a report: [text], [tags] (their ids) and [aboutUid] (empty for
  /// someone from outside Ronda). Returns its id.
  Future<String> send({
    required String text,
    required List<String> tags,
    required String aboutUid,
  }) async {
    final result = await functions.httpsCallable(sendCallable).call<Object?>({
      'text': text,
      'tags': tags,
      'aboutUid': aboutUid,
    });
    return switch (result.data) {
      {'reportId': final String id} => id,
      _ => throw const FormatException('send_report has another shape'),
    };
  }

  /// Adds [text] to the caller's own report [reportId].
  Future<void> add({required String reportId, required String text}) =>
      _call(addCallable, {'reportId': reportId, 'text': text});

  /// "Retirar" on the caller's own report [reportId].
  Future<void> withdraw(String reportId) =>
      _call(withdrawCallable, {'reportId': reportId});

  /// [uid]'s receipts, newest first, now and on every change.
  Stream<List<ReportReceiptDocument>> watchReceipts(String uid) => firestore
      .collection('users/$uid/reports')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            ReportReceiptDocument.fromJson(doc.id, doc.data()),
        ],
      );

  /// Every report, newest first, now and on every change. Admin only.
  Stream<List<ReportDocument>> watchReports() => firestore
      .collection('reports')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            ReportDocument.fromJson(doc.id, doc.data()),
        ],
      );

  /// How many reports the admin hasn't seen, now and on every change.
  /// Admin only.
  Stream<int> watchUnreadCount() => firestore
      .collection('reports')
      .where('unread', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.size);

  /// Every pair kept apart, now and on every change. Admin only.
  Stream<List<AvoidPairDocument>> watchAvoidPairs() => firestore
      .collection('avoid')
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            AvoidPairDocument.fromJson(doc.id, doc.data()),
        ],
      );

  /// Everyone out of Ronda, now and on every change. Admin only.
  Stream<List<RemovedDocument>> watchRemoved() => firestore
      .collection('removed')
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            RemovedDocument.fromJson(doc.id, doc.data()),
        ],
      );

  /// The admin on report [reportId]: [action] `read`, `archive` or
  /// `reopen`.
  Future<void> review({required String reportId, required String action}) =>
      _call(reviewCallable, {'reportId': reportId, 'action': action});

  /// "Separarlos" on report [reportId].
  Future<void> separate(String reportId) =>
      _call(separateCallable, {'reportId': reportId});

  /// [Juntarlos de nuevo] on pair [pairId].
  Future<void> joinAgain(String pairId) =>
      _call(joinAgainCallable, {'pairId': pairId});

  /// [Sacar de Ronda] on report [reportId].
  Future<void> remove(String reportId) =>
      _call(removeCallable, {'reportId': reportId});

  /// [Dejar entrar de nuevo] for [uid].
  Future<void> letBackIn(String uid) => _call(letBackInCallable, {'uid': uid});

  Future<void> _call(String name, Map<String, Object> data) =>
      functions.httpsCallable(name).call<Object?>(data);
}
