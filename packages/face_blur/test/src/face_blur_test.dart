import 'dart:io';
import 'dart:math' as math;

import 'package:face_blur/face_blur.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress_common/flutter_image_compress_common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockImagePicker extends Mock implements ImagePicker;

class _MockFaceDetector extends Mock implements FaceDetector;

class _FakePathProvider(final String _directory)
    extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => _directory;
}

/// A photo of noise: every pixel black or white, so a pixelated region is
/// told apart from the rest by how little it varies.
Uint8List noisyJpeg(int width, int height, {bool withExif = false}) {
  final random = math.Random(7);
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    final v = random.nextBool() ? 255 : 0;
    pixel
      ..r = v
      ..g = v
      ..b = v;
  }
  if (withExif) image.exif.imageIfd['Make'] = 'Invented phone';
  return img.encodeJpg(image, quality: 95);
}

/// The spread of grey levels in a square of [image].
double spread(img.Image image, int left, int top, int size) {
  final values = [
    for (var y = top; y < top + size; y++)
      for (var x = left; x < left + size; x++)
        image.getPixel(x, y).r.toDouble(),
  ];
  final mean = values.reduce((a, b) => a + b) / values.length;
  final variance =
      values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
      values.length;
  return math.sqrt(variance);
}

void main() {
  group(FaceBlur, () {
    late ImagePicker picker;
    late FaceDetector detector;
    late Map<String, Uint8List> files;
    late List<String> deleted;
    late List<(String, String)> copies;
    late bool copySucceeds;

    setUpAll(() => registerFallbackValue(ImageSource.camera));

    setUp(() {
      picker = _MockImagePicker();
      detector = _MockFaceDetector();
      files = {};
      deleted = [];
      copies = [];
      copySucceeds = true;
      when(() => detector.detect(any())).thenAnswer((_) async => []);
      when(() => detector.close()).thenAnswer((_) async {});
    });

    FaceBlur subject() => FaceBlur(
      imagePicker: picker,
      faceDetector: detector,
      uprightCopy: (source, target) async {
        copies.add((source, target));
        if (!copySucceeds) return false;
        files[target] = files[source]!;
        return true;
      },
      temporaryDirectory: () async => '/tmp/app',
      readBytes: (path) async => files[path]!,
      deleteFile: (path) async {
        deleted.add(path);
        files.remove(path);
      },
    );

    test('can blur on phones, not on web', () {
      expect(subject().isSupported, isTrue);
      expect(FaceBlur(isSupported: false).isSupported, isFalse);
    });

    group('takePhoto', () {
      test('opens the camera or the gallery without metadata', () async {
        when(
          () => picker.pickImage(
            source: any(named: 'source'),
            requestFullMetadata: any(named: 'requestFullMetadata'),
          ),
        ).thenAnswer((_) async => XFile('/cache/taken.jpg'));

        expect(
          await subject().takePhoto(PhotoSource.camera),
          equals(const TakenPhoto.test('/cache/taken.jpg')),
        );
        await subject().takePhoto(PhotoSource.gallery);

        verify(
          () => picker.pickImage(
            source: ImageSource.camera,
            requestFullMetadata: false,
          ),
        ).called(1);
        verify(
          () => picker.pickImage(
            source: ImageSource.gallery,
            requestFullMetadata: false,
          ),
        ).called(1);
      });

      test('returns null when the person backs out', () async {
        when(
          () => picker.pickImage(
            source: any(named: 'source'),
            requestFullMetadata: any(named: 'requestFullMetadata'),
          ),
        ).thenAnswer((_) async => null);

        expect(await subject().takePhoto(PhotoSource.camera), isNull);
      });
    });

    group('retrieveLostPhoto', () {
      test('returns the photo taken while the app was stopped', () async {
        when(() => picker.retrieveLostData()).thenAnswer(
          (_) async => LostDataResponse(file: XFile('/cache/lost.jpg')),
        );

        expect(
          await subject().retrieveLostPhoto(),
          equals(const TakenPhoto.test('/cache/lost.jpg')),
        );
      });

      test('returns null when nothing was lost', () async {
        when(() => picker.retrieveLostData())
            .thenAnswer((_) async => LostDataResponse.empty());

        expect(await subject().retrieveLostPhoto(), isNull);
      });
    });

    group('blur', () {
      const taken = TakenPhoto.test('/cache/taken.jpg');

      test('pixelates each face with a margin and leaves the rest', () async {
        files['/cache/taken.jpg'] = noisyJpeg(400, 300);
        when(() => detector.detect(any()))
            .thenAnswer((_) async => [const FaceBox(100, 100, 180, 180)]);

        final photo = await subject().blur(taken);

        expect(photo.width, equals(400));
        expect(photo.height, equals(300));
        expect(photo.blurredFaces, equals(1));
        final blurred = img.decodeJpg(photo.jpeg)!;
        // The box padded by a quarter: 80..200. Cells are 15 px across, so
        // the middle of one cell is one colour; the noise elsewhere isn't.
        expect(spread(blurred, 83, 83, 9), lessThan(12));
        expect(spread(blurred, 300, 220, 9), greaterThan(60));
      });

      test('finds faces on the upright copy, then deletes it and the '
          'photo taken', () async {
        files['/cache/taken.jpg'] = noisyJpeg(40, 30);

        await subject().blur(taken);

        final copy = copies.single.$2;
        expect(copies.single.$1, equals('/cache/taken.jpg'));
        expect(copy, startsWith('/tmp/app/face_blur_'));
        expect(copy, endsWith('.jpg'));
        verify(() => detector.detect(copy)).called(1);
        expect(deleted, unorderedEquals(['/cache/taken.jpg', copy]));
      });

      test('scales a large photo down to the long side, faces '
          'included', () async {
        files['/cache/taken.jpg'] = noisyJpeg(3200, 2000);
        when(() => detector.detect(any()))
            .thenAnswer((_) async => [const FaceBox(3000, 1800, 3200, 2000)]);

        final photo = await subject().blur(taken);

        expect(photo.width, equals(FaceBlur.longSide));
        expect(photo.height, equals(1000));
        final blurred = img.decodeJpg(photo.jpeg)!;
        // The face sits in the bottom-right corner, half the size now.
        expect(spread(blurred, 1590, 990, 6), lessThan(12));
      });

      test('writes no EXIF', () async {
        files['/cache/taken.jpg'] = noisyJpeg(40, 30, withExif: true);
        expect(
          img.decodeJpg(files['/cache/taken.jpg']!)!.exif.isEmpty,
          isFalse,
        );

        final photo = await subject().blur(taken);

        expect(img.decodeJpg(photo.jpeg)!.exif.isEmpty, isTrue);
      });

      test('throws $FaceBlurException and deletes the photo when no copy '
          'could be made', () async {
        files['/cache/taken.jpg'] = noisyJpeg(40, 30);
        copySucceeds = false;

        await expectLater(
          subject().blur(taken),
          throwsA(
            isA<FaceBlurException>().having(
              (e) => e.toString(),
              'toString',
              'FaceBlurException: no upright copy',
            ),
          ),
        );
        expect(deleted, equals(['/cache/taken.jpg']));
        verifyNever(() => detector.detect(any()));
      });

      test('throws $FaceBlurException for a file that is no JPEG', () async {
        files['/cache/taken.jpg'] = Uint8List.fromList([1, 2, 3]);

        await expectLater(
          subject().blur(taken),
          throwsA(isA<FaceBlurException>()),
        );
        expect(deleted, hasLength(2));
      });

      test('carries on when a file is already gone', () async {
        files['/cache/taken.jpg'] = noisyJpeg(40, 30);
        final blur = FaceBlur(
          imagePicker: picker,
          faceDetector: detector,
          uprightCopy: (source, target) async {
            files[target] = files[source]!;
            return true;
          },
          temporaryDirectory: () async => '/tmp/app',
          readBytes: (path) async => files[path]!,
          deleteFile: (path) async => throw const FileSystemException('gone'),
        );

        expect(await blur.blur(taken), isA<BlurredPhoto>());
      });
    });

    group('blurTappedFace', () {
      test('pixelates a square around the tap and counts it', () async {
        files['/cache/taken.jpg'] = noisyJpeg(400, 300);
        final blur = subject();
        final photo = await blur.blur(
          const TakenPhoto.test('/cache/taken.jpg'),
        );

        final tapped = await blur.blurTappedFace(photo, x: 0.75, y: 0.5);

        expect(tapped.blurredFaces, equals(1));
        expect(tapped.width, equals(400));
        final image = img.decodeJpg(tapped.jpeg)!;
        // A 60 px square around (300, 150), cells of 8 px: one cell's middle.
        expect(spread(image, 272, 122, 6), lessThan(12));
        expect(spread(image, 40, 40, 9), greaterThan(60));
      });

      test('keeps a tap at the edge inside the photo', () async {
        final blur = subject();
        final photo = BlurredPhoto.test(jpeg: noisyJpeg(100, 80));
        expect(BlurredPhoto.test().jpeg, isNotEmpty);

        final tapped = await blur.blurTappedFace(photo, x: 1.4, y: -0.2);

        expect(tapped.blurredFaces, equals(1));
        expect(tapped.height, equals(80));
      });
    });

    test('closes the face detector', () async {
      await subject().close();

      verify(() => detector.close()).called(1);
    });

    test('runs on the real plugins and files by default', () async {
      final directory = Directory.systemTemp.createTempSync('face_blur');
      addTearDown(() => directory.deleteSync(recursive: true));
      PathProviderPlatform.instance = _FakePathProvider(directory.path);
      final taken = File('${directory.path}/taken.jpg')
        ..writeAsBytesSync(noisyJpeg(40, 30));
      final messenger =
          TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
            ..setMockMethodCallHandler(
              const MethodChannel('flutter_image_compress'),
              (call) async {
                final arguments = call.arguments as List<Object?>;
                final target = arguments[4]! as String;
                File(arguments[0]! as String).copySync(target);
                return target;
              },
            )
            ..setMockMethodCallHandler(
              const MethodChannel('google_mlkit_face_detector'),
              (call) async => [],
            );
      addTearDown(() {
        messenger
          ..setMockMethodCallHandler(
            const MethodChannel('flutter_image_compress'),
            null,
          )
          ..setMockMethodCallHandler(
            const MethodChannel('google_mlkit_face_detector'),
            null,
          );
      });

      FlutterImageCompressCommon.registerWith();

      final photo = await FaceBlur().blur(TakenPhoto.test(taken.path));

      expect(photo.width, equals(40));
      expect(directory.listSync(), isEmpty);
    });
  });

  group(BlurredPhoto, () {
    test('equals a photo with the same bytes and counts', () {
      final bytes = Uint8List.fromList([1, 2]);

      expect(
        BlurredPhoto.test(jpeg: bytes),
        equals(BlurredPhoto.test(jpeg: Uint8List.fromList([1, 2]))),
      );
      expect(
        BlurredPhoto.test(jpeg: bytes).hashCode,
        equals(BlurredPhoto.test(jpeg: Uint8List.fromList([1, 2])).hashCode),
      );
      expect(
        BlurredPhoto.test(jpeg: bytes),
        isNot(equals(BlurredPhoto.test(jpeg: bytes, blurredFaces: 1))),
      );
    });
  });

  group(TakenPhoto, () {
    test('equals a photo of the same file', () {
      expect(const TakenPhoto.test('a'), equals(const TakenPhoto.test('a')));
      expect(
        const TakenPhoto.test('a').hashCode,
        equals(const TakenPhoto.test('a').hashCode),
      );
      expect(
        const TakenPhoto.test(),
        isNot(equals(const TakenPhoto.test('b'))),
      );
    });
  });
}
