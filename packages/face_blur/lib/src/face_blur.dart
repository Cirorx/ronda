import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:face_blur/src/face_detector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

part 'photos.dart';
part 'pixelate.dart';

/// Writes an upright copy of the photo at `source` to `target`: rotated by
/// its EXIF orientation, EXIF dropped, its short side scaled down to
/// [FaceBlur.detectionSide]. Returns `false` when it couldn't.
typedef UprightCopy = Future<bool> Function(String source, String target);

/// {@template face_blur}
/// Takes a photo and pixelates every face in it on the phone, before it
/// goes anywhere.
///
/// [blur] makes an upright copy without EXIF, finds the faces on that
/// copy with a [FaceDetector] (ML Kit by default: detection only, never
/// recognition), then in an isolate scales the photo down to [longSide],
/// pixelates each face with some margin and encodes a JPEG with no EXIF.
/// The photo taken and the copy are deleted from the phone afterwards.
/// [blurTappedFace] pixelates a face the detector missed.
///
/// Phones only: ML Kit has no web version, so [isSupported] is `false` on
/// web and nothing here should be called there. It logs nothing.
/// {@endtemplate}
class FaceBlur {
  /// {@macro face_blur}
  new({
    ImagePicker? imagePicker,
    FaceDetector? faceDetector,
    UprightCopy? uprightCopy,
    Future<String> Function()? temporaryDirectory,
    Future<Uint8List> Function(String path)? readBytes,
    Future<void> Function(String path)? deleteFile,
    this.isSupported = !kIsWeb,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _faceDetector = faceDetector ?? MlKitFaceDetector(),
       _uprightCopy = uprightCopy ?? _compressedCopy,
       _temporaryDirectory = temporaryDirectory ?? _systemTemporaryDirectory,
       _readBytes = readBytes ?? _readFile,
       _deleteFile = deleteFile ?? _deleteIoFile;

  /// The long side of a blurred photo, in pixels.
  static const longSide = 1600;

  /// The short side of the copy faces are looked for in: larger than the
  /// blurred photo, so small faces in the background are still found.
  static const detectionSide = 2400;

  /// Whether this platform can blur faces: phones yes, web no.
  final bool isSupported;

  final ImagePicker _imagePicker;
  final FaceDetector _faceDetector;
  final UprightCopy _uprightCopy;
  final Future<String> Function() _temporaryDirectory;
  final Future<Uint8List> Function(String path) _readBytes;
  final Future<void> Function(String path) _deleteFile;

  static Future<bool> _compressedCopy(String source, String target) async =>
      await FlutterImageCompress.compressAndGetFile(
        source,
        target,
        minWidth: detectionSide,
        minHeight: detectionSide,
      ) !=
      null;

  static Future<String> _systemTemporaryDirectory() async =>
      (await getTemporaryDirectory()).path;

  static Future<Uint8List> _readFile(String path) => File(path).readAsBytes();

  static Future<void> _deleteIoFile(String path) => File(path).delete();

  /// Opens the camera or the gallery; `null` when the person backs out.
  Future<TakenPhoto?> takePhoto(PhotoSource source) async {
    final file = await _imagePicker.pickImage(
      source: switch (source) {
        PhotoSource.camera => ImageSource.camera,
        PhotoSource.gallery => ImageSource.gallery,
      },
      requestFullMetadata: false,
    );
    return file == null ? null : TakenPhoto._(file.path);
  }

  /// The photo the camera took while Android stopped the app to free
  /// memory, if any: call it when the photo screen opens again.
  Future<TakenPhoto?> retrieveLostPhoto() async {
    final lost = await _imagePicker.retrieveLostData();
    final file = lost.file;
    return file == null ? null : TakenPhoto._(file.path);
  }

  /// [photo] with every face found pixelated. [photo]'s file is deleted
  /// whatever happens, so it can't be used again.
  ///
  /// Throws a [FaceBlurException] when the photo can't be read.
  Future<BlurredPhoto> blur(TakenPhoto photo) async {
    final copy =
        '${await _temporaryDirectory()}/face_blur_'
        '${DateTime.now().microsecondsSinceEpoch}.jpg';
    var copied = false;
    try {
      copied = await _uprightCopy(photo._path, copy);
      if (!copied) throw const FaceBlurException('no upright copy');
      final faces = await _faceDetector.detect(copy);
      final jpeg = await _readBytes(copy);
      return await Isolate.run(() => _blurFaces(jpeg, faces));
    } finally {
      await _delete(photo._path);
      if (copied) await _delete(copy);
    }
  }

  /// [photo] with one more face pixelated, around the point ([x], [y]),
  /// each a share of the width and the height (0 to 1): for a face the
  /// detector missed and the person tapped.
  Future<BlurredPhoto> blurTappedFace(
    BlurredPhoto photo, {
    required double x,
    required double y,
  }) => Isolate.run(() => _blurTappedFace(photo, x, y));

  /// Releases the face detector.
  Future<void> close() => _faceDetector.close();

  Future<void> _delete(String path) async {
    try {
      await _deleteFile(path);
    } on Exception {
      // Already gone; the system clears the temporary directory anyway.
    }
  }
}
