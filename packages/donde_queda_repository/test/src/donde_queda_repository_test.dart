import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:donde_queda_repository/donde_queda_repository.dart';
import 'package:face_blur/face_blur.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockFaceBlur extends Mock implements FaceBlur;

class _MockDondeQuedaApi extends Mock implements DondeQuedaApi;

void main() {
  group(DondeQuedaRepository, () {
    late FaceBlur faceBlur;
    late DondeQuedaApi api;
    late StreamController<DondeQuedaViewDocument?> views;
    late StreamController<DondeQuedaPlayerDocument?> players;
    late DondeQuedaRepository subject;

    const uid = 'demo-uid';
    const upload = 'donde_queda_photos/demo-uid/photo-1.jpg';
    const taken = TakenPhoto.test();
    final blurred = BlurredPhoto.test(blurredFaces: 1);
    const pin = MapPoint(-34.8, -55.885);
    const current = DondeQuedaCurrentDocument(
      week: '2026-W45',
      status: 'asking',
      centre: DondeQuedaPoint(lat: -34.8, lng: -55.885),
      zoom: 16,
      closesOn: '2026-11-05',
    );

    setUpAll(() {
      registerFallbackValue(Uint8List(0));
      registerFallbackValue(PhotoSource.camera);
      registerFallbackValue(BlurredPhoto.test());
      registerFallbackValue(const TakenPhoto.test());
    });

    setUp(() {
      faceBlur = _MockFaceBlur();
      api = _MockDondeQuedaApi();
      views = StreamController();
      players = StreamController();
      subject = DondeQuedaRepository(
        faceBlur: faceBlur,
        dondeQuedaApi: api,
        newPhotoId: () => 'photo-1',
      );
      when(() => api.watchView('r1')).thenAnswer((_) => views.stream);
      when(() => api.watchPlayer('r1', uid)).thenAnswer((_) => players.stream);
      when(
        () => api.uploadPhoto(
          uid: any(named: 'uid'),
          photoId: any(named: 'photoId'),
          jpeg: any(named: 'jpeg'),
        ),
      ).thenAnswer((_) async => upload);
      when(() => api.deletePhoto(any())).thenAnswer((_) async {});
    });

    test('can blur faces where face_blur can', () {
      when(() => faceBlur.isSupported).thenReturn(true);

      expect(subject.canBlurFaces, isTrue);
    });

    test('names photos with 32 random hex characters by default', () async {
      final named = DondeQuedaRepository(
        faceBlur: faceBlur,
        dondeQuedaApi: api,
      );
      when(
        () => api.post(
          rondaId: any(named: 'rondaId'),
          week: any(named: 'week'),
          photoPath: any(named: 'photoPath'),
          line: any(named: 'line'),
          hint: any(named: 'hint'),
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
        ),
      ).thenAnswer((_) async {});

      await named.post(
        uid: uid,
        rondaId: 'r1',
        week: '2026-W45',
        photo: blurred,
        line: 'x',
        hint: '',
        pin: pin,
      );

      final id =
          verify(
                () => api.uploadPhoto(
                  uid: uid,
                  photoId: captureAny(named: 'photoId'),
                  jpeg: any(named: 'jpeg'),
                ),
              ).captured.single
              as String;
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    group('watch', () {
      test('waits for both, then joins the game and the card', () async {
        final weeks = subject.watch(rondaId: 'r1', uid: uid);
        final seen = <DondeQuedaWeek>[];
        final subscription = weeks.listen(seen.add);

        views.add(
          const DondeQuedaViewDocument(
            current: current,
            reveal: DondeQuedaRevealDocument(
              week: '2026-W44',
              line: 'la puerta verde',
              close: 3,
              guessed: 5,
            ),
          ),
        );
        await pumpEventQueue();
        expect(seen, isEmpty);

        players.add(
          const DondeQuedaPlayerDocument(
            week: '2026-W45',
            asked: true,
            posted: false,
            guessed: false,
          ),
        );
        await pumpEventQueue();

        expect(
          seen.single,
          equals(
            DondeQuedaWeek(
              game: DondeQuedaGame(
                week: '2026-W45',
                status: DondeQuedaStatus.asking,
                centre: pin,
                zoom: 16,
                closesOn: DateTime(2026, 11, 5),
                isMyTurn: true,
              ),
              reveal: const DondeQuedaReveal(
                line: 'la puerta verde',
                close: 3,
                guessed: 5,
              ),
            ),
          ),
        );
        await subscription.cancel();
      });

      test("reads an open game and ignores another week's card", () async {
        final weeks = subject.watch(rondaId: 'r1', uid: uid);
        final next = weeks.first;
        views.add(
          const DondeQuedaViewDocument(
            current: DondeQuedaCurrentDocument(
              week: '2026-W45',
              status: 'open',
              centre: DondeQuedaPoint(lat: -34.8, lng: -55.885),
              zoom: 16,
              closesOn: '2026-11-05',
              photoPath: 'donde_queda/r1/2026-W45.jpg',
              hint: 'cerca de la feria',
            ),
          ),
        );
        players.add(
          const DondeQuedaPlayerDocument(
            week: '2026-W44',
            asked: false,
            posted: false,
            guessed: true,
          ),
        );

        final game = (await next).game!;
        expect(game.status, DondeQuedaStatus.open);
        expect(game.photoPath, 'donde_queda/r1/2026-W45.jpg');
        expect(game.hint, 'cerca de la feria');
        expect(game.guessed, isFalse);
        expect((await next).reveal, isNull);
      });

      test('has no game without a view, or with a status it '
          "doesn't know", () async {
        final weeks = subject.watch(rondaId: 'r1', uid: uid).take(3).toList();
        players.add(null);
        views
          ..add(null)
          ..add(
            const DondeQuedaViewDocument(
              current: DondeQuedaCurrentDocument(
                week: 'w',
                status: 'whatever',
                centre: DondeQuedaPoint(lat: 0, lng: 0),
                zoom: 16,
                closesOn: '2026-11-05',
              ),
            ),
          )
          ..add(
            const DondeQuedaViewDocument(
              current: DondeQuedaCurrentDocument(
                week: 'w',
                status: 'nobody',
                centre: DondeQuedaPoint(lat: 0, lng: 0),
                zoom: 16,
                closesOn: 'not a date',
              ),
            ),
          );

        expect(await weeks, everyElement(const DondeQuedaWeek()));
      });

      test('passes errors through', () async {
        final weeks = subject.watch(rondaId: 'r1', uid: uid);
        final first = weeks.first;
        views.addError(Exception('denied'));

        await expectLater(first, throwsException);
      });
    });

    group('the photo', () {
      test('takePhoto opens the source, or fails', () async {
        when(() => faceBlur.takePhoto(PhotoSource.gallery))
            .thenAnswer((_) async => taken);
        expect(await subject.takePhoto(PhotoSource.gallery), taken);

        when(() => faceBlur.takePhoto(any())).thenThrow(Exception('denied'));
        expect(
          subject.takePhoto(PhotoSource.camera),
          throwsA(isA<TakePhotoFailure>()),
        );
      });

      test('retrieveLostPhoto returns it, or null', () async {
        when(() => faceBlur.retrieveLostPhoto()).thenAnswer((_) async => taken);
        expect(await subject.retrieveLostPhoto(), taken);

        when(() => faceBlur.retrieveLostPhoto()).thenThrow(Exception('io'));
        expect(await subject.retrieveLostPhoto(), isNull);
      });

      test('blur and blurTappedFace go through face_blur, or fail', () async {
        when(() => faceBlur.blur(taken)).thenAnswer((_) async => blurred);
        when(() => faceBlur.blurTappedFace(blurred, x: 0.5, y: 0.5))
            .thenAnswer((_) async => blurred);
        expect(await subject.blur(taken), blurred);
        expect(await subject.blurTappedFace(blurred, x: 0.5, y: 0.5), blurred);

        when(() => faceBlur.blur(any())).thenThrow(const FaceBlurException(''));
        when(
          () => faceBlur.blurTappedFace(
            any(),
            x: any(named: 'x'),
            y: any(named: 'y'),
          ),
        ).thenThrow(const FaceBlurException(''));
        expect(subject.blur(taken), throwsA(isA<BlurPhotoFailure>()));
        expect(
          subject.blurTappedFace(blurred, x: 0, y: 0),
          throwsA(isA<BlurPhotoFailure>()),
        );
      });
    });

    group('post', () {
      Future<void> post() => subject.post(
        uid: uid,
        rondaId: 'r1',
        week: '2026-W45',
        photo: blurred,
        line: 'la puerta verde',
        hint: 'cerca de la feria',
        pin: pin,
      );

      void answers(Exception? error) =>
          when(
            () => api.post(
              rondaId: any(named: 'rondaId'),
              week: any(named: 'week'),
              photoPath: any(named: 'photoPath'),
              line: any(named: 'line'),
              hint: any(named: 'hint'),
              lat: any(named: 'lat'),
              lng: any(named: 'lng'),
            ),
          ).thenAnswer((_) async {
            if (error != null) throw error;
          });

      test('uploads the blurred JPEG and posts it with the pin', () async {
        answers(null);

        await post();

        verify(
          () =>
              api.uploadPhoto(uid: uid, photoId: 'photo-1', jpeg: blurred.jpeg),
        ).called(1);
        verify(
          () => api.post(
            rondaId: 'r1',
            week: '2026-W45',
            photoPath: upload,
            line: 'la puerta verde',
            hint: 'cerca de la feria',
            lat: -34.8,
            lng: -55.885,
          ),
        ).called(1);
        verifyNever(() => api.deletePhoto(any()));
      });

      for (final (reason, refusal) in [
        ('houseNumber', PhotoRefusal.houseNumber),
        ('person', PhotoRefusal.person),
        ('empty', PhotoRefusal.empty),
        ('words', PhotoRefusal.words),
        ('unknown', PhotoRefusal.empty),
      ]) {
        test('says why a photo was refused: $reason', () {
          answers(DondeQuedaRefusedException(reason));

          expect(
            post(),
            throwsA(
              isA<PhotoRefusedFailure>().having(
                (f) => f.reason,
                'reason',
                refusal,
              ),
            ),
          );
        });
      }

      test('fails when the turn passed on', () {
        answers(const NotYourTurnException());

        expect(post(), throwsA(isA<NotYourTurnFailure>()));
      });

      test('deletes an upload the callable may not have reached', () async {
        answers(FirebaseFunctionsException(code: 'unavailable', message: ''));

        await expectLater(post(), throwsA(isA<DondeQuedaFailure>()));
        verify(() => api.deletePhoto(upload)).called(1);
      });

      test('fails quietly when that delete fails too', () async {
        answers(FirebaseFunctionsException(code: 'unavailable', message: ''));
        when(() => api.deletePhoto(any())).thenThrow(Exception('offline'));

        await expectLater(post(), throwsA(isA<DondeQuedaFailure>()));
      });

      test('fails when the upload fails', () {
        when(
          () => api.uploadPhoto(
            uid: any(named: 'uid'),
            photoId: any(named: 'photoId'),
            jpeg: any(named: 'jpeg'),
          ),
        ).thenThrow(Exception('offline'));

        expect(post(), throwsA(isA<DondeQuedaFailure>()));
      });
    });

    group('pass', () {
      test('passes the turn', () async {
        when(() => api.pass(rondaId: 'r1', week: 'w')).thenAnswer((_) async {});

        await subject.pass(rondaId: 'r1', week: 'w');

        verify(() => api.pass(rondaId: 'r1', week: 'w')).called(1);
      });

      for (final (error, matcher) in [
        (const NotYourTurnException(), isA<NotYourTurnFailure>()),
        (Exception('offline'), isA<DondeQuedaFailure>()),
      ]) {
        test('maps ${error.runtimeType}', () {
          when(() => api.pass(rondaId: 'r1', week: 'w')).thenThrow(error);

          expect(subject.pass(rondaId: 'r1', week: 'w'), throwsA(matcher));
        });
      }
    });

    group('guess', () {
      test('drops the pin', () async {
        when(
          () => api.guess(rondaId: 'r1', week: 'w', lat: -34.8, lng: -55.885),
        ).thenAnswer((_) async {});

        await subject.guess(rondaId: 'r1', week: 'w', pin: pin);

        verify(
          () => api.guess(rondaId: 'r1', week: 'w', lat: -34.8, lng: -55.885),
        ).called(1);
      });

      for (final (error, matcher) in [
        (const AlreadyGuessedException(), isA<AlreadyGuessedFailure>()),
        (const NotYourTurnException(), isA<NotYourTurnFailure>()),
        (Exception('offline'), isA<DondeQuedaFailure>()),
      ]) {
        test('maps ${error.runtimeType}', () {
          when(
            () => api.guess(
              rondaId: any(named: 'rondaId'),
              week: any(named: 'week'),
              lat: any(named: 'lat'),
              lng: any(named: 'lng'),
            ),
          ).thenThrow(error);

          expect(
            subject.guess(rondaId: 'r1', week: 'w', pin: pin),
            throwsA(matcher),
          );
        });
      }
    });

    group('photo', () {
      test('downloads the bytes, or fails', () async {
        final jpeg = Uint8List.fromList([1, 2]);
        when(() => api.downloadPhoto('p')).thenAnswer((_) async => jpeg);
        expect(await subject.photo('p'), jpeg);

        when(() => api.downloadPhoto('p')).thenThrow(const FormatException());
        expect(subject.photo('p'), throwsA(isA<DondeQuedaFailure>()));
      });
    });

    test('a refusal keeps its reason', () {
      expect(
        const PhotoRefusedFailure(PhotoRefusal.words).reason,
        PhotoRefusal.words,
      );
    });
  });
}
