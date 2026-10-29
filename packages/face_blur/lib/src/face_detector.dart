import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart'
    as ml_kit;

/// {@template face_box}
/// Where a face is in an image, in that image's pixels.
/// {@endtemplate}
@immutable
final class FaceBox {
  /// {@macro face_box}
  const new(this.left, this.top, this.right, this.bottom);

  /// The left edge.
  final double left;

  /// The top edge.
  final double top;

  /// The right edge.
  final double right;

  /// The bottom edge.
  final double bottom;

  /// The box's width.
  double get width => right - left;

  /// The box's height.
  double get height => bottom - top;

  @override
  bool operator ==(Object other) =>
      other is FaceBox &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'FaceBox($left, $top, $right, $bottom)';
}

/// Finds the faces in an image file. Detection only: nothing recognises who
/// a face belongs to.
abstract interface class FaceDetector {
  /// The faces in the image at [imagePath], in its pixels.
  Future<List<FaceBox>> detect(String imagePath);

  /// Releases the detector.
  Future<void> close();
}

/// {@template ml_kit_face_detector}
/// [FaceDetector] on ML Kit's on-device face detection, in its accurate
/// mode, finding faces down to 3% of the image's width.
///
/// The plugin's detector is built on the first [detect], so nothing of ML
/// Kit runs on a platform that never detects (web).
/// {@endtemplate}
class MlKitFaceDetector implements FaceDetector {
  /// {@macro ml_kit_face_detector}
  new({ml_kit.FaceDetector Function()? create}) : _create = create ?? _plugin;

  /// How faces are looked for: accurate, small faces too, and nothing but
  /// the bounding box (no landmarks, contours, classification or tracking).
  static final options = ml_kit.FaceDetectorOptions(
    performanceMode: ml_kit.FaceDetectorMode.accurate,
    minFaceSize: 0.03,
  );

  static ml_kit.FaceDetector _plugin() => ml_kit.FaceDetector(options: options);

  final ml_kit.FaceDetector Function() _create;
  ml_kit.FaceDetector? _detector;

  @override
  Future<List<FaceBox>> detect(String imagePath) async {
    final detector = _detector ??= _create();
    final faces = await detector.processImage(
      ml_kit.InputImage.fromFilePath(imagePath),
    );
    return [
      for (final face in faces)
        FaceBox(
          face.boundingBox.left,
          face.boundingBox.top,
          face.boundingBox.right,
          face.boundingBox.bottom,
        ),
    ];
  }

  @override
  Future<void> close() async {
    final detector = _detector;
    _detector = null;
    await detector?.close();
  }
}
