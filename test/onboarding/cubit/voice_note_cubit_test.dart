import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:ronda/onboarding/onboarding.dart';

class _MockOnboardingRepository extends Mock implements OnboardingRepository;

const _signup = VoiceSignup(firstName: 'Graciela', pretexts: ['mate']);

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

    setUp(() {
      repository = _MockOnboardingRepository();
      ticks = StreamController<void>.broadcast();
      levels = StreamController<double>.broadcast();
      addTearDown(ticks.close);
      addTearDown(levels.close);
      when(() => repository.startVoiceNote()).thenAnswer((_) async {});
      when(() => repository.discardVoiceNote()).thenAnswer((_) async {});
      when(() => repository.voiceLevels()).thenAnswer((_) => levels.stream);
      when(() => repository.readVoiceNote(any()))
          .thenAnswer((_) async => _signup);
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
      verifyNever(() => repository.startVoiceNote());
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
              when(() => repository.startVoiceNote()).thenThrow(thrown),
          build: buildCubit,
          act: (cubit) => cubit.start(),
          expect: () => [_starting, _failed(failure)],
          verify: (_) => verifyNever(() => repository.voiceLevels()),
        );
      }

      test('throws the note away when closed while starting', () async {
        final started = Completer<void>();
        when(() => repository.startVoiceNote())
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
        when(() => repository.startVoiceNote())
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
          VoiceNoteState(status: VoiceNoteStatus.read, signup: _signup),
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
          verify(() => repository.startVoiceNote()).called(2);
        },
      );
    });

    group('finish', () {
      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'reads the note and stops counting',
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
          VoiceNoteState(status: VoiceNoteStatus.read, signup: _signup),
        ],
        verify: (_) => verify(() => repository.readVoiceNote('demo-uid')),
      );

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'says so when nothing was understood',
        setUp: () =>
            when(() => repository.readVoiceNote(any()))
                .thenThrow(const VoiceNoteNotUnderstoodFailure()),
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
              when(() => repository.readVoiceNote(any())).thenThrow(thrown),
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
        final answer = Completer<VoiceSignup>();
        when(() => repository.readVoiceNote(any()))
            .thenAnswer((_) => answer.future);
        final cubit = buildCubit();
        await cubit.start();
        final finishing = cubit.finish();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.status, equals(VoiceNoteStatus.reading));

        await cubit.close();
        answer.complete(_signup);

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
