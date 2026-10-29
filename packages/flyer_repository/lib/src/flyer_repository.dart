import 'dart:math';

import 'package:face_blur/face_blur.dart';
import 'package:flyer_repository/src/flyer_failures.dart';
import 'package:flyer_repository/src/models/models.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:share_sheet/share_sheet.dart';

/// {@template flyer_repository}
/// The host's "Un mate de más" flyer, from the photo to the share sheet.
///
/// **Only a blurred photo leaves the phone.** [makeMateFlyer] takes a
/// [BlurredPhoto], which only [FaceBlur] makes; the photo taken is a
/// [TakenPhoto], whose pixels nothing outside `face_blur` can read. So
/// there is no way to hand the upload a photo whose faces weren't blurred.
///
/// Phones only: [canBlurFaces] is `false` on web, where ML Kit doesn't
/// exist, and nothing else here should be called there.
/// {@endtemplate}
class FlyerRepository {
  /// {@macro flyer_repository}
  new({
    required this._faceBlur,
    required this._flyersApi,
    required this._shareSheet,
    String Function()? newPhotoId,
  }) : _newPhotoId = newPhotoId ?? _randomPhotoId;

  final FaceBlur _faceBlur;
  final FlyersApi _flyersApi;
  final ShareSheet _shareSheet;
  final String Function() _newPhotoId;

  /// The file name a shared flyer gets.
  static const fileName = 'volante-un-mate-de-mas.jpg';

  static String _randomPhotoId() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  /// Whether this platform can blur faces, and so make a flyer.
  bool get canBlurFaces => _faceBlur.isSupported;

  /// Opens the camera or the gallery; `null` when the person backs out.
  ///
  /// Throws a [TakePhotoFailure] when neither opens.
  Future<TakenPhoto?> takePhoto(PhotoSource source) async {
    try {
      return await _faceBlur.takePhoto(source);
    } on Exception {
      throw const TakePhotoFailure();
    }
  }

  /// The photo the camera took while Android stopped the app, if any;
  /// `null` when there is none or it can't be read.
  Future<TakenPhoto?> retrieveLostPhoto() async {
    try {
      return await _faceBlur.retrieveLostPhoto();
    } on Exception {
      return null;
    }
  }

  /// [photo] with every face found pixelated.
  ///
  /// Throws a [BlurPhotoFailure] when it can't be read.
  Future<BlurredPhoto> blur(TakenPhoto photo) async {
    try {
      return await _faceBlur.blur(photo);
    } on Exception {
      throw const BlurPhotoFailure();
    }
  }

  /// [photo] with the face around ([x], [y]) pixelated too.
  ///
  /// Throws a [BlurPhotoFailure] when it can't be.
  Future<BlurredPhoto> blurTappedFace(
    BlurredPhoto photo, {
    required double x,
    required double y,
  }) async {
    try {
      return await _faceBlur.blurTappedFace(photo, x: x, y: y);
    } on Exception {
      throw const BlurPhotoFailure();
    }
  }

  /// Uploads [photo] for ronda [rondaId], awaits `make_mate_flyer` and
  /// downloads the flyer it made.
  ///
  /// Throws a [NotAHostFailure] when [uid] may not make that ronda's
  /// flyer, a [NothingToCutOutFailure] when the photo shows nothing to cut
  /// out, and a [MakeFlyerFailure] for anything else. The callable deletes
  /// the photo; when it never got to, this repository does.
  Future<MateFlyer> makeMateFlyer({
    required String uid,
    required String rondaId,
    required BlurredPhoto photo,
  }) async {
    final String photoPath;
    try {
      photoPath = await _flyersApi.uploadPhoto(
        uid: uid,
        photoId: _newPhotoId(),
        jpeg: photo.jpeg,
      );
    } on Exception {
      throw const MakeFlyerFailure();
    }

    final MateFlyerResult result;
    try {
      result = await _flyersApi.makeMateFlyer(
        rondaId: rondaId,
        photoPath: photoPath,
      );
    } on NotAHostException {
      throw const NotAHostFailure();
    } on NothingToCutOutException {
      throw const NothingToCutOutFailure();
    } on Exception {
      await _deleteUnread(photoPath);
      throw const MakeFlyerFailure();
    }

    try {
      return MateFlyer(
        id: result.flyerId,
        image: await _flyersApi.downloadFlyer(result.imagePath),
        landingUrl: result.landingUrl,
      );
    } on Exception {
      throw const MakeFlyerFailure();
    }
  }

  /// Opens the share sheet with [flyer], titled [title]. Returns whether
  /// the person shared it somewhere.
  ///
  /// Throws a [ShareFlyerFailure] when the sheet can't open.
  Future<bool> shareFlyer(MateFlyer flyer, {String? title}) async {
    try {
      return await _shareSheet.shareFile(
        flyer.image,
        fileName: fileName,
        mimeType: 'image/jpeg',
        title: title,
      );
    } on Exception {
      throw const ShareFlyerFailure();
    }
  }

  /// Deletes a photo the callable may not have reached. One it did read is
  /// already gone, so a failure here is expected; the bucket's 1-day
  /// lifecycle rule on `flyer_photos/` is the backstop.
  Future<void> _deleteUnread(String path) async {
    try {
      await _flyersApi.deletePhoto(path);
    } on Exception {
      // Already deleted, or unreachable: the lifecycle rule removes it.
    }
  }
}
