import 'dart:developer';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ronda_api/src/models/models.dart';
import 'package:ronda_api/src/ronda_api_exceptions.dart';

/// {@template ronda_api}
/// Ronda's data client over Firebase.
///
/// Every client is built in bootstrap, pointed at the emulators in the
/// development flavor. [functions] must be
/// `FirebaseFunctions.instanceFor(region: RondaApi.region)`: without the
/// region the plugin calls `us-central1`.
/// {@endtemplate}
class const RondaApi({
  /// The Firestore instance every read and write goes through.
  required final FirebaseFirestore firestore,

  /// The Storage bucket voice notes are uploaded to.
  required final FirebaseStorage storage,

  /// The callables, in [region].
  required final FirebaseFunctions functions,
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

  /// `users/{uid}` once, or `null` when it doesn't exist.
  Future<UserDocument?> readUser(String uid) async =>
      switch ((await _user(uid).get()).data()) {
        final data? => UserDocument.fromJson(data),
        null => null,
      };

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

  /// How long the app waits for `extract`: Voice Transcribe and Spark 1.3
  /// take a few seconds each, a cold start a few more.
  static const extractTimeout = Duration(seconds: 120);

  /// Uploads a WAV voice note to `audio/{uid}/{noteId}.wav` and returns
  /// that path. Logs its size and how long the upload took, never the audio.
  Future<String> uploadVoiceNote({
    required String uid,
    required String noteId,
    required Uint8List wav,
  }) async {
    final path = 'audio/$uid/$noteId.wav';
    final watch = Stopwatch()..start();
    await storage
        .ref(path)
        .putData(wav, SettableMetadata(contentType: 'audio/wav'));
    log(
      'voice note uploaded: ${wav.length} bytes '
      'in ${watch.elapsedMilliseconds} ms',
    );
    return path;
  }

  /// Deletes the voice note at [path], for when `extract` never read it.
  Future<void> deleteVoiceNote(String path) => storage.ref(path).delete();

  /// Calls `extract` on the voice note at [path]. The callable deletes the
  /// note before it answers.
  ///
  /// Throws an [UnreadableVoiceNoteException] when the callable couldn't
  /// read the note; any other failure passes through.
  Future<ExtractedFields> extract(String path) async {
    try {
      final result = await functions
          .httpsCallable(
            'extract',
            options: HttpsCallableOptions(timeout: extractTimeout),
          )
          .call<Object?>({'path': path});
      return switch (result.data) {
        final Map<Object?, Object?> json => ExtractedFields.fromJson(json),
        _ => const ExtractedFields(),
      };
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'invalid-argument') {
        throw const UnreadableVoiceNoteException();
      }
      rethrow;
    }
  }
}
