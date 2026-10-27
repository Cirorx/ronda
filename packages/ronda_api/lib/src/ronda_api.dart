import 'package:cloud_firestore/cloud_firestore.dart';

/// {@template ronda_api}
/// Ronda's data client over Firebase.
///
/// [firestore] is built in bootstrap, pointed at the Firestore emulator in
/// the development flavor. Callables join as a `FirebaseFunctions` built with
/// `FirebaseFunctions.instanceFor(region: RondaApi.region)` when the first one
/// exists; without the region the plugin calls `us-central1`.
/// {@endtemplate}
class const RondaApi({
  /// The Firestore instance every read and write goes through.
  required final FirebaseFirestore firestore,
}) {
  /// {@macro ronda_api}
  this;

  /// Where every Ronda function and callable runs.
  static const region = 'southamerica-east1';

  /// The collection of member profiles, one document per Firebase uid.
  static const usersCollection = 'users';

  /// Whether `users/{uid}` exists, now and on every change: a signed-in
  /// person without one has not finished onboarding.
  Stream<bool> watchUserExists(String uid) => firestore
      .collection(usersCollection)
      .doc(uid)
      .snapshots()
      .map((snapshot) => snapshot.exists);
}
