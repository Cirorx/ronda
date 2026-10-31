import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
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
  group(DondeQuedaApi, () {
    late FakeFirebaseFirestore firestore;
    late FirebaseStorage storage;
    late FirebaseFunctions functions;
    late Reference reference;
    late HttpsCallable callable;
    late DondeQuedaApi subject;

    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
    const current = {
      'week': '2026-W45',
      'status': 'open',
      'area': {'lat': -34.8, 'lng': -55.885, 'zoom': 16},
      'closesOn': '2026-11-05',
      'photoPath': 'donde_queda/r1/2026-W45.jpg',
      'hint': 'cerca de la feria',
    };
    const reveal = {
      'week': '2026-W44',
      'line': 'la puerta verde de la esquina',
      'close': 3,
      'guessed': 5,
    };

    setUpAll(() {
      registerFallbackValue(Uint8List(0));
      registerFallbackValue(SettableMetadata());
      registerFallbackValue(HttpsCallableOptions());
    });

    setUp(() {
      firestore = FakeFirebaseFirestore();
      storage = _MockFirebaseStorage();
      functions = _MockFirebaseFunctions();
      reference = _MockReference();
      callable = _MockHttpsCallable();
      subject = DondeQuedaApi(
        firestore: firestore,
        storage: storage,
        functions: functions,
      );
      when(() => storage.ref(any())).thenReturn(reference);
      when(() => functions.httpsCallable(any(), options: any(named: 'options')))
          .thenReturn(callable);
      when(() => callable.call<Object?>(any<Object?>()))
          .thenAnswer((_) async => _MockHttpsCallableResult());
    });

    group('watchView', () {
      test('reads the game and the reveal', () async {
        await firestore.doc('rondas/r1/views/donde_queda').set({
          'current': current,
          'reveal': reveal,
        });

        final view = await subject.watchView('r1').first;

        final game = view!.current!;
        expect(game.week, equals('2026-W45'));
        expect(game.status, equals('open'));
        expect(game.centre.lat, equals(-34.8));
        expect(game.centre.lng, equals(-55.885));
        expect(game.zoom, equals(16));
        expect(game.closesOn, equals('2026-11-05'));
        expect(game.photoPath, equals('donde_queda/r1/2026-W45.jpg'));
        expect(game.hint, equals('cerca de la feria'));
        final shown = view.reveal!;
        expect(shown.week, equals('2026-W44'));
        expect(shown.line, equals('la puerta verde de la esquina'));
        expect((shown.close, shown.guessed), equals((3, 5)));
      });

      test('reads a view with neither', () async {
        await firestore.doc('rondas/r1/views/donde_queda').set({
          'current': null,
          'reveal': null,
        });

        final view = await subject.watchView('r1').first;

        expect(view!.current, isNull);
        expect(view.reveal, isNull);
      });

      test('is null while there is no view', () async {
        expect(await subject.watchView('r1').first, isNull);
      });

      test('throws on a game or a reveal of another shape', () {
        expect(
          () => DondeQuedaViewDocument.fromJson(const {
            'current': {'week': 'x'},
          }),
          throwsFormatException,
        );
        expect(
          () => DondeQuedaViewDocument.fromJson(const {
            'reveal': {'week': 'x'},
          }),
          throwsFormatException,
        );
      });
    });

    group('watchPlayer', () {
      test("reads the member's own card", () async {
        await firestore.doc('rondas/r1/donde_queda_players/u1').set({
          'week': '2026-W45',
          'asked': true,
          'posted': false,
        });

        final card = await subject.watchPlayer('r1', 'u1').first;

        expect(card!.week, equals('2026-W45'));
        expect((card.asked, card.posted, card.guessed), (true, false, false));
      });

      test('is null without one', () async {
        expect(await subject.watchPlayer('r1', 'u1').first, isNull);
      });

      test('throws without a week', () {
        expect(
          () => DondeQuedaPlayerDocument.fromJson(const {'asked': true}),
          throwsFormatException,
        );
      });
    });

    test('uploadPhoto puts the JPEG under donde_queda_photos/{uid}', () async {
      when(() => reference.putData(any(), any()))
          .thenAnswer((_) => _FakeUploadTask(_MockTaskSnapshot()));

      expect(
        await subject.uploadPhoto(uid: 'u1', photoId: 'p1', jpeg: jpeg),
        equals('donde_queda_photos/u1/p1.jpg'),
      );
      final metadata =
          verify(() => reference.putData(jpeg, captureAny())).captured.single
              as SettableMetadata;
      expect(metadata.contentType, equals('image/jpeg'));
    });

    test('deletePhoto deletes the upload', () async {
      when(() => reference.delete()).thenAnswer((_) async {});

      await subject.deletePhoto('donde_queda_photos/u1/p1.jpg');

      verify(() => storage.ref('donde_queda_photos/u1/p1.jpg')).called(1);
    });

    group('downloadPhoto', () {
      test('returns the bytes', () async {
        when(() => reference.getData()).thenAnswer((_) async => jpeg);

        expect(await subject.downloadPhoto('donde_queda/r1/w.jpg'), jpeg);
      });

      test('throws a $FormatException when there is nothing', () {
        when(() => reference.getData()).thenAnswer((_) async => null);

        expect(
          subject.downloadPhoto('donde_queda/r1/w.jpg'),
          throwsFormatException,
        );
      });
    });

    test('post sends everything, with a long timeout', () async {
      await subject.post(
        rondaId: 'r1',
        week: '2026-W45',
        photoPath: 'donde_queda_photos/u1/p1.jpg',
        line: 'la puerta verde',
        hint: '',
        lat: -34.8,
        lng: -55.885,
      );

      final options =
          verify(
                () => functions.httpsCallable(
                  DondeQuedaApi.postCallable,
                  options: captureAny(named: 'options'),
                ),
              ).captured.single
              as HttpsCallableOptions;
      expect(options.timeout, equals(DondeQuedaApi.postTimeout));
      verify(
        () => callable.call<Object?>({
          'rondaId': 'r1',
          'week': '2026-W45',
          'photoPath': 'donde_queda_photos/u1/p1.jpg',
          'line': 'la puerta verde',
          'hint': '',
          'lat': -34.8,
          'lng': -55.885,
        }),
      ).called(1);
    });

    test('pass and guess call their callables', () async {
      await subject.pass(rondaId: 'r1', week: '2026-W45');
      await subject.guess(rondaId: 'r1', week: '2026-W45', lat: 1, lng: 2);

      verify(() => functions.httpsCallable(DondeQuedaApi.passCallable))
          .called(1);
      verify(
        () => callable.call<Object?>({'rondaId': 'r1', 'week': '2026-W45'}),
      ).called(1);
      verify(
        () => callable.call<Object?>({
          'rondaId': 'r1',
          'week': '2026-W45',
          'lat': 1.0,
          'lng': 2.0,
        }),
      ).called(1);
    });

    for (final (code, details, matcher) in [
      (
        'failed-precondition',
        {'reason': 'houseNumber'},
        isA<DondeQuedaRefusedException>().having(
          (e) => e.reason,
          'reason',
          'houseNumber',
        ),
      ),
      ('failed-precondition', null, isA<NotYourTurnException>()),
      ('permission-denied', null, isA<NotYourTurnException>()),
      ('already-exists', null, isA<AlreadyGuessedException>()),
      ('unavailable', null, isA<FirebaseFunctionsException>()),
    ]) {
      test('maps $code ${details ?? ''}', () {
        when(() => callable.call<Object?>(any<Object?>())).thenThrow(
          FirebaseFunctionsException(
            code: code,
            message: 'no',
            details: details,
          ),
        );

        expect(
          subject.guess(rondaId: 'r', week: 'w', lat: 0, lng: 0),
          throwsA(matcher),
        );
      });
    }

    test('the refusal names its reason', () {
      expect(
        const DondeQuedaRefusedException('empty').toString(),
        contains('empty'),
      );
    });
  });
}
