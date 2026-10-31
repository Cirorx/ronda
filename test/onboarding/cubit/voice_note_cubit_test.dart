import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:ronda/onboarding/onboarding.dart';

class _MockOnboardingRepository extends Mock implements OnboardingRepository;

const _signup = VoiceSignup(firstName: 'Graciela', pretexts: ['mate']);

void main() {
  group(VoiceNoteCubit, () {
    late OnboardingRepository repository;
    late StreamController<void> ticks;

    setUp(() {
      repository = _MockOnboardingRepository();
      ticks = StreamController<void>.broadcast();
      addTearDown(ticks.close);
      when(() => repository.startVoiceNote()).thenAnswer((_) async {});
      when(() => repository.discardVoiceNote()).thenAnswer((_) async {});
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

    test('starts out starting, at zero', () {
      expect(buildCubit().state, equals(const VoiceNoteState()));
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
          VoiceNoteState(status: VoiceNoteStatus.recording),
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

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'says so when the microphone is denied',
        setUp: () =>
            when(() => repository.startVoiceNote())
                .thenThrow(const MicrophoneDeniedFailure()),
        build: buildCubit,
        act: (cubit) => cubit.start(),
        expect: () => const [
          VoiceNoteState(status: VoiceNoteStatus.microphoneDenied),
        ],
      );

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'fails when the recorder does not start',
        setUp: () =>
            when(() => repository.startVoiceNote())
                .thenThrow(const StartVoiceNoteFailure()),
        build: buildCubit,
        act: (cubit) => cubit.start(),
        expect: () => const [VoiceNoteState(status: VoiceNoteStatus.failure)],
      );

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'reads the note on its own at the limit',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await tick(60);
          await Future<void>.delayed(Duration.zero);
        },
        skip: 61,
        expect: () => const [
          VoiceNoteState(
            status: VoiceNoteStatus.reading,
            elapsed: VoiceNoteCubit.limit,
          ),
          VoiceNoteState(status: VoiceNoteStatus.read, signup: _signup),
        ],
      );
    });

    group('restart', () {
      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'throws the note away and starts again from zero',
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await tick();
          await cubit.restart();
          await tick();
        },
        skip: 2,
        expect: () => const [
          VoiceNoteState(),
          VoiceNoteState(status: VoiceNoteStatus.recording),
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
        skip: 2,
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
        skip: 2,
        expect: () => const [
          VoiceNoteState(status: VoiceNoteStatus.notUnderstood),
        ],
      );

      blocTest<VoiceNoteCubit, VoiceNoteState>(
        'fails when reading fails',
        setUp: () =>
            when(() => repository.readVoiceNote(any()))
                .thenThrow(const TermsNotAcceptedFailure()),
        build: buildCubit,
        act: (cubit) async {
          await cubit.start();
          await cubit.finish();
        },
        skip: 2,
        expect: () => const [VoiceNoteState(status: VoiceNoteStatus.failure)],
      );

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
}
