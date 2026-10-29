import 'package:face_blur/face_blur.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart'
    as ml_kit;
import 'package:mocktail/mocktail.dart';

class _MockMlKitDetector extends Mock implements ml_kit.FaceDetector;

class _FakeInputImage extends Fake implements ml_kit.InputImage;

void main() {
  group(FaceBox, () {
    test('measures its width and height', () {
      const box = FaceBox(10, 20, 40, 80);

      expect(box.width, equals(30));
      expect(box.height, equals(60));
    });

    test('equals a box with the same edges', () {
      expect(const FaceBox(1, 2, 3, 4), equals(const FaceBox(1, 2, 3, 4)));
      expect(
        const FaceBox(1, 2, 3, 4),
        isNot(equals(const FaceBox(1, 2, 3, 5))),
      );
      expect(
        const FaceBox(1, 2, 3, 4).hashCode,
        equals(const FaceBox(1, 2, 3, 4).hashCode),
      );
      expect(
        const FaceBox(1, 2, 3, 4).toString(),
        equals('FaceBox(1.0, 2.0, 3.0, 4.0)'),
      );
    });
  });

  group(MlKitFaceDetector, () {
    late ml_kit.FaceDetector plugin;
    late int created;

    setUpAll(() => registerFallbackValue(_FakeInputImage()));

    setUp(() {
      plugin = _MockMlKitDetector();
      created = 0;
      when(() => plugin.close()).thenAnswer((_) async {});
    });

    MlKitFaceDetector subject() => MlKitFaceDetector(
      create: () {
        created++;
        return plugin;
      },
    );

    test('looks for small faces in accurate mode, boxes only', () {
      final options = MlKitFaceDetector.options;

      expect(options.performanceMode, equals(ml_kit.FaceDetectorMode.accurate));
      expect(options.minFaceSize, equals(0.03));
      expect(options.enableLandmarks, isFalse);
      expect(options.enableContours, isFalse);
      expect(options.enableClassification, isFalse);
      expect(options.enableTracking, isFalse);
    });

    test('builds no plugin detector until it detects', () async {
      final detector = subject();
      await detector.close();

      expect(created, equals(0));
      verifyNever(() => plugin.close());
    });

    test('returns the bounding box of each face, building the plugin '
        'once', () async {
      when(() => plugin.processImage(any())).thenAnswer(
        (_) async => [
          ml_kit.Face(
            boundingBox: const Rect.fromLTRB(10, 20, 110, 140),
            landmarks: const {},
            contours: const {},
          ),
        ],
      );
      final detector = subject();

      expect(
        await detector.detect('/tmp/photo.jpg'),
        equals([const FaceBox(10, 20, 110, 140)]),
      );
      await detector.detect('/tmp/photo.jpg');

      final input =
          verify(() => plugin.processImage(captureAny())).captured.first
              as ml_kit.InputImage;
      expect(input.filePath, equals('/tmp/photo.jpg'));
      expect(created, equals(1));
    });

    test('closes the plugin detector it built', () async {
      when(() => plugin.processImage(any())).thenAnswer((_) async => []);
      final detector = subject();
      await detector.detect('/tmp/photo.jpg');

      await detector.close();

      verify(() => plugin.close()).called(1);
    });

    test('talks to the ML Kit plugin by default', () async {
      final calls = <String>[];
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('google_mlkit_face_detector'),
            (call) async {
              calls.add(call.method);
              return call.method == 'vision#startFaceDetector'
                  ? [
                      {
                        'rect': {'left': 1, 'top': 2, 'right': 3, 'bottom': 4},
                        'landmarks': <String, dynamic>{},
                      },
                    ]
                  : null;
            },
          );
      final detector = MlKitFaceDetector();

      expect(
        await detector.detect('/tmp/photo.jpg'),
        equals([const FaceBox(1, 2, 3, 4)]),
      );
      await detector.close();

      expect(
        calls,
        equals(['vision#startFaceDetector', 'vision#closeFaceDetector']),
      );
    });
  });
}
