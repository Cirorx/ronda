import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/small_plan/cubit/small_plan_choose_cubit.dart';
import 'package:ronda/small_plan/models/models.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

class _MockSmallPlanRepository extends Mock implements SmallPlanRepository;

void main() {
  group(SmallPlanChooseCubit, () {
    late SmallPlanRepository repository;
    late StreamController<double> levels;
    late StreamController<void> ticks;

    final suggestion = SmallPlanSuggestion(
      id: 'walk-1',
      kind: SmallPlanKind.walk,
      at: DateTime(2026, 11, 3, 18),
      outdoor: true,
      place: 'la Plaza',
      dry: true,
    );
    final read = SmallPlanRead(
      plan: SmallPlan(
        kind: SmallPlanKind.walk,
        at: DateTime(2026, 11, 3, 19),
        activity: 'Caminar',
      ),
      dry: true,
    );

    setUp(() {
      repository = _MockSmallPlanRepository();
      levels = StreamController<double>.broadcast();
      ticks = StreamController<void>.broadcast();
      addTearDown(() async {
        await levels.close();
        await ticks.close();
      });
      when(() => repository.suggestions())
          .thenAnswer((_) async => [suggestion]);
      when(() => repository.startVoiceNote()).thenAnswer((_) async {});
      when(() => repository.voiceLevels()).thenAnswer((_) => levels.stream);
      when(() => repository.discardVoiceNote()).thenAnswer((_) async {});
      when(() => repository.shapeVoiceNote('uid'))
          .thenAnswer((_) async => read);
      when(() => repository.shapeText('uid', any()))
          .thenAnswer((_) async => read);
    });

    SmallPlanChooseCubit build() => SmallPlanChooseCubit(
      uid: 'uid',
      smallPlanRepository: repository,
      ticks: () => ticks.stream,
    );

    test('starts on the ideas, loading', () {
      expect(build().state, equals(const SmallPlanChooseState()));
    });

    test('waits a second for each tick by default', () async {
      final cubit = SmallPlanChooseCubit(
        uid: 'uid',
        smallPlanRepository: repository,
      );

      await cubit.recordTapped();
      await cubit.close();

      verify(() => repository.discardVoiceNote()).called(1);
    });

    group('ideas', () {
      blocTest<SmallPlanChooseCubit, SmallPlanChooseState>(
        'brings the three ideas',
        build: build,
        act: (cubit) => cubit.load(),
        expect: () => [
          const SmallPlanChooseState(),
          SmallPlanChooseState(
            ideas: SmallPlanIdeas.ready,
            suggestions: [suggestion],
          ),
        ],
      );

      blocTest<SmallPlanChooseCubit, SmallPlanChooseState>(
        'says so when they could not be had',
        setUp: () => when(
          () => repository.suggestions(),
        ).thenThrow(const SmallPlanFailure(SmallPlanFailureKind.suggestFailed)),
        build: build,
        act: (cubit) => cubit.load(),
        errors: () => [isA<SmallPlanFailure>()],
        expect: () => const [
          SmallPlanChooseState(),
          SmallPlanChooseState(ideas: SmallPlanIdeas.failure),
        ],
      );

      blocTest<SmallPlanChooseCubit, SmallPlanChooseState>(
        'closes with the plan of the idea that was tapped',
        build: build,
        act: (cubit) => cubit.suggestionTapped(suggestion),
        expect: () => [SmallPlanChooseState(chosen: suggestion.plan)],
      );
    });

    group('typing', () {
      blocTest<SmallPlanChooseCubit, SmallPlanChooseState>(
        'goes to saying it and back to the ideas',
        build: build,
        act: (cubit) => cubit
          ..sayTapped()
          ..ideasTapped(),
        expect: () => const [
          SmallPlanChooseState(step: SmallPlanStep.say),
          SmallPlanChooseState(),
        ],
      );

      blocTest<SmallPlanChooseCubit, SmallPlanChooseState>(
        'asks for words before sending an empty field',
        build: build,
        act: (cubit) => cubit.textSubmitted(),
        expect: () => const [SmallPlanChooseState(textTried: true)],
        verify: (_) => verifyNever(() => repository.shapeText(any(), any())),
      );

      blocTest<SmallPlanChooseCubit, SmallPlanChooseState>(
        'shapes what was typed and asks if it is right',
        build: build,
        act: (cubit) async {
          cubit.textChanged('  caminar por la rambla ');
          await cubit.textSubmitted();
        },
        expect: () => [
          const SmallPlanChooseState(
            text: PlanText.dirty('  caminar por la rambla '),
          ),
          const SmallPlanChooseState(
            step: SmallPlanStep.reading,
            text: PlanText.dirty('  caminar por la rambla '),
          ),
          SmallPlanChooseState(
            step: SmallPlanStep.review,
            text: const PlanText.dirty('  caminar por la rambla '),
            read: read,
          ),
        ],
        verify: (_) =>
            verify(() => repository.shapeText('uid', 'caminar por la rambla'))
                .called(1),
      );

      blocTest<SmallPlanChooseCubit, SmallPlanChooseState>(
        'says why a plan was left out, keeping the words',
        setUp: () => when(
          () => repository.shapeText('uid', any()),
        ).thenAnswer((_) async => const SmallPlanDropped(PlanDropReason.diet)),
        build: build,
        act: (cubit) async {
          cubit.textChanged('dieta');
          await cubit.textSubmitted();
        },
        skip: 2,
        expect: () => const [
          SmallPlanChooseState(
            step: SmallPlanStep.say,
            text: PlanText.dirty('dieta'),
            dropped: PlanDropReason.diet,
          ),
        ],
      );

      blocTest<SmallPlanChooseCubit, SmallPlanChooseState>(
        'says what failed',
        setUp: () => when(() => repository.shapeText('uid', any())).thenThrow(
          const SmallPlanFailure(SmallPlanFailureKind.readFailed, code: 'x'),
        ),
        build: build,
        act: (cubit) async {
          cubit.textChanged('caminar');
          await cubit.textSubmitted();
        },
        skip: 2,
        expect: () => const [
          SmallPlanChooseState(
            step: SmallPlanStep.say,
            text: PlanText.dirty('caminar'),
            failure: SmallPlanFailureKind.readFailed,
            failureCode: 'x',
          ),
        ],
      );

      blocTest<SmallPlanChooseCubit, SmallPlanChooseState>(
        'forgets a problem as soon as the person types again',
        build: build,
        seed: () => const SmallPlanChooseState(
          step: SmallPlanStep.say,
          dropped: PlanDropReason.money,
          failure: SmallPlanFailureKind.readFailed,
        ),
        act: (cubit) => cubit.textChanged('x'),
        expect: () => const [
          SmallPlanChooseState(
            step: SmallPlanStep.say,
            text: PlanText.dirty('x'),
          ),
        ],
      );
    });

    group('confirming', () {
      blocTest<SmallPlanChooseCubit, SmallPlanChooseState>(
        'closes with the plan that was read',
        build: build,
        seed: () =>
            SmallPlanChooseState(step: SmallPlanStep.review, read: read),
        act: (cubit) => cubit.confirmTapped(),
        expect: () => [
          SmallPlanChooseState(
            step: SmallPlanStep.review,
            read: read,
            chosen: read.plan,
          ),
        ],
      );

      blocTest<SmallPlanChooseCubit, SmallPlanChooseState>(
        'does nothing with no plan read',
        build: build,
        act: (cubit) => cubit.confirmTapped(),
        expect: () => const <SmallPlanChooseState>[],
      );

      blocTest<SmallPlanChooseCubit, SmallPlanChooseState>(
        'goes back to saying it',
        build: build,
        seed: () =>
            SmallPlanChooseState(step: SmallPlanStep.review, read: read),
        act: (cubit) => cubit.againTapped(),
        expect: () => const [SmallPlanChooseState(step: SmallPlanStep.say)],
      );
    });

    group('by voice', () {
      test('records, follows the voice and reads the note', () async {
        final cubit = build();

        await cubit.recordTapped();
        expect(cubit.state.step, equals(SmallPlanStep.recording));

        levels
          ..add(0.8)
          ..add(0.01);
        ticks.add(null);
        await pumpEventQueue();
        expect(cubit.state.levels, equals([0.8, 0.01]));
        expect(cubit.state.heard, equals(2));
        expect(cubit.state.elapsed, equals(const Duration(seconds: 1)));
        expect(cubit.state.silent, isFalse);

        await cubit.finishTapped();
        expect(cubit.state.step, equals(SmallPlanStep.review));
        expect(cubit.state.read, equals(read));
        await cubit.close();
      });

      test(
        'warns after three quiet seconds, and stops warning at a voice',
        () async {
          final cubit = build();
          await cubit.recordTapped();

          for (var i = 0; i < 3; i++) {
            ticks.add(null);
            await pumpEventQueue();
          }
          expect(cubit.state.silent, isTrue);

          levels.add(0.9);
          await pumpEventQueue();
          expect(cubit.state.silent, isFalse);
          await cubit.close();
        },
      );

      test(
        'shows the last ${SmallPlanChooseCubit.waveformLength} levels',
        () async {
          final cubit = build();
          await cubit.recordTapped();

          for (var i = 0; i < SmallPlanChooseCubit.waveformLength + 5; i++) {
            levels.add(0.5);
            await pumpEventQueue();
          }

          expect(
            cubit.state.levels,
            hasLength(SmallPlanChooseCubit.waveformLength),
          );
          await cubit.close();
        },
      );

      test('reads the note by itself at the limit', () async {
        final cubit = build();
        await cubit.recordTapped();

        for (var i = 0; i < SmallPlanChooseCubit.limit.inSeconds; i++) {
          ticks.add(null);
          await pumpEventQueue();
        }

        expect(cubit.state.step, equals(SmallPlanStep.review));
        await cubit.close();
      });

      test('ignores a level that cannot be read', () async {
        final cubit = build();
        await cubit.recordTapped();

        levels.addError(StateError('no level'));
        await pumpEventQueue();

        expect(cubit.state.step, equals(SmallPlanStep.recording));
        await cubit.close();
      });

      test('throws a recording away on cancel, and on leaving', () async {
        final cubit = build();
        await cubit.recordTapped();

        await cubit.recordingCancelled();
        expect(cubit.state.step, equals(SmallPlanStep.say));

        await cubit.recordTapped();
        await cubit.close();
        verify(() => repository.discardVoiceNote()).called(2);
      });

      test('"Terminé" does nothing when nothing records', () async {
        final cubit = build();

        await cubit.finishTapped();

        expect(cubit.state, equals(const SmallPlanChooseState()));
        verifyNever(() => repository.shapeVoiceNote(any()));
        await cubit.close();
      });

      test('says why the microphone did not start', () async {
        when(() => repository.startVoiceNote()).thenThrow(
          const SmallPlanFailure(SmallPlanFailureKind.microphoneDenied),
        );
        final cubit = build();

        await cubit.recordTapped();

        expect(cubit.state.step, equals(SmallPlanStep.say));
        expect(
          cubit.state.failure,
          equals(SmallPlanFailureKind.microphoneDenied),
        );
        await cubit.close();
      });

      test('throws the note away when the person left while the microphone '
          'started', () async {
        final started = Completer<void>();
        when(() => repository.startVoiceNote())
            .thenAnswer((_) => started.future);
        final cubit = build();

        final recording = cubit.recordTapped();
        await cubit.close();
        started.complete();
        await recording;

        verify(() => repository.discardVoiceNote()).called(greaterThan(0));
      });

      test('says what failed while reading the note', () async {
        when(() => repository.shapeVoiceNote('uid')).thenThrow(
          const SmallPlanFailure(
            SmallPlanFailureKind.uploadFailed,
            code: 'retry-limit-exceeded',
          ),
        );
        final cubit = build();
        await cubit.recordTapped();

        await cubit.finishTapped();

        expect(cubit.state.step, equals(SmallPlanStep.say));
        expect(cubit.state.failure, equals(SmallPlanFailureKind.uploadFailed));
        expect(cubit.state.failureCode, equals('retry-limit-exceeded'));
        await cubit.close();
      });

      test('drops the answer when the person left while it was read', () async {
        final reading = Completer<SmallPlanReading>();
        when(() => repository.shapeVoiceNote('uid'))
            .thenAnswer((_) => reading.future);
        final cubit = build();
        await cubit.recordTapped();

        final finish = cubit.finishTapped();
        await cubit.close();
        reading.complete(read);
        await finish;

        expect(cubit.state.step, equals(SmallPlanStep.reading));
      });

      test('drops a failure when the person left', () async {
        final reading = Completer<SmallPlanReading>();
        when(() => repository.shapeText('uid', any()))
            .thenAnswer((_) => reading.future);
        final cubit = build()..textChanged('caminar');

        final submit = cubit.textSubmitted();
        await cubit.close();
        reading.completeError(
          const SmallPlanFailure(SmallPlanFailureKind.readFailed),
        );
        await submit;

        expect(cubit.state.failure, isNull);
      });

      test('says the ideas could not be had only while it is open', () async {
        final suggestions = Completer<List<SmallPlanSuggestion>>();
        when(() => repository.suggestions())
            .thenAnswer((_) => suggestions.future);
        final cubit = build();

        final loading = cubit.load();
        await cubit.close();
        suggestions.completeError(
          const SmallPlanFailure(SmallPlanFailureKind.suggestFailed),
        );
        await loading;

        expect(cubit.state.ideas, equals(SmallPlanIdeas.loading));
      });
    });
  });
}
