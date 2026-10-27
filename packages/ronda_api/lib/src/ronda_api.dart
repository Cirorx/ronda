import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ronda_api/src/models/models.dart';

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

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      firestore.collection(usersCollection).doc(uid);

  /// `users/{uid}` now and on every change; `null` while it doesn't exist.
  ///
  /// The document exists as soon as the terms are recorded, before the
  /// profile is saved, so existence alone says nothing about onboarding.
  Stream<UserDocument?> watchUser(String uid) => _user(uid).snapshots().map(
    (snapshot) => switch (snapshot.data()) {
      final data? => UserDocument.fromJson(data),
      null => null,
    },
  );

  /// Writes `terms` on `users/{uid}`, creating the document if needed and
  /// leaving every other field as it is.
  Future<void> saveTerms(String uid, TermsRecord terms) =>
      _user(uid).set({'terms': terms.toJson()}, SetOptions(merge: true));

  /// Writes the profile fields on `users/{uid}` and stamps `createdAt` with
  /// the server time, leaving `terms` as it is.
  Future<void> saveProfile(
    String uid, {
    required String firstName,
    required String ageBand,
    required String barrio,
    required List<String> slots,
    required List<String> pretexts,
    required List<String> brings,
  }) => _user(uid).set({
    'firstName': firstName,
    'ageBand': ageBand,
    'barrio': barrio,
    'slots': slots,
    'pretexts': pretexts,
    'brings': brings,
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
