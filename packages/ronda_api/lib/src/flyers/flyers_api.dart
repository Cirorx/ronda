import 'dart:developer';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ronda_api/src/flyers/mate_flyer_result.dart';
import 'package:ronda_api/src/ronda_api_exceptions.dart';

/// {@template flyers_api}
/// The host's side of the "Un mate de más" flyer: uploads a photo to
/// `flyer_photos/{uid}/{photoId}.jpg`, calls `make_mate_flyer` on it and
/// downloads the flyer it made from `flyers/{uid}/{flyerId}.jpg`.
///
/// It uploads whatever bytes it is given: the repository above it takes
/// only a photo with its faces already blurred. Storage rules let only the
/// owner write the photo and read the flyer; the callable deletes the photo
/// whatever happens. [functions] must be built with
/// `FirebaseFunctions.instanceFor(region: RondaApi.region)`.
/// {@endtemplate}
class const FlyersApi({
  /// The Storage bucket photos go to and flyers come from.
  required final FirebaseStorage storage,

  /// The callables' client, in Ronda's region.
  required final FirebaseFunctions functions,
}) {
  /// {@macro flyers_api}
  this;

  /// The callable that makes a flyer from an uploaded photo.
  static const makeMateFlyerCallable = 'make_mate_flyer';

  /// How long the app waits for the flyer: SAM 3.1 and Muse Image run side
  /// by side, about 20 s, plus a cold start.
  static const makeMateFlyerTimeout = Duration(seconds: 150);

  /// Uploads [jpeg] to `flyer_photos/{uid}/{photoId}.jpg` and returns that
  /// path. Logs its size and how long the upload took, never the photo.
  Future<String> uploadPhoto({
    required String uid,
    required String photoId,
    required Uint8List jpeg,
  }) async {
    final path = 'flyer_photos/$uid/$photoId.jpg';
    final watch = Stopwatch()..start();
    await storage
        .ref(path)
        .putData(jpeg, SettableMetadata(contentType: 'image/jpeg'));
    log(
      'flyer photo uploaded: ${jpeg.length} bytes '
      'in ${watch.elapsedMilliseconds} ms',
    );
    return path;
  }

  /// Deletes the photo at [path], for when `make_mate_flyer` never got it.
  Future<void> deletePhoto(String path) => storage.ref(path).delete();

  /// Calls `make_mate_flyer` on the photo at [photoPath] for ronda
  /// [rondaId]. The callable deletes the photo before it answers.
  ///
  /// Throws a [NotAHostException] when the caller may not make that
  /// ronda's flyer, a [NothingToCutOutException] when no termo, mazo or
  /// mate was found in the photo, and passes any other failure through.
  Future<MateFlyerResult> makeMateFlyer({
    required String rondaId,
    required String photoPath,
  }) async {
    try {
      final result = await functions
          .httpsCallable(
            makeMateFlyerCallable,
            options: HttpsCallableOptions(timeout: makeMateFlyerTimeout),
          )
          .call<Object?>({'rondaId': rondaId, 'photoPath': photoPath});
      return MateFlyerResult.fromJson(result.data);
    } on FirebaseFunctionsException catch (error) {
      throw switch (error.code) {
        'permission-denied' => const NotAHostException(),
        'failed-precondition' => const NothingToCutOutException(),
        _ => error,
      };
    }
  }

  /// The flyer image at [imagePath], as JPEG bytes (Storage's default cap
  /// of 10 MB is far above one).
  ///
  /// Throws a [FormatException] when Storage has nothing there.
  Future<Uint8List> downloadFlyer(String imagePath) async {
    final bytes = await storage.ref(imagePath).getData();
    if (bytes == null) throw FormatException('no flyer at $imagePath');
    return bytes;
  }
}
