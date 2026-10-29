import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockFirebaseStorage extends Mock implements FirebaseStorage;

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions;

class _MockReference extends Mock implements Reference;

class _MockTaskSnapshot extends Mock implements TaskSnapshot;

class _MockHttpsCallable extends Mock implements HttpsCallable;

class _MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<Object?>;

/// An upload that completes with [_snapshot]; mocktail can't stand in for a
/// `Future`.
class _FakeUploadTask(final TaskSnapshot _snapshot)
    extends Fake
    implements UploadTask {
  @override
  Future<R> then<R>(
    FutureOr<R> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) => Future.value(_snapshot).then(onValue, onError: onError);
}

void main() {
  group(FlyersApi, () {
    late FirebaseStorage storage;
    late FirebaseFunctions functions;
    late Reference reference;
    late HttpsCallable callable;
    late HttpsCallableResult<Object?> result;
    late FlyersApi subject;

    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
    const answer = {
      'flyerId': 'flyer-1',
      'imagePath': 'flyers/demo-uid/flyer-1.jpg',
      'landingUrl': 'https://ronda-uy.firebaseapp.com/f/flyer-1',
    };

    setUpAll(() {
      registerFallbackValue(Uint8List(0));
      registerFallbackValue(SettableMetadata());
      registerFallbackValue(HttpsCallableOptions());
    });

    setUp(() {
      storage = _MockFirebaseStorage();
      functions = _MockFirebaseFunctions();
      reference = _MockReference();
      callable = _MockHttpsCallable();
      result = _MockHttpsCallableResult();
      subject = FlyersApi(storage: storage, functions: functions);
      when(() => storage.ref(any())).thenReturn(reference);
      when(() => functions.httpsCallable(any(), options: any(named: 'options')))
          .thenReturn(callable);
      when(() => callable.call<Object?>(any<Object?>()))
          .thenAnswer((_) async => result);
    });

    group('uploadPhoto', () {
      test('puts the JPEG under flyer_photos/{uid} and returns the '
          'path', () async {
        when(() => reference.putData(any(), any()))
            .thenAnswer((_) => _FakeUploadTask(_MockTaskSnapshot()));

        expect(
          await subject.uploadPhoto(
            uid: 'demo-uid',
            photoId: 'photo-1',
            jpeg: jpeg,
          ),
          equals('flyer_photos/demo-uid/photo-1.jpg'),
        );
        verify(() => storage.ref('flyer_photos/demo-uid/photo-1.jpg'))
            .called(1);
        final metadata =
            verify(() => reference.putData(jpeg, captureAny())).captured.single
                as SettableMetadata;
        expect(metadata.contentType, equals('image/jpeg'));
      });
    });

    test('deletePhoto deletes the object at the path', () async {
      when(() => reference.delete()).thenAnswer((_) async {});

      await subject.deletePhoto('flyer_photos/demo-uid/photo-1.jpg');

      verify(() => storage.ref('flyer_photos/demo-uid/photo-1.jpg')).called(1);
      verify(() => reference.delete()).called(1);
    });

    group('makeMateFlyer', () {
      test('calls make_mate_flyer with the ronda and the photo, and reads '
          'the flyer', () async {
        when(() => result.data).thenReturn(answer);

        expect(
          await subject.makeMateFlyer(
            rondaId: 'ronda-1',
            photoPath: 'flyer_photos/demo-uid/photo-1.jpg',
          ),
          equals(
            const MateFlyerResult(
              flyerId: 'flyer-1',
              imagePath: 'flyers/demo-uid/flyer-1.jpg',
              landingUrl: 'https://ronda-uy.firebaseapp.com/f/flyer-1',
            ),
          ),
        );
        final options =
            verify(
                  () => functions.httpsCallable(
                    FlyersApi.makeMateFlyerCallable,
                    options: captureAny(named: 'options'),
                  ),
                ).captured.single
                as HttpsCallableOptions;
        expect(options.timeout, equals(FlyersApi.makeMateFlyerTimeout));
        verify(
          () => callable.call<Object?>({
            'rondaId': 'ronda-1',
            'photoPath': 'flyer_photos/demo-uid/photo-1.jpg',
          }),
        ).called(1);
      });

      test('throws a $FormatException for an answer of another '
          'shape', () async {
        when(() => result.data).thenReturn({'flyerId': 'flyer-1'});

        expect(
          subject.makeMateFlyer(rondaId: 'r', photoPath: 'p'),
          throwsA(isA<FormatException>()),
        );
      });

      for (final (code, matcher) in [
        ('permission-denied', isA<NotAHostException>()),
        ('failed-precondition', isA<NothingToCutOutException>()),
        ('unavailable', isA<FirebaseFunctionsException>()),
      ]) {
        test('maps $code', () {
          when(() => callable.call<Object?>(any<Object?>()))
              .thenThrow(FirebaseFunctionsException(code: code, message: 'no'));

          expect(
            subject.makeMateFlyer(rondaId: 'r', photoPath: 'p'),
            throwsA(matcher),
          );
        });
      }
    });

    group('downloadFlyer', () {
      test('returns the image bytes', () async {
        when(() => reference.getData()).thenAnswer((_) async => jpeg);

        expect(
          await subject.downloadFlyer('flyers/demo-uid/flyer-1.jpg'),
          equals(jpeg),
        );
        verify(() => storage.ref('flyers/demo-uid/flyer-1.jpg')).called(1);
      });

      test('throws a $FormatException when there is nothing', () {
        when(() => reference.getData()).thenAnswer((_) async => null);

        expect(
          subject.downloadFlyer('flyers/demo-uid/flyer-1.jpg'),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });
}
