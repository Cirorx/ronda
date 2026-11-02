import 'package:firebase_core/firebase_core.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:rxdart/rxdart.dart';
import 'package:safety_repository/safety_repository.dart';

/// {@template safety_repository}
/// Contar algo que pasó, as the app sees it:
/// - for a member, who "¿Con quién?" offers, sending a report, adding to it
///   and "Retirar", and their own receipts;
/// - for the admin, the queue (reports, pairs kept apart, who is out of
///   Ronda), the unread count for the Admin tab, and what the admin does
///   with a report.
///
/// Every failure is a [SafetyFailure].
/// {@endtemplate}
class SafetyRepository {
  /// {@macro safety_repository}
  const new({required this._safetyApi});

  final SafetyApi _safetyApi;

  /// The other members of the caller's rondas, by first name.
  ///
  /// Throws a [SafetyFailure].
  Future<List<ReportPerson>> reportPeople() => _guard(() async {
    final people = await _safetyApi.people();
    return [
      for (final person in people)
        ReportPerson(uid: person.uid, firstName: person.firstName),
    ];
  });

  /// Sends a report about [aboutUid] (empty for someone from outside Ronda)
  /// with [text] and [tags]; returns its id.
  ///
  /// Throws a [SafetyFailure]: [SafetyFailureReason.tooMany] after five in a
  /// day.
  Future<String> sendReport({
    required String text,
    required Set<ReportTag> tags,
    required String aboutUid,
  }) => _guard(
    () => _safetyApi.send(
      text: text,
      tags: [
        for (final tag in ReportTag.values)
          if (tags.contains(tag)) tag.name,
      ],
      aboutUid: aboutUid,
    ),
  );

  /// Adds [text] to the caller's own report [reportId].
  ///
  /// Throws a [SafetyFailure]: [SafetyFailureReason.gone] once withdrawn.
  Future<void> addToReport({required String reportId, required String text}) =>
      _guard(() => _safetyApi.add(reportId: reportId, text: text));

  /// "Retirar" on the caller's own report [reportId].
  ///
  /// Throws a [SafetyFailure].
  Future<void> withdrawReport(String reportId) =>
      _guard(() => _safetyApi.withdraw(reportId));

  /// [uid]'s receipts, newest first.
  Stream<List<ReportReceipt>> watchReceipts(String uid) => _guarded(
    _safetyApi
        .watchReceipts(uid)
        .map(
          (receipts) => [
            for (final receipt in receipts)
              ReportReceipt(
                id: receipt.id,
                createdAt: receipt.createdAt,
                withdrawn: receipt.status == 'withdrawn',
              ),
          ],
        ),
  );

  /// The admin's queue, now and on every change. Admin only.
  Stream<SafetyQueue> watchQueue() => _guarded(
    Rx.combineLatest3(
      _safetyApi.watchReports(),
      _safetyApi.watchAvoidPairs(),
      _safetyApi.watchRemoved(),
      (reports, pairs, removed) => SafetyQueue(
        reports: [for (final report in reports) report.toReport()],
        separated: [
          for (final pair in pairs)
            SeparatedPair(
              id: pair.id,
              uidA: pair.uidA,
              uidB: pair.uidB,
              nameA: pair.nameA,
              nameB: pair.nameB,
              togetherLine: pair.togetherLine,
            ),
        ],
        removed: [
          for (final person in removed)
            RemovedPerson(
              uid: person.uid,
              firstName: person.firstName,
              at: person.at,
              notice:
                  RemovalNotice.values.asNameMap()[person.notice] ??
                  RemovalNotice.none,
            ),
        ],
      ),
    ),
  );

  /// How many reports the admin hasn't seen. Admin only.
  Stream<int> watchUnreadCount() => _guarded(_safetyApi.watchUnreadCount());

  /// The admin saw report [reportId].
  ///
  /// Throws a [SafetyFailure].
  Future<void> markRead(String reportId) =>
      _guard(() => _safetyApi.review(reportId: reportId, action: 'read'));

  /// "Archivar" report [reportId].
  ///
  /// Throws a [SafetyFailure].
  Future<void> archive(String reportId) =>
      _guard(() => _safetyApi.review(reportId: reportId, action: 'archive'));

  /// "Reabrir" report [reportId].
  ///
  /// Throws a [SafetyFailure].
  Future<void> reopen(String reportId) =>
      _guard(() => _safetyApi.review(reportId: reportId, action: 'reopen'));

  /// "Separarlos" on report [reportId]: its reporter and the person it is
  /// about are never seated together again.
  ///
  /// Throws a [SafetyFailure].
  Future<void> separate(String reportId) =>
      _guard(() => _safetyApi.separate(reportId));

  /// "Juntarlos de nuevo" on pair [pairId].
  ///
  /// Throws a [SafetyFailure].
  Future<void> joinAgain(String pairId) =>
      _guard(() => _safetyApi.joinAgain(pairId));

  /// "Sacar de Ronda" on report [reportId]: the person it is about leaves
  /// their ronda and gets one neutral notice.
  ///
  /// Throws a [SafetyFailure]: [SafetyFailureReason.gone] when they are
  /// already out.
  Future<void> remove(String reportId) =>
      _guard(() => _safetyApi.remove(reportId));

  /// "Dejar entrar de nuevo" for [uid].
  ///
  /// Throws a [SafetyFailure].
  Future<void> letBackIn(String uid) => _guard(() => _safetyApi.letBackIn(uid));

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

  static SafetyFailure _failure(Object error) => SafetyFailure(switch (error) {
    FirebaseException(code: 'permission-denied' || 'unauthenticated') =>
      SafetyFailureReason.forbidden,
    FirebaseException(code: 'resource-exhausted') =>
      SafetyFailureReason.tooMany,
    FirebaseException(
      code: 'failed-precondition' || 'not-found' || 'already-exists',
    ) =>
      SafetyFailureReason.gone,
    _ => SafetyFailureReason.other,
  });
}

extension on ReportDocument {
  Report toReport() => Report(
    id: id,
    reporterUid: reporterUid,
    reporterName: reporterName,
    aboutUid: aboutUid,
    aboutName: aboutName,
    createdAt: createdAt,
    rondaLine: rondaLine,
    tags: [for (final tag in tags) ?ReportTag.values.asNameMap()[tag]],
    text: text,
    additions: [
      for (final addition in additions)
        ReportAddition(text: addition.text, at: addition.at),
    ],
    archived: status == 'archived',
    withdrawn: withdrawn,
    unread: unread,
  );
}
