import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/cuaderno/cuaderno.dart';

class _MockCuadernoRepository extends Mock implements CuadernoRepository;

const _uid = 'demo-001';

void main() {
  group(LineVoiceCubit, () {
    late CuadernoRepository repository;
    late StreamController<void> ticks;
    late StreamController<double> levels;
    late StreamController<String> words;

    setUp(() {
      repository = _MockCuadernoRepository();
      ticks = StreamController<void>.broadcast();
      levels = StreamController<double>.broadcast();
      words = StreamController<String>.broadcast();
      addTearDown(words.close);
      addTearDown(ticks.close);
      addTearDown(levels.close);
      when(() => repository.startVoiceNote(_uid)).thenAnswer((_) async {});
      when(() => repository.voiceLevels()).thenAnswer((_) => levels.stream);
      when(() => repository.liveWords()).thenAnswer((_) => words.stream);
      when(() => repository.discardVoiceNote()).thenAnswer((_) async {});
      when(() => repository.readVoiceLine(_uid))
          .thenAnswer((_) async => 'El jacarandá floreció.');
    });

    LineVoiceCubit build() => LineVoiceCubit(
      uid: _uid,
      cuadernoRepository: repository,
      ticks: () => ticks.stream,
    );

    Future<LineVoiceCubit> recording() async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.start();
      return cubit;
    }

    test('waits for the tap: nothing records on its own', () {
      expect(build().state.status, equals(LineVoiceStatus.ready));
      verifyNever(() => repository.startVoiceNote(_uid));
    });

    test("has the app's default clock", () async {
      final cubit = LineVoiceCubit(uid: _uid, cuadernoRepository: repository);
      addTearDown(cubit.close);

      await cubit.start();

      expect(cubit.state.status, equals(LineVoiceStatus.recording));
    });

    group('start', () {
      test('records, counting the seconds and following the voice', () async {
        final cubit = await recording();

        ticks.add(null);
        levels.add(0.4);
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, equals(LineVoiceStatus.recording));
        expect(cubit.state.elapsed, equals(const Duration(seconds: 1)));
        expect(cubit.state.levels, equals([0.4]));
        expect(cubit.state.heard, equals(1));
      });

      test('shows the last bars only', () async {
        final cubit = await recording();

        for (var i = 0; i < LineVoiceCubit.waveformLength + 5; i++) {
          levels.add(i / 100);
        }
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.levels, hasLength(LineVoiceCubit.waveformLength));
        expect(cubit.state.heard, equals(LineVoiceCubit.waveformLength + 5));
      });

      test("ignores a level that can't be read", () async {
        final cubit = await recording();

        levels.addError(Exception('x'));
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, equals(LineVoiceStatus.recording));
      });

      for (final problem in VoiceLineProblem.values) {
        test('says $problem when the repository does', () async {
          when(() => repository.startVoiceNote(_uid))
              .thenThrow(VoiceLineFailure(problem, code: 'c'));
          final cubit = build();
          addTearDown(cubit.close);

          await cubit.start();

          expect(cubit.state.status, equals(LineVoiceStatus.failed));
          expect(cubit.state.problem, equals(problem));
          expect(cubit.state.problemCode, equals('c'));
        });
      }

      test('says the recorder failed when anything else does', () async {
        when(() => repository.startVoiceNote(_uid)).thenThrow(Exception('x'));
        final cubit = build();
        addTearDown(cubit.close);

        await cubit.start();

        expect(cubit.state.problem, equals(VoiceLineProblem.recorderFailed));
      });

      test('throws the note away when the person left meanwhile', () async {
        final starting = Completer<void>();
        when(() => repository.startVoiceNote(_uid))
            .thenAnswer((_) => starting.future);
        final cubit = build();
        final start = cubit.start();
        await cubit.close();
        starting.complete();

        await start;

        verify(() => repository.discardVoiceNote()).called(1);
      });

      test('says nothing of a failure once closed', () async {
        final starting = Completer<void>();
        when(() => repository.startVoiceNote(_uid))
            .thenAnswer((_) => starting.future);
        final cubit = build();
        final start = cubit.start();
        await cubit.close();
        starting.completeError(Exception('x'));

        await expectLater(start, completes);
      });
    });

    group('finish', () {
      test('reads the note and keeps the words', () async {
        final cubit = await recording();

        await cubit.finish();

        expect(cubit.state.status, equals(LineVoiceStatus.read));
        expect(cubit.state.text, equals('El jacarandá floreció.'));
      });

      test('says it is reading meanwhile', () async {
        final reading = Completer<String>();
        when(() => repository.readVoiceLine(_uid))
            .thenAnswer((_) => reading.future);
        final cubit = await recording();

        final finishing = cubit.finish();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.status, equals(LineVoiceStatus.reading));
        reading.complete('uno');
        await finishing;
      });

      test('does nothing unless recording', () async {
        final cubit = build();
        addTearDown(cubit.close);

        await cubit.finish();

        verifyNever(() => repository.readVoiceLine(any()));
      });

      test('stops by itself at the limit', () async {
        final cubit = await recording();

        for (var i = 0; i < LineVoiceCubit.limit.inSeconds; i++) {
          ticks.add(null);
        }
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, equals(LineVoiceStatus.read));
      });

      test('says why it could not be read', () async {
        when(() => repository.readVoiceLine(_uid))
            .thenThrow(const VoiceLineFailure(VoiceLineProblem.notUnderstood));
        final cubit = await recording();

        await cubit.finish();

        expect(cubit.state.problem, equals(VoiceLineProblem.notUnderstood));
      });

      test('says reading failed when anything else does', () async {
        when(() => repository.readVoiceLine(_uid)).thenThrow(Exception('x'));
        final cubit = await recording();

        await cubit.finish();

        expect(cubit.state.problem, equals(VoiceLineProblem.readFailed));
      });

      test('drops the words when the person left meanwhile', () async {
        final reading = Completer<String>();
        when(() => repository.readVoiceLine(_uid))
            .thenAnswer((_) => reading.future);
        final cubit = await recording();
        final finishing = cubit.finish();
        await Future<void>.delayed(Duration.zero);
        await cubit.close();
        reading.complete('uno');

        await finishing;

        expect(cubit.state.text, isNull);
      });
    });

    group('cancel', () {
      test('throws a recording away and waits again', () async {
        final cubit = await recording();

        await cubit.cancel();

        expect(cubit.state, equals(const LineVoiceState()));
        verify(() => repository.discardVoiceNote()).called(1);
      });

      test('dismisses a failure', () async {
        when(() => repository.startVoiceNote(_uid))
            .thenThrow(const VoiceLineFailure(VoiceLineProblem.noMicrophone));
        final cubit = build();
        addTearDown(cubit.close);
        await cubit.start();

        await cubit.cancel();

        expect(cubit.state.status, equals(LineVoiceStatus.ready));
        verifyNever(() => repository.discardVoiceNote());
      });
    });

    test('textTaken waits for the next tap', () async {
      final cubit = await recording();
      await cubit.finish();

      cubit.textTaken();

      expect(cubit.state, equals(const LineVoiceState()));
    });

    group('live words', () {
      Future<void> say(String heard) async {
        words.add(heard);
        await Future<void>.delayed(Duration.zero);
      }

      blocTest<LineVoiceCubit, LineVoiceState>(
        'follow what is said while recording',
        build: build,
        act: (cubit) async {
          await cubit.start();
          await say('El');
          await say('El jacarandá');
        },
        skip: 2,
        expect: () => const [
          LineVoiceState(status: LineVoiceStatus.recording, words: 'El'),
          LineVoiceState(
            status: LineVoiceStatus.recording,
            words: 'El jacarandá',
          ),
        ],
      );

      blocTest<LineVoiceCubit, LineVoiceState>(
        'ignore a failure of the words',
        build: build,
        act: (cubit) async {
          await cubit.start();
          words.addError(Exception('relay'));
          await say('El');
        },
        verify: (cubit) => expect(cubit.state.words, equals('El')),
      );

      blocTest<LineVoiceCubit, LineVoiceState>(
        'are ignored once the note is no longer recording',
        build: build,
        act: (cubit) async {
          await cubit.start();
          await cubit.finish();
          await say('late');
        },
        verify: (cubit) {
          expect(cubit.state.status, equals(LineVoiceStatus.read));
          expect(cubit.state.words, isEmpty);
          expect(words.hasListener, isFalse);
        },
      );

      test('stop being heard when the cubit closes', () async {
        final cubit = await recording();
        expect(words.hasListener, isTrue);

        await cubit.close();

        expect(words.hasListener, isFalse);
      });
    });

    test('closing throws a recording away', () async {
      final cubit = await recording();

      await cubit.close();

      verify(() => repository.discardVoiceNote()).called(1);
    });

    test('closing a cubit that does not record throws nothing away', () async {
      final cubit = build();

      await cubit.close();

      verifyNever(() => repository.discardVoiceNote());
    });
  });
}
