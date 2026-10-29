part of 'face_blur.dart';

/// {@template taken_photo}
/// A photo just taken or picked, before any face in it is blurred.
///
/// It is opaque on purpose: nothing outside this package can read its
/// pixels, so nothing can upload it. [FaceBlur.blur] turns it into a
/// [BlurredPhoto], the only photo that may leave the phone.
/// {@endtemplate}
@immutable
final class TakenPhoto {
  const new _(this._path);

  /// A photo at [path], for tests that pass one to a mocked [FaceBlur].
  @visibleForTesting
  const new test([String path = 'taken.jpg']) : this._(path);

  final String _path;

  @override
  bool operator ==(Object other) => other is TakenPhoto && other._path == _path;

  @override
  int get hashCode => _path.hashCode;
}

/// {@template blurred_photo}
/// A photo with every face found in it pixelated, upright, at most
/// [FaceBlur.longSide] pixels on its long side, as a JPEG with no EXIF (so
/// no location either).
///
/// Only [FaceBlur] makes one, so a method that takes a [BlurredPhoto] can't
/// be handed a photo nobody blurred.
/// {@endtemplate}
@immutable
final class BlurredPhoto {
  const new _({
    required this.jpeg,
    required this.width,
    required this.height,
    required this.blurredFaces,
  });

  /// A photo with these bytes, for tests of code that receives one.
  @visibleForTesting
  new test({
    Uint8List? jpeg,
    int width = 4,
    int height = 3,
    int blurredFaces = 0,
  }) : this._(
         jpeg: jpeg ?? Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]),
         width: width,
         height: height,
         blurredFaces: blurredFaces,
       );

  /// The JPEG bytes: what the preview shows and what is uploaded.
  final Uint8List jpeg;

  /// The width in pixels.
  final int width;

  /// The height in pixels.
  final int height;

  /// How many faces are pixelated: the detector's and the ones tapped.
  final int blurredFaces;

  @override
  bool operator ==(Object other) =>
      other is BlurredPhoto &&
      other.width == width &&
      other.height == height &&
      other.blurredFaces == blurredFaces &&
      listEquals(other.jpeg, jpeg);

  @override
  int get hashCode =>
      Object.hash(width, height, blurredFaces, Object.hashAll(jpeg));
}

/// Where a photo comes from.
enum PhotoSource {
  /// The phone's camera.
  camera,

  /// The phone's gallery.
  gallery,
}

/// {@template face_blur_exception}
/// A photo that couldn't be read or blurred.
/// {@endtemplate}
class FaceBlurException implements Exception {
  /// {@macro face_blur_exception}
  const new(this.message);

  /// What went wrong, for logs; never the photo.
  final String message;

  @override
  String toString() => 'FaceBlurException: $message';
}
