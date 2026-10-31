import 'dart:developer';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ronda_api/src/donde_queda/donde_queda_documents.dart';
import 'package:ronda_api/src/ronda_api_exceptions.dart';

/// {@template donde_queda_api}
/// ¿Dónde queda?, the ronda's weekly barrio photo game
/// (`functions/donde_queda.py`): the game's view and the member's own card
/// in Firestore, the photo up to `donde_queda_photos/{uid}/{photoId}.jpg`
/// and the published one down from `donde_queda/{rondaId}/{week}.jpg`, and
/// the callables `post_donde_queda`, `pass_donde_queda` and
/// `guess_donde_queda`.
///
/// It uploads whatever bytes it is given: the repository above it takes
/// only a photo with its faces already blurred. [functions] must be built
/// with `FirebaseFunctions.instanceFor(region: RondaApi.region)`.
/// {@endtemplate}
class const DondeQuedaApi({
  /// The Firestore instance the view and the card are read from.
  required final FirebaseFirestore firestore,

  /// The Storage bucket photos go to and come from.
  required final FirebaseStorage storage,

  /// The callables' client, in Ronda's region.
  required final FirebaseFunctions functions,
}) {
  /// {@macro donde_queda_api}
  this;

  /// The callable that posts the week's photo.
  static const postCallable = 'post_donde_queda';

  /// The callable for "Esta semana no".
  static const passCallable = 'pass_donde_queda';

  /// The callable that drops a member's pin.
  static const guessCallable = 'guess_donde_queda';

  /// How long the app waits for the photo to be checked: SAM 3.1 three
  /// times side by side and Spark 1.3, plus a cold start.
  static const postTimeout = Duration(seconds: 120);

  DocumentReference<Map<String, dynamic>> _ronda(String rondaId) =>
      firestore.collection('rondas').doc(rondaId);

  /// `rondas/{rondaId}/views/donde_queda` now and on every change; `null`
  /// while there is none.
  Stream<DondeQuedaViewDocument?> watchView(String rondaId) =>
      _ronda(rondaId)
          .collection('views')
          .doc('donde_queda')
          .snapshots()
          .map(
            (snapshot) => switch (snapshot.data()) {
              final data? => DondeQuedaViewDocument.fromJson(data),
              null => null,
            },
          );

  /// [uid]'s own card in ronda [rondaId]'s game, now and on every change;
  /// `null` while there is none.
  Stream<DondeQuedaPlayerDocument?> watchPlayer(String rondaId, String uid) =>
      _ronda(rondaId)
          .collection('donde_queda_players')
          .doc(uid)
          .snapshots()
          .map(
            (snapshot) => switch (snapshot.data()) {
              final data? => DondeQuedaPlayerDocument.fromJson(data),
              null => null,
            },
          );

  /// Uploads [jpeg] to `donde_queda_photos/{uid}/{photoId}.jpg` and returns
  /// that path. Logs its size and how long it took, never the photo.
  Future<String> uploadPhoto({
    required String uid,
    required String photoId,
    required Uint8List jpeg,
  }) async {
    final path = 'donde_queda_photos/$uid/$photoId.jpg';
    final watch = Stopwatch()..start();
    await storage
        .ref(path)
        .putData(jpeg, SettableMetadata(contentType: 'image/jpeg'));
    log(
      'donde queda photo uploaded: ${jpeg.length} bytes '
      'in ${watch.elapsedMilliseconds} ms',
    );
    return path;
  }

  /// Deletes the upload at [path], for when the callable never got it.
  Future<void> deletePhoto(String path) => storage.ref(path).delete();

  /// The published photo at [path], as JPEG bytes.
  ///
  /// Throws a [FormatException] when Storage has nothing there.
  Future<Uint8List> downloadPhoto(String path) async {
    final bytes = await storage.ref(path).getData();
    if (bytes == null) throw FormatException('no photo at $path');
    return bytes;
  }

  /// Posts the photo uploaded at [photoPath] for ronda [rondaId]'s game of
  /// [week]: what it is ([line]), an optional [hint], and where it is (the
  /// pin at [lat], [lng]). The callable deletes the upload before it
  /// answers.
  ///
  /// Throws a [DondeQuedaRefusedException] with the reason when the photo
  /// or its words were refused, a [NotYourTurnException] when it isn't the
  /// caller's turn any more, and passes any other failure through.
  Future<void> post({
    required String rondaId,
    required String week,
    required String photoPath,
    required String line,
    required String hint,
    required double lat,
    required double lng,
  }) => _call(postCallable, {
    'rondaId': rondaId,
    'week': week,
    'photoPath': photoPath,
    'line': line,
    'hint': hint,
    'lat': lat,
    'lng': lng,
  }, timeout: postTimeout);

  /// "Esta semana no": the turn passes on.
  ///
  /// Throws a [NotYourTurnException] when it isn't the caller's turn any
  /// more, and passes any other failure through.
  Future<void> pass({required String rondaId, required String week}) =>
      _call(passCallable, {'rondaId': rondaId, 'week': week});

  /// Drops the caller's one pin at [lat], [lng] on [week]'s photo.
  ///
  /// Throws an [AlreadyGuessedException] when they already did, a
  /// [NotYourTurnException] when the game is closed or the photo is
  /// theirs, and passes any other failure through.
  Future<void> guess({
    required String rondaId,
    required String week,
    required double lat,
    required double lng,
  }) => _call(guessCallable, {
    'rondaId': rondaId,
    'week': week,
    'lat': lat,
    'lng': lng,
  });

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
          DondeQuedaRefusedException(reason),
        ('failed-precondition' || 'permission-denied', _) =>
          const NotYourTurnException(),
        ('already-exists', _) => const AlreadyGuessedException(),
        _ => error,
      };
    }
  }
}
