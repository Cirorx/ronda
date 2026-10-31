import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions;

class _MockHttpsCallable extends Mock implements HttpsCallable;

class _MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<Object?>;

void main() {
  group(SmallPlansApi, () {
    late FirebaseFunctions functions;
    late HttpsCallable callable;
    late HttpsCallableResult<Object?> result;
    late SmallPlansApi subject;

    setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

    setUp(() {
      functions = _MockFirebaseFunctions();
      callable = _MockHttpsCallable();
      result = _MockHttpsCallableResult();
      subject = SmallPlansApi(functions: functions);
      when(() => functions.httpsCallable(any(), options: any(named: 'options')))
          .thenReturn(callable);
      when(() => callable.call<Object?>(any<Object?>()))
          .thenAnswer((_) async => result);
    });

    group('suggest', () {
      test('calls suggest_small_plans and reads the suggestions', () async {
        when(() => result.data).thenReturn({
          'suggestions': [
            {
              'id': 'walk-1',
              'kind': 'walk',
              'place': null,
              'date': '2026-11-03',
              'time': '18:00',
              'outdoor': true,
              'dry': true,
            },
          ],
          'pickedBy': 'model',
        });

        final suggestions = await subject.suggest();

        expect(suggestions.map((s) => s.id), equals(['walk-1']));
        final options =
            verify(
                  () => functions.httpsCallable(
                    SmallPlansApi.suggestCallable,
                    options: captureAny(named: 'options'),
                  ),
                ).captured.single
                as HttpsCallableOptions;
        expect(options.timeout, equals(SmallPlansApi.suggestTimeout));
      });

      test('throws a $FormatException for an answer of another shape', () {
        when(() => result.data).thenReturn({'nope': true});

        expect(subject.suggest(), throwsFormatException);
      });
    });

    group('shape', () {
      const plan = {
        'activity': 'Caminar',
        'date': '2026-11-03',
        'time': '19:00',
        'kind': 'walk',
        'outdoor': true,
        'moved': false,
      };

      test('sends the typed words and reads the plan', () async {
        when(() => result.data).thenReturn({'plan': plan});

        final answer = await subject.shape(text: 'caminar');

        expect(answer, isA<SmallPlanShaped>());
        verify(() => callable.call<Object?>({'text': 'caminar'})).called(1);
        final options =
            verify(
                  () => functions.httpsCallable(
                    SmallPlansApi.shapeCallable,
                    options: captureAny(named: 'options'),
                  ),
                ).captured.single
                as HttpsCallableOptions;
        expect(options.timeout, equals(SmallPlansApi.shapeTimeout));
      });

      test('sends the voice note path', () async {
        when(() => result.data).thenReturn({'rejected': 'diet'});

        final answer = await subject.shape(path: 'audio/uid/note.wav');

        expect(answer, equals(const SmallPlanRejected('diet')));
        verify(() => callable.call<Object?>({'path': 'audio/uid/note.wav'}))
            .called(1);
      });

      test('throws an $UnreadableVoiceNoteException when nothing could be '
          'read', () {
        when(() => callable.call<Object?>(any<Object?>())).thenThrow(
          FirebaseFunctionsException(message: 'x', code: 'invalid-argument'),
        );

        expect(
          subject.shape(text: ' '),
          throwsA(isA<UnreadableVoiceNoteException>()),
        );
      });

      test('passes any other failure through', () {
        when(() => callable.call<Object?>(any<Object?>())).thenThrow(
          FirebaseFunctionsException(message: 'x', code: 'unavailable'),
        );

        expect(
          subject.shape(text: 'caminar'),
          throwsA(isA<FirebaseFunctionsException>()),
        );
      });
    });
  });
}
