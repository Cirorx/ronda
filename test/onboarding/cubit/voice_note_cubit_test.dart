import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:ronda/onboarding/onboarding.dart';

class _MockOnboardingRepository extends Mock implements OnboardingRepository;

const _signup = VoiceSignup(firstName: 'Graciela', pretexts: ['mate']);

const _heard = 'Soy Graciela, me copa el mate';

/// Every step of a reading that goes well.
const _steps = <VoiceNoteReading>[
  VoiceNoteUploading(),
  VoiceNoteListening(),
  VoiceNoteHeard(_heard),
  VoiceNoteUnderstood(_signup),
];

const _read = VoiceNoteState(
  status: VoiceNoteStatus.read,
  signup: _signup,
  stage: VoiceNoteStage.understanding,
  transcript: _heard,
);

const _recording = VoiceNoteState(status: VoiceNoteStatus.recording);

const _starting = VoiceNoteState(status: VoiceNoteStatus.starting);

VoiceNoteState _failed(VoiceNoteFailure failure, [String? code]) =>
    VoiceNoteState(
      status: VoiceNoteStatus.failed,
      failure: failure,
      failureCode: code,
    );

void main() {
  group(VoiceNoteCubit, () {
    late OnboardingRepository repository;
    late StreamController<void> ticks;
    late StreamController<double> levels;
    late StreamController<String> words;

    setUp(() {
      repository = _MockOnboardingRepository();
      ticks = StreamController<void>.broadcast();
      levels = StreamController<double>.broadcast();
      words = StreamController<String>.broadcast();
      addTearDown(words.close);
      addTearDown(ticks.close);
      addTearDown(levels.close);
      when(() => repository.startVoiceNote('demo-uid'))
          .thenAnswer((_) async {});
      when(() => repository.discardVoiceNote()).thenAnswer((_) async {});
      when(() => repository.voiceLevels()).thenAnswer((_) => levels.stream);
      when(() => repository.liveWords()).thenAnswer((_) => words.stream);
      when(() => repository.readVoiceNote(any()))
          .thenAnswer((_) => Stream.fromIterable(_steps));
    });

    VoiceNoteCubit buildCubit() => VoiceNoteCubit(
      uid: 'demo-uid',
      onboardingRepository: repository,
      ticks: () => ticks.stream,
    );

    Future<void> tick([int times = 1]) async {
      for (var i = 0; i < times; i++) {
        ticks.add(null);
        await Future<void>.delayed(Duration.zero);
      }
    }

    Future<void> hear(List<double> heard) async {
      heard.forEach(levels.add);
      await Future<void>.delayed(Duration.zero);
    }

    test('waits for "Grabar": nothing records on its own', () {
      expect(buildCubit().state, equals(const VoiceNoteState()));
      expect(buildCubit().state.status, equals(VoiceNoteStatus.ready));
      verifyNever(() => repository.startVoiceNote('demo-uid'));
    });

    test('ticks every second by default', () async {
      final cubit = VoiceNoteCubit(
        uid: 'demo-uid',
        onboardingRepository: repository,
      );
      await cubit.start();
      expect(cubit.state.status, equals(VoiceNoteStatus.recording));
      await cubit.close();
    });

    group('start', () {
      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'records and counts the seconds',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await tick(2);
        },
        expect: () => const [
          _starting,
          _recording,
          VoiceNoteState(
            status: VoiceNoteStatus.recording,
            elapsed: Duration(seconds: 1),
          ),
          VoiceNoteState(
            status: VoiceNoteStatus.recording,
            elapsed: Duration(seconds: 2),
          ),
        ],
      );

      final failures = {
        const NoMicrophoneFailure(): VoiceNoteFailure.noMicrophone,
        const MicrophoneDeniedFailure(): VoiceNoteFailure.microphoneDenied,
        const StartVoiceNoteFailure(): VoiceNoteFailure.recorderFailed,
      };
      for (final MapEntry(key: thrown, value: failure) in failures.entries) {
        blocTest<VoiceNoteCubit, VoiceNoteState>(
          'says ${failure.name} on ${thrown.runtimeType}',
          setUp: () =>
              when(() => repository.startVoiceNote('demo-uid'))
                  .thenThrow(thrown),
          build: buildCubit,
          act: (cubit) => cubit.start(),
          expect: () => [_starting, _failed(failure)],
          verify: (_) => verifyNever(() => repository.voiceLevels()),
        );
      }

      test('throws the note away when closed while starting', () async {
        final started = Completer<void>();
        when(() => repository.startVoiceNote('demo-uid'))
            .thenAnswer((_) => started.future);
        final cubit = buildCubit();
        final starting = cubit.start();
        await Future<void>.delayed(Duration.zero);

        await cubit.close();
        started.complete();
        await starting;

        verify(() => repository.discardVoiceNote()).called(1);
        expect(cubit.state.status, equals(VoiceNoteStatus.starting));
      });

      test('says nothing when closed while the start fails', () async {
        final started = Completer<void>();
        when(() => repository.startVoiceNote('demo-uid'))
            .thenAnswer((_) => started.future);
        final cubit = buildCubit();
        final starting = cubit.start();
        await Future<void>.delayed(Duration.zero);

        await cubit.close();
        started.completeError(const StartVoiceNoteFailure());
        await starting;

        expect(cubit.state.status, equals(VoiceNoteStatus.starting));
      });

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'reads the note on its own at the limit',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await tick(60);
          await Future<void>.delayed(Duration.zero);
        },
        skip: 62,
        expect: () => const [
          VoiceNoteState(
            status: VoiceNoteStatus.reading,
            elapsed: VoiceNoteCubit.limit,
          ),
          VoiceNoteState(
            status: VoiceNoteStatus.reading,
            elapsed: VoiceNoteCubit.limit,
            stage: VoiceNoteStage.listening,
          ),
          VoiceNoteState(
            status: VoiceNoteStatus.reading,
            elapsed: VoiceNoteCubit.limit,
            stage: VoiceNoteStage.understanding,
            transcript: _heard,
          ),
          _read,
        ],
      );
    });

    group('levels', () {
      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'follow the voice, newest last',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await hear([0.02, 0.6]);
        },
        skip: 2,
        expect: () => const [
          VoiceNoteState(
            status: VoiceNoteStatus.recording,
            levels: [0.02],
            heard: 1,
          ),
          VoiceNoteState(
            status: VoiceNoteStatus.recording,
            levels: [0.02, 0.6],
            heard: 2,
          ),
        ],
      );

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'keep only the bars the waveform shows',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await hear([1, ...List.filled(VoiceNoteCubit.waveformLength, 0.5)]);
        },
        verify: (cubit) {
          expect(
            cubit.state.levels,
            equals(List.filled(VoiceNoteCubit.waveformLength, 0.5)),
          );
          expect(cubit.state.heard, equals(VoiceNoteCubit.waveformLength + 1));
        },
      );

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'ignore a level that cannot be read',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          levels.addError(Exception('no level'));
          await hear([0.4]);
        },
        verify: (cubit) => expect(cubit.state.levels, equals([0.4])),
      );

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'say nothing is heard after 3 s of silence (a quiet room)',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          for (var second = 0; second < 3; second++) {
            await hear([0.01, 0.03, 0.02]);
            expect(cubit.state.silent, isFalse);
            await tick();
          }
        },
        verify: (cubit) => expect(cubit.state.silent, isTrue),
      );

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'say nothing is heard after 3 s from a dead microphone',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await hear(List.filled(25, 0));
          await tick(3);
        },
        verify: (cubit) {
          expect(cubit.state.silent, isTrue);
          expect(cubit.state.levels, everyElement(0));
        },
      );

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'never say so while the person speaks',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          for (var second = 0; second < 5; second++) {
            await hear([0.01, 0.7, 0.4]);
            await tick();
          }
        },
        verify: (cubit) => expect(cubit.state.silent, isFalse),
      );

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'clear the warning as soon as the voice comes back',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await tick(3);
          expect(cubit.state.silent, isTrue);
          await hear([0.5]);
        },
        verify: (cubit) => expect(cubit.state.silent, isFalse),
      );

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'stop once the note is read',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await cubit.finish();
          await hear([0.5]);
        },
        verify: (cubit) => expect(cubit.state.levels, isEmpty),
      );
    });

    group('live words', () {
      Future<void> say(String heard) async {
        words.add(heard);
        await Future<void>.delayed(Duration.zero);
      }

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'follow what is said while recording, revised as it goes',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await say('Hola');
          await say('Hola, soy Marta');
        },
        skip: 2,
        expect: () => const [
          VoiceNoteState(status: VoiceNoteStatus.recording, words: 'Hola'),
          VoiceNoteState(
            status: VoiceNoteStatus.recording,
            words: 'Hola, soy Marta',
          ),
        ],
      );

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'ignore a failure of the words',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          words.addError(Exception('relay'));
          await say('Hola');
        },
        verify: (cubit) => expect(cubit.state.words, equals('Hola')),
      );

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'are kept while the note is read',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await say('Hola');
          await cubit.finish();
        },
        skip: 3,
        expect: () => const [
          VoiceNoteState(status: VoiceNoteStatus.reading, words: 'Hola'),
          VoiceNoteState(
            status: VoiceNoteStatus.reading,
            words: 'Hola',
            stage: VoiceNoteStage.listening,
          ),
          VoiceNoteState(
            status: VoiceNoteStatus.reading,
            words: 'Hola',
            stage: VoiceNoteStage.understanding,
            transcript: _heard,
          ),
          _read,
        ],
      );

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'are ignored once the note is no longer recording',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await cubit.finish();
          await say('late');
        },
        verify: (cubit) {
          expect(cubit.state.status, equals(VoiceNoteStatus.read));
          expect(cubit.state.words, isEmpty);
          expect(words.hasListener, isFalse);
        },
      );

      test('stop being heard when the cubit closes', () async {
        final cubit = buildCubit();
        await cubit.start();
        expect(words.hasListener, isTrue);

        await cubit.close();

        expect(words.hasListener, isFalse);
      });
    });

    group('restart', () {
      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'throws the note away and starts again from zero',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await tick();
          await hear([0.5]);
          await cubit.restart();
          await tick();
        },
        skip: 4,
        expect: () => const [
          _starting,
          _recording,
          VoiceNoteState(
            status: VoiceNoteStatus.recording,
            elapsed: Duration(seconds: 1),
          ),
        ],
        verify: (_) {
          // Once for the restart, once more as blocTest closes the cubit
          // with the new note still recording.
          verify(() => repository.discardVoiceNote()).called(2);
          verify(() => repository.startVoiceNote('demo-uid')).called(2);
        },
      );
    });

    group('finish', () {
      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'reads the note step by step, the words first, and stops counting',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await tick();
          await cubit.finish();
          await tick();
        },
        skip: 3,
        expect: () => const [
          VoiceNoteState(
            status: VoiceNoteStatus.reading,
            elapsed: Duration(seconds: 1),
          ),
          VoiceNoteState(
            status: VoiceNoteStatus.reading,
            elapsed: Duration(seconds: 1),
            stage: VoiceNoteStage.listening,
          ),
          VoiceNoteState(
            status: VoiceNoteStatus.reading,
            elapsed: Duration(seconds: 1),
            stage: VoiceNoteStage.understanding,
            transcript: _heard,
          ),
          _read,
        ],
        verify: (_) => verify(() => repository.readVoiceNote('demo-uid')),
      );

      test('counts the seconds it waits, then stops', () async {
        final steps = StreamController<VoiceNoteReading>();
        addTearDown(steps.close);
        when(() => repository.readVoiceNote(any()))
            .thenAnswer((_) => steps.stream);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.start();
        final finishing = cubit.finish();
        await Future<void>.delayed(Duration.zero);

        await tick(4);
        expect(cubit.state.waited, equals(const Duration(seconds: 4)));
        steps
          ..add(const VoiceNoteHeard(_heard))
          ..add(const VoiceNoteUnderstood(_signup));
        await finishing;
        await tick();

        expect(cubit.state.status, equals(VoiceNoteStatus.read));
        expect(cubit.state.transcript, equals(_heard));
      });

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'says readFailed when the reading ends without an answer',
        setUp: () =>
            when(() => repository.readVoiceNote(any()))
                .thenAnswer((_) => Stream.fromIterable(_steps.take(3))),
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await cubit.finish();
        },
        skip: 5,
        expect: () => [_failed(VoiceNoteFailure.readFailed)],
      );

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'drops the words it showed when a later step fails',
        setUp: () =>
            when(() => repository.readVoiceNote(any())).thenAnswer((_) async* {
              yield* Stream.fromIterable(_steps.take(3));
              throw const VoiceNoteNotUnderstoodFailure();
            }),
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await cubit.finish();
        },
        skip: 5,
        expect: () => const [
          VoiceNoteState(status: VoiceNoteStatus.notUnderstood),
        ],
      );

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'says so when nothing was understood',
        setUp: () => when(() => repository.readVoiceNote(any())).thenAnswer(
          (_) => Stream.error(const VoiceNoteNotUnderstoodFailure()),
        ),
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await cubit.finish();
        },
        skip: 3,
        expect: () => const [
          VoiceNoteState(status: VoiceNoteStatus.notUnderstood),
        ],
      );

      final failures = <Exception, VoiceNoteState>{
        const RecordVoiceNoteFailure(): _failed(
          VoiceNoteFailure.recorderFailed,
        ),
        const TermsNotAcceptedFailure(): _failed(VoiceNoteFailure.termsMissing),
        const UploadVoiceNoteFailure(refused: true, code: 'unauthorized'):
            _failed(VoiceNoteFailure.uploadRefused, 'unauthorized'),
        const UploadVoiceNoteFailure(code: 'retry-limit-exceeded'): _failed(
          VoiceNoteFailure.uploadFailed,
          'retry-limit-exceeded',
        ),
        const ReadVoiceNoteFailure(): _failed(VoiceNoteFailure.readFailed),
      };
      for (final MapEntry(key: thrown, value: failed) in failures.entries) {
        blocTest<VoiceNoteCubit, VoiceNoteState>(
          'says ${failed.failure!.name} on ${thrown.runtimeType}',
          setUp: () =>
              when(() => repository.readVoiceNote(any()))
                  .thenAnswer((_) => Stream.error(thrown)),
          build: buildCubit,
          act: (cubit) async {
            await cubit.start();
            await cubit.finish();
          },
          skip: 3,
          expect: () => [failed],
        );
      }

      test('drops the answer once closed while reading (Cancelar)', () async {
        final answer = StreamController<VoiceNoteReading>();
        when(() => repository.readVoiceNote(any()))
            .thenAnswer((_) => answer.stream);
        final cubit = buildCubit();
        await cubit.start();
        final finishing = cubit.finish();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.status, equals(VoiceNoteStatus.reading));

        await cubit.close();
        answer.add(const VoiceNoteUnderstood(_signup));
        unawaited(answer.close());

        await expectLater(finishing, completes);
        expect(cubit.state.status, equals(VoiceNoteStatus.reading));
      });

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'does nothing unless recording',
        build: buildCubit,
        act: (cubit) => cubit.finish(),
        expect: () => const <VoiceNoteState>[],
        verify: (_) => verifyNever(() => repository.readVoiceNote(any())),
      );
    });

    group('close', () {
      test('throws away a note still recording', () async {
        final cubit = buildCubit();
        await cubit.start();

        await cubit.close();

        verify(() => repository.discardVoiceNote()).called(1);
      });

      test('leaves a read note alone', () async {
        final cubit = buildCubit();
        await cubit.start();
        await cubit.finish();

        await cubit.close();

        verifyNever(() => repository.discardVoiceNote());
      });
    });
  });

  group(VoiceNoteState, () {
    test('copyWith keeps what it is not given', () {
      const state = VoiceNoteState(
        status: VoiceNoteStatus.failed,
        signup: _signup,
        failure: VoiceNoteFailure.uploadFailed,
        failureCode: 'x',
        levels: [0.5],
        heard: 3,
        silent: true,
        elapsed: Duration(seconds: 4),
      );

      expect(state.copyWith(), equals(state));
    });
  });
}
