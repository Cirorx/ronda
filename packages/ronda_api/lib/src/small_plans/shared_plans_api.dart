import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:ronda_api/src/ronda_api_exceptions.dart';
import 'package:ronda_api/src/small_plans/shared_plan_documents.dart';

/// {@template shared_plans_api}
/// ¿Alguien se suma?, a member's small plan opened to their ronda
/// (`functions/shared_plans.py`): the member's own plan card in Firestore
/// and the callables `share_small_plan`, `withdraw_small_plan`,
/// `join_small_plan` and `leave_small_plan`.
///
/// The plan itself stays on the phone until the member turns the toggle on;
/// only then does [share] send its text. [functions] must be built with
/// `FirebaseFunctions.instanceFor(region: RondaApi.region)`.
/// {@endtemplate}
class const SharedPlansApi({
  /// The Firestore instance the card is read from.
  required final FirebaseFirestore firestore,

  /// The callables' client, in Ronda's region.
  required final FirebaseFunctions functions,
}) {
  /// {@macro shared_plans_api}
  this;

  /// The callable that opens a plan to the ronda.
  static const shareCallable = 'share_small_plan';

  /// The callable that takes it back.
  static const withdrawCallable = 'withdraw_small_plan';

  /// The callable for "Me sumo".
  static const joinCallable = 'join_small_plan';

  /// The callable that takes "Me sumo" back.
  static const leaveCallable = 'leave_small_plan';

  /// How long the app waits for a plan to be checked: Spark 1.3 and a cold
  /// start.
  static const shareTimeout = Duration(seconds: 60);

  /// [uid]'s own card in ronda [rondaId] now and on every change; `null`
  /// while it has nothing for them.
  Stream<SharedPlanCardDocument?> watchCard(String rondaId, String uid) =>
      firestore
          .collection('rondas')
          .doc(rondaId)
          .collection('plan_cards')
          .doc(uid)
          .snapshots()
          .map(
            (snapshot) => switch (snapshot.data()) {
              final data? => SharedPlanCardDocument.fromJson(data),
              null => null,
            },
          );

  /// Opens a plan to ronda [rondaId]: [activity] and [place] as the phone
  /// worded them (the place empty when the activity already says it), its
  /// [kind], [date] (`YYYY-MM-DD`) and [time] (`HH:MM`).
  ///
  /// Throws a [SharedPlanHeldException] with the reason when a check held
  /// it, and passes any other failure through.
  Future<void> share({
    required String rondaId,
    required String activity,
    required String place,
    required String kind,
    required String date,
    required String time,
  }) => _call(shareCallable, {
    'rondaId': rondaId,
    'activity': activity,
    'place': place,
    'kind': kind,
    'date': date,
    'time': time,
  }, timeout: shareTimeout);

  /// Takes the caller's shared plan back, with every "Me sumo".
  Future<void> withdraw(String rondaId) =>
      _call(withdrawCallable, {'rondaId': rondaId});

  /// "Me sumo" on [authorUid]'s plan.
  ///
  /// Throws a [SharedPlanGoneException] when the plan is over or withdrawn.
  Future<void> join({required String rondaId, required String authorUid}) =>
      _call(joinCallable, {'rondaId': rondaId, 'authorUid': authorUid});

  /// Takes "Me sumo" on [authorUid]'s plan back.
  Future<void> leave({required String rondaId, required String authorUid}) =>
      _call(leaveCallable, {'rondaId': rondaId, 'authorUid': authorUid});

  Future<void> _call(
    String name,
    Map<String, Object> data, {
    Duration? timeout,
  }) async {
    try {
      await functions
          .httpsCallable(
            name,
            options: timeout == null
                ? null
                : HttpsCallableOptions(timeout: timeout),
          )
          .call<Object?>(data);
    } on FirebaseFunctionsException catch (error) {
      throw switch ((error.code, error.details)) {
        ('failed-precondition', {'reason': final String reason}) =>
          SharedPlanHeldException(reason),
        ('failed-precondition', _) => const SharedPlanGoneException(),
        _ => error,
      };
    }
  }
}
