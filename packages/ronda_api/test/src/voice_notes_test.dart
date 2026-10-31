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

/// An upload that fails with [_error].
class _FailingUploadTask(final FirebaseException _error)
    extends Fake
    implements UploadTask {
  @override
  Future<R> then<R>(
    FutureOr<R> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) => Future<TaskSnapshot>.error(_error).then(onValue, onError: onError);
}

void main() {
  group('$RondaApi voice notes', () {
    late FirebaseStorage storage;
    late FirebaseFunctions functions;
    late Reference reference;
    late HttpsCallable callable;
    late HttpsCallableResult<Object?> result;
    late FakeFirebaseFirestore firestore;
    late RondaApi subject;

    final wav = Uint8List.fromList([82, 73, 70, 70]);

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
      firestore = FakeFirebaseFirestore();
      subject = RondaApi(
        firestore: firestore,
        storage: storage,
        functions: functions,
      );
      when(() => storage.ref(any())).thenReturn(reference);
      when(() => functions.httpsCallable(any(), options: any(named: 'options')))
          .thenReturn(callable);
      when(() => callable.call<Object?>(any<Object?>()))
          .thenAnswer((_) async => result);
    });

    group('readUser', () {
      test('returns null when users/{uid} does not exist', () async {
        expect(await subject.readUser('demo-uid'), isNull);
      });

      test('returns the stored $UserDocument', () async {
        await firestore.collection('users').doc('demo-uid').set({
          'firstName': 'Marta',
        });

        expect(
          await subject.readUser('demo-uid'),
          equals(const UserDocument(firstName: 'Marta')),
        );
      });
    });

    group('uploadVoiceNote', () {
      test(
        'puts the WAV at audio/{uid}/{noteId}.wav and returns the path',
        () async {
          when(() => reference.putData(any(), any()))
              .thenAnswer((_) => _FakeUploadTask(_MockTaskSnapshot()));

          final path = await subject.uploadVoiceNote(
            uid: 'demo-uid',
            noteId: 'note-1',
            wav: wav,
          );

          expect(path, equals('audio/demo-uid/note-1.wav'));
          verify(() => storage.ref('audio/demo-uid/note-1.wav')).called(1);
          final metadata =
              verify(() => reference.putData(wav, captureAny())).captured.single
                  as SettableMetadata;
          expect(metadata.contentType, equals('audio/wav'));
        },
      );

      Future<String> upload() =>
          subject.uploadVoiceNote(uid: 'demo-uid', noteId: 'note-1', wav: wav);

      void failWith(String code) => when(() => reference.putData(any(), any()))
          .thenAnswer(
            (_) => _FailingUploadTask(
              FirebaseException(plugin: 'firebase_storage', code: code),
            ),
          );

      for (final code in ['unauthorized', 'storage/unauthorized']) {
        test('says Storage refused it on $code', () async {
          failWith(code);

          await expectLater(
            upload(),
            throwsA(
              isA<VoiceNoteRefusedException>()
                  .having((e) => e.code, 'code', 'unauthorized')
                  .having(
                    (e) => e.toString(),
                    'toString',
                    'VoiceNoteRefusedException(unauthorized)',
                  ),
            ),
          );
        });
      }

      test('says Storage refused it when signed out', () async {
        failWith('unauthenticated');

        await expectLater(
          upload(),
          throwsA(
            isA<VoiceNoteRefusedException>().having(
              (e) => e.code,
              'code',
              'unauthenticated',
            ),
          ),
        );
      });

      test('says the upload failed on any other code', () async {
        failWith('retry-limit-exceeded');

        await expectLater(
          upload(),
          throwsA(
            isA<VoiceNoteUploadException>()
                .having((e) => e.code, 'code', 'retry-limit-exceeded')
                .having(
                  (e) => e.toString(),
                  'toString',
                  'VoiceNoteUploadException(retry-limit-exceeded)',
                ),
          ),
        );
      });
    });

    group('deleteVoiceNote', () {
      test('deletes the object at the path', () async {
        when(() => reference.delete()).thenAnswer((_) async {});

        await subject.deleteVoiceNote('audio/demo-uid/note-1.wav');

        verify(() => storage.ref('audio/demo-uid/note-1.wav')).called(1);
        verify(() => reference.delete()).called(1);
      });
    });

    group('extract', () {
      test('calls extract with the path and a two-minute timeout', () async {
        when(() => result.data).thenReturn(<Object?, Object?>{});

        await subject.extract('audio/demo-uid/note-1.wav');

        final options =
            verify(
                  () => functions.httpsCallable(
                    'extract',
                    options: captureAny(named: 'options'),
                  ),
                ).captured.single
                as HttpsCallableOptions;
        expect(options.timeout, equals(RondaApi.extractTimeout));
        verify(
          () => callable.call<Object?>({'path': 'audio/demo-uid/note-1.wav'}),
        ).called(1);
      });

      test('returns the fields the callable read', () async {
        when(() => result.data).thenReturn(<Object?, Object?>{
          'firstName': 'Graciela',
          'ageBand': '60-69',
          'barrio': 'solymar-norte',
          'pretexts': ['mate', 'truco'],
          'slots': ['tue-afternoon'],
          'brings': ['termo'],
        });

        expect(
          await subject.extract('audio/demo-uid/note-1.wav'),
          equals(
            const ExtractedFields(
              firstName: 'Graciela',
              ageBand: '60-69',
              barrio: 'solymar-norte',
              pretexts: ['mate', 'truco'],
              slots: ['tue-afternoon'],
              brings: ['termo'],
            ),
          ),
        );
      });

      test('returns no fields when the answer is not a map', () async {
        when(() => result.data).thenReturn(null);

        expect(
          await subject.extract('audio/demo-uid/note-1.wav'),
          equals(const ExtractedFields()),
        );
      });

      test('throws $UnreadableVoiceNoteException on invalid-argument', () {
        when(() => callable.call<Object?>(any<Object?>())).thenThrow(
          FirebaseFunctionsException(message: 'm', code: 'invalid-argument'),
        );

        expect(
          () => subject.extract('audio/demo-uid/note-1.wav'),
          throwsA(isA<UnreadableVoiceNoteException>()),
        );
      });

      test('passes any other callable failure through', () {
        when(() => callable.call<Object?>(any<Object?>())).thenThrow(
          FirebaseFunctionsException(message: 'm', code: 'unavailable'),
        );

        expect(
          () => subject.extract('audio/demo-uid/note-1.wav'),
          throwsA(isA<FirebaseFunctionsException>()),
        );
      });
    });
  });

  group(ExtractedFields, () {
    test('skips empty strings and values of the wrong type', () {
      expect(
        ExtractedFields.fromJson(const {
          'firstName': '',
          'ageBand': 3,
          'pretexts': ['mate', 4],
          'slots': 'tue-afternoon',
        }),
        equals(const ExtractedFields(pretexts: ['mate'])),
      );
    });
  });
}
