import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions;

class _MockHttpsCallable extends Mock implements HttpsCallable;

class _MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<Object?>;

void main() {
  group(CuadernoApi, () {
    late FirebaseFunctions functions;
    late HttpsCallable callable;
    late HttpsCallableResult<Object?> result;
    late CuadernoApi subject;

    setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

    setUp(() {
      functions = _MockFirebaseFunctions();
      callable = _MockHttpsCallable();
      result = _MockHttpsCallableResult();
      subject = CuadernoApi(functions: functions);
      when(() => functions.httpsCallable(any(), options: any(named: 'options')))
          .thenReturn(callable);
      when(() => callable.call<Object?>(any<Object?>()))
          .thenAnswer((_) async => result);
    });

    group('readLine', () {
      const path = 'audio/demo-uid/note-1.wav';

      test('calls read_line on the note and returns the words', () async {
        when(() => result.data)
            .thenReturn({'text': '  El jacarandá floreció. '});

        expect(await subject.readLine(path), equals('El jacarandá floreció.'));
        verify(
          () => functions.httpsCallable(
            'read_line',
            options: any(named: 'options'),
          ),
        ).called(1);
        verify(() => callable.call<Object?>({'path': path})).called(1);
      });

      for (final data in <Object?>[
        null,
        <String, Object?>{},
        {'text': '   '},
      ]) {
        test('is unreadable when the answer is $data', () {
          when(() => result.data).thenReturn(data);

          expect(
            subject.readLine(path),
            throwsA(isA<UnreadableVoiceNoteException>()),
          );
        });
      }

      test('is unreadable when the callable refuses the note', () {
        when(() => callable.call<Object?>(any<Object?>())).thenThrow(
          FirebaseFunctionsException(message: 'x', code: 'invalid-argument'),
        );

        expect(
          subject.readLine(path),
          throwsA(isA<UnreadableVoiceNoteException>()),
        );
      });

      test('passes any other failure through', () {
        when(() => callable.call<Object?>(any<Object?>())).thenThrow(
          FirebaseFunctionsException(message: 'x', code: 'unavailable'),
        );

        expect(
          subject.readLine(path),
          throwsA(isA<FirebaseFunctionsException>()),
        );
      });
    });

    group('makePostcard', () {
      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

      test('sends the lines and returns the image from the answer', () async {
        when(
          () => result.data,
        ).thenReturn({'image': base64Encode(jpeg), 'mimeType': 'image/jpeg'});

        expect(await subject.makePostcard(['uno', 'dos']), equals(jpeg));
        verify(
          () => functions.httpsCallable(
            'make_postcard',
            options: any(named: 'options'),
          ),
        ).called(1);
        verify(
          () => callable.call<Object?>({
            'lines': ['uno', 'dos'],
          }),
        ).called(1);
      });

      test('has no way to store anything: it holds only the callables', () {
        // The whole of CuadernoApi's constructor is the functions client.
        expect(subject.functions, same(functions));
      });

      test('fails on an answer with no image', () {
        when(() => result.data).thenReturn(<String, Object?>{});

        expect(subject.makePostcard(['uno']), throwsA(isA<FormatException>()));
      });

      test('says when there is nothing to draw', () {
        when(() => callable.call<Object?>(any<Object?>())).thenThrow(
          FirebaseFunctionsException(message: 'x', code: 'failed-precondition'),
        );

        expect(
          subject.makePostcard(['uno']),
          throwsA(isA<NothingToDrawException>()),
        );
      });

      test('passes any other failure through', () {
        when(() => callable.call<Object?>(any<Object?>())).thenThrow(
          FirebaseFunctionsException(message: 'x', code: 'unavailable'),
        );

        expect(
          subject.makePostcard(['uno']),
          throwsA(isA<FirebaseFunctionsException>()),
        );
      });
    });
  });
}
