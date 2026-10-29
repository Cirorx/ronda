import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:face_blur/face_blur.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyer_repository/flyer_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:share_sheet/share_sheet.dart';

class _MockFaceBlur extends Mock implements FaceBlur;

class _MockFlyersApi extends Mock implements FlyersApi;

class _MockShareSheet extends Mock implements ShareSheet;

void main() {
  group(FlyerRepository, () {
    late FaceBlur faceBlur;
    late FlyersApi flyersApi;
    late ShareSheet shareSheet;
    late FlyerRepository subject;

    const uid = 'demo-uid';
    const photoPath = 'flyer_photos/demo-uid/photo-1.jpg';
    const taken = TakenPhoto.test();
    final blurred = BlurredPhoto.test(blurredFaces: 2);
    final image = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
    final flyer = MateFlyer(
      id: 'flyer-1',
      image: image,
      landingUrl: 'https://ronda-uy.web.app/f/flyer-1',
    );

    setUpAll(() {
      registerFallbackValue(Uint8List(0));
      registerFallbackValue(PhotoSource.camera);
      registerFallbackValue(BlurredPhoto.test());
    });

    setUp(() {
      faceBlur = _MockFaceBlur();
      flyersApi = _MockFlyersApi();
      shareSheet = _MockShareSheet();
      subject = FlyerRepository(
        faceBlur: faceBlur,
        flyersApi: flyersApi,
        shareSheet: shareSheet,
        newPhotoId: () => 'photo-1',
      );
      when(
        () => flyersApi.uploadPhoto(
          uid: any(named: 'uid'),
          photoId: any(named: 'photoId'),
          jpeg: any(named: 'jpeg'),
        ),
      ).thenAnswer((_) async => photoPath);
      when(
        () => flyersApi.makeMateFlyer(
          rondaId: any(named: 'rondaId'),
          photoPath: any(named: 'photoPath'),
        ),
      ).thenAnswer(
        (_) async => const MateFlyerResult(
          flyerId: 'flyer-1',
          imagePath: 'flyers/demo-uid/flyer-1.jpg',
          landingUrl: 'https://ronda-uy.web.app/f/flyer-1',
        ),
      );
      when(() => flyersApi.downloadFlyer(any())).thenAnswer((_) async => image);
      when(() => flyersApi.deletePhoto(any())).thenAnswer((_) async {});
    });

    test('can blur faces where face_blur can', () {
      when(() => faceBlur.isSupported).thenReturn(false);

      expect(subject.canBlurFaces, isFalse);
    });

    test('names photos with 32 random hex characters by default', () async {
      final ids = <String>[];
      when(
        () => flyersApi.uploadPhoto(
          uid: any(named: 'uid'),
          photoId: any(named: 'photoId'),
          jpeg: any(named: 'jpeg'),
        ),
      ).thenAnswer((invocation) async {
        ids.add(invocation.namedArguments[#photoId] as String);
        return photoPath;
      });
      final random = FlyerRepository(
        faceBlur: faceBlur,
        flyersApi: flyersApi,
        shareSheet: shareSheet,
      );

      await random.makeMateFlyer(uid: uid, rondaId: 'r', photo: blurred);
      await random.makeMateFlyer(uid: uid, rondaId: 'r', photo: blurred);

      expect(ids.first, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(ids.first, isNot(equals(ids.last)));
    });

    group('takePhoto', () {
      test('returns the photo taken', () async {
        when(() => faceBlur.takePhoto(PhotoSource.gallery))
            .thenAnswer((_) async => taken);

        expect(await subject.takePhoto(PhotoSource.gallery), equals(taken));
      });

      test('throws $TakePhotoFailure when the picker fails', () {
        when(() => faceBlur.takePhoto(any())).thenThrow(Exception());

        expect(
          subject.takePhoto(PhotoSource.camera),
          throwsA(isA<TakePhotoFailure>()),
        );
      });
    });

    group('retrieveLostPhoto', () {
      test('returns the lost photo', () async {
        when(() => faceBlur.retrieveLostPhoto()).thenAnswer((_) async => taken);

        expect(await subject.retrieveLostPhoto(), equals(taken));
      });

      test('returns null when it fails', () async {
        when(() => faceBlur.retrieveLostPhoto()).thenThrow(Exception());

        expect(await subject.retrieveLostPhoto(), isNull);
      });
    });

    group('blur', () {
      test('returns the blurred photo', () async {
        when(() => faceBlur.blur(taken)).thenAnswer((_) async => blurred);

        expect(await subject.blur(taken), equals(blurred));
      });

      test('throws $BlurPhotoFailure when blurring fails', () {
        when(() => faceBlur.blur(taken))
            .thenThrow(const FaceBlurException('no'));

        expect(subject.blur(taken), throwsA(isA<BlurPhotoFailure>()));
      });
    });

    group('blurTappedFace', () {
      test('returns the photo with the tapped face blurred', () async {
        final tapped = BlurredPhoto.test(blurredFaces: 3);
        when(() => faceBlur.blurTappedFace(blurred, x: 0.5, y: 0.25))
            .thenAnswer((_) async => tapped);

        expect(
          await subject.blurTappedFace(blurred, x: 0.5, y: 0.25),
          equals(tapped),
        );
      });

      test('throws $BlurPhotoFailure when it fails', () {
        when(
          () => faceBlur.blurTappedFace(
            any(),
            x: any(named: 'x'),
            y: any(named: 'y'),
          ),
        ).thenThrow(Exception());

        expect(
          subject.blurTappedFace(blurred, x: 0, y: 0),
          throwsA(isA<BlurPhotoFailure>()),
        );
      });
    });

    group('makeMateFlyer', () {
      test('uploads the blurred JPEG, awaits the flyer and downloads '
          'it', () async {
        expect(
          await subject.makeMateFlyer(
            uid: uid,
            rondaId: 'ronda-1',
            photo: blurred,
          ),
          equals(flyer),
        );
        verify(
          () => flyersApi.uploadPhoto(
            uid: uid,
            photoId: 'photo-1',
            jpeg: blurred.jpeg,
          ),
        ).called(1);
        verify(
          () =>
              flyersApi.makeMateFlyer(rondaId: 'ronda-1', photoPath: photoPath),
        ).called(1);
        verify(() => flyersApi.downloadFlyer('flyers/demo-uid/flyer-1.jpg'))
            .called(1);
        verifyNever(() => flyersApi.deletePhoto(any()));
      });

      test('throws $MakeFlyerFailure when the upload fails', () {
        when(
          () => flyersApi.uploadPhoto(
            uid: any(named: 'uid'),
            photoId: any(named: 'photoId'),
            jpeg: any(named: 'jpeg'),
          ),
        ).thenThrow(Exception());

        expect(
          subject.makeMateFlyer(uid: uid, rondaId: 'r', photo: blurred),
          throwsA(isA<MakeFlyerFailure>()),
        );
      });

      for (final (thrown, failure) in [
        (const NotAHostException(), isA<NotAHostFailure>()),
        (const NothingToCutOutException(), isA<NothingToCutOutFailure>()),
      ]) {
        test('throws ${failure.runtimeType} when the callable refuses with '
            '${thrown.runtimeType}, leaving the delete to it', () async {
          when(
            () => flyersApi.makeMateFlyer(
              rondaId: any(named: 'rondaId'),
              photoPath: any(named: 'photoPath'),
            ),
          ).thenThrow(thrown);

          await expectLater(
            subject.makeMateFlyer(uid: uid, rondaId: 'r', photo: blurred),
            throwsA(failure),
          );
          verifyNever(() => flyersApi.deletePhoto(any()));
        });
      }

      test('deletes the photo and throws $MakeFlyerFailure when the call '
          'fails', () async {
        when(
          () => flyersApi.makeMateFlyer(
            rondaId: any(named: 'rondaId'),
            photoPath: any(named: 'photoPath'),
          ),
        ).thenThrow(
          FirebaseFunctionsException(code: 'unavailable', message: ''),
        );

        await expectLater(
          subject.makeMateFlyer(uid: uid, rondaId: 'r', photo: blurred),
          throwsA(isA<MakeFlyerFailure>()),
        );
        verify(() => flyersApi.deletePhoto(photoPath)).called(1);
      });

      test('still throws $MakeFlyerFailure when that delete fails', () async {
        when(
          () => flyersApi.makeMateFlyer(
            rondaId: any(named: 'rondaId'),
            photoPath: any(named: 'photoPath'),
          ),
        ).thenThrow(Exception());
        when(() => flyersApi.deletePhoto(any())).thenThrow(Exception());

        await expectLater(
          subject.makeMateFlyer(uid: uid, rondaId: 'r', photo: blurred),
          throwsA(isA<MakeFlyerFailure>()),
        );
      });

      test('throws $MakeFlyerFailure when the download fails', () {
        when(() => flyersApi.downloadFlyer(any())).thenThrow(Exception());

        expect(
          subject.makeMateFlyer(uid: uid, rondaId: 'r', photo: blurred),
          throwsA(isA<MakeFlyerFailure>()),
        );
      });
    });

    group('shareFlyer', () {
      test('shares the flyer as a JPEG with its title', () async {
        when(
          () => shareSheet.shareFile(
            any(),
            fileName: any(named: 'fileName'),
            mimeType: any(named: 'mimeType'),
            title: any(named: 'title'),
          ),
        ).thenAnswer((_) async => true);

        expect(await subject.shareFlyer(flyer, title: 'Tu volante'), isTrue);
        verify(
          () => shareSheet.shareFile(
            image,
            fileName: FlyerRepository.fileName,
            mimeType: 'image/jpeg',
            title: 'Tu volante',
          ),
        ).called(1);
      });

      test('throws $ShareFlyerFailure when the sheet fails', () {
        when(
          () => shareSheet.shareFile(
            any(),
            fileName: any(named: 'fileName'),
            mimeType: any(named: 'mimeType'),
            title: any(named: 'title'),
          ),
        ).thenThrow(Exception());

        expect(subject.shareFlyer(flyer), throwsA(isA<ShareFlyerFailure>()));
      });
    });
  });
}
