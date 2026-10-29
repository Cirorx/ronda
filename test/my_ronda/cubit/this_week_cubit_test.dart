import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/my_ronda/cubit/this_week_cubit.dart';
import 'package:ronda_repository/ronda_repository.dart';

import '../fixtures.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  setUpAll(() => registerFallbackValue(RsvpAnswer.yes));

  group(ThisWeekCubit, () {
    late RondaRepository rondaRepository;
    late StreamController<ThisWeek?> weeks;

    setUp(() {
      rondaRepository = _MockRondaRepository();
      weeks = StreamController<ThisWeek?>.broadcast();
      addTearDown(weeks.close);
      when(() => rondaRepository.watchThisWeek(MyRondaFixtures.uid))
          .thenAnswer((_) => weeks.stream);
      when(
        () => rondaRepository.answerRsvp(
          rondaId: any(named: 'rondaId'),
          answer: any(named: 'answer'),
          pause: any(named: 'pause'),
        ),
      ).thenAnswer((_) async {});
    });

    ThisWeekCubit build() => ThisWeekCubit(
      uid: MyRondaFixtures.uid,
      rondaRepository: rondaRepository,
    );

    final week = MyRondaFixtures.week();
    final ready = ThisWeekState(status: ThisWeekStatus.ready, week: week);

    test('starts loading and asks nothing yet', () {
      expect(build().state, const ThisWeekState());
    });

    group('subscribe', () {
      blocTest<ThisWeekCubit, ThisWeekState>(
        'shows the week, or no group before one exists',
        build: build,
        act: (cubit) async {
          cubit.subscribe();
          weeks.add(week);
          await Future<void>.delayed(Duration.zero);
          weeks.add(null);
        },
        expect: () => [
          const ThisWeekState(),
          ready,
          const ThisWeekState(status: ThisWeekStatus.noGroup),
        ],
      );

      blocTest<ThisWeekCubit, ThisWeekState>(
        'fails when the ronda cannot be read',
        build: build,
        act: (cubit) {
          cubit.subscribe();
          weeks.addError(const RsvpFailure(RsvpFailureReason.other));
        },
        expect: () => [
          const ThisWeekState(),
          const ThisWeekState(status: ThisWeekStatus.failure),
        ],
        errors: () => [isA<RsvpFailure>()],
      );

      blocTest<ThisWeekCubit, ThisWeekState>(
        'keeps an answer on its way when the week changes',
        build: build,
        act: (cubit) async {
          cubit
            ..subscribe()
            ..emit(ready.copyWith(answering: true, estaNoSheet: true));
          weeks.add(MyRondaFixtures.week(myAnswer: RsvpAnswer.no));
        },
        skip: 2,
        expect: () => [
          ThisWeekState(
            status: ThisWeekStatus.ready,
            week: MyRondaFixtures.week(myAnswer: RsvpAnswer.no),
            answering: true,
            estaNoSheet: true,
          ),
        ],
      );
    });

    group('answers', () {
      blocTest<ThisWeekCubit, ThisWeekState>(
        'Voy records yes',
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.yesTapped(),
        expect: () => [ready.copyWith(answering: true), ready],
        verify: (_) => verify(
          () =>
              rondaRepository.answerRsvp(rondaId: 'r1', answer: RsvpAnswer.yes),
        ).called(1),
      );

      blocTest<ThisWeekCubit, ThisWeekState>(
        'Esta no records no and opens the sheet',
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.noTapped(),
        expect: () => [
          ready.copyWith(answering: true),
          ready.copyWith(estaNoSheet: true),
        ],
        verify: (_) => verify(
          () =>
              rondaRepository.answerRsvp(rondaId: 'r1', answer: RsvpAnswer.no),
        ).called(1),
      );

      blocTest<ThisWeekCubit, ThisWeekState>(
        'Pausar 2 semanas records no with the pause',
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.pauseTapped(),
        expect: () => [ready.copyWith(answering: true), ready],
        verify: (_) => verify(
          () => rondaRepository.answerRsvp(
            rondaId: 'r1',
            answer: RsvpAnswer.no,
            pause: true,
          ),
        ).called(1),
      );

      blocTest<ThisWeekCubit, ThisWeekState>(
        'an answer ends "Cambiar mi respuesta"',
        build: build,
        seed: () => ready.copyWith(changing: true),
        act: (cubit) => cubit.yesTapped(),
        expect: () => [ready.copyWith(changing: true, answering: true), ready],
      );

      blocTest<ThisWeekCubit, ThisWeekState>(
        'a failed answer leaves the card and says so',
        setUp: () => when(
          () => rondaRepository.answerRsvp(
            rondaId: any(named: 'rondaId'),
            answer: any(named: 'answer'),
            pause: any(named: 'pause'),
          ),
        ).thenThrow(const RsvpFailure(RsvpFailureReason.other)),
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.noTapped(),
        expect: () => [
          ready.copyWith(answering: true),
          ready.copyWith(answerFailed: true),
        ],
        errors: () => [isA<RsvpFailure>()],
      );

      blocTest<ThisWeekCubit, ThisWeekState>(
        'does nothing without a week or while an answer is on its way',
        build: build,
        act: (cubit) async {
          await cubit.yesTapped();
          cubit.emit(ready.copyWith(answering: true));
          await cubit.noTapped();
        },
        expect: () => [ready.copyWith(answering: true)],
        verify: (_) => verifyNever(
          () => rondaRepository.answerRsvp(
            rondaId: any(named: 'rondaId'),
            answer: any(named: 'answer'),
            pause: any(named: 'pause'),
          ),
        ),
      );

      blocTest<ThisWeekCubit, ThisWeekState>(
        'emits nothing after it closes',
        setUp: () {
          final answered = Completer<void>();
          when(
            () => rondaRepository.answerRsvp(
              rondaId: any(named: 'rondaId'),
              answer: any(named: 'answer'),
              pause: any(named: 'pause'),
            ),
          ).thenAnswer((_) => answered.future);
          Future<void>.delayed(Duration.zero, answered.complete);
        },
        build: build,
        seed: () => ready,
        act: (cubit) {
          unawaited(cubit.yesTapped());
          return cubit.close();
        },
        expect: () => [ready.copyWith(answering: true)],
      );

      blocTest<ThisWeekCubit, ThisWeekState>(
        'emits no failure after it closes',
        setUp: () {
          final answered = Completer<void>();
          when(
            () => rondaRepository.answerRsvp(
              rondaId: any(named: 'rondaId'),
              answer: any(named: 'answer'),
              pause: any(named: 'pause'),
            ),
          ).thenAnswer((_) => answered.future);
          Future<void>.delayed(
            Duration.zero,
            () => answered.completeError(
              const RsvpFailure(RsvpFailureReason.other),
            ),
          );
        },
        build: build,
        seed: () => ready,
        act: (cubit) {
          unawaited(cubit.yesTapped());
          return cubit.close();
        },
        expect: () => [ready.copyWith(answering: true)],
      );
    });

    blocTest<ThisWeekCubit, ThisWeekState>(
      'Cambiar mi respuesta asks again, and the sheet closes',
      build: build,
      seed: () => ready.copyWith(estaNoSheet: true),
      act: (cubit) => cubit
        ..changeTapped()
        ..sheetClosed(),
      expect: () => [
        ready.copyWith(estaNoSheet: true, changing: true),
        ready.copyWith(changing: true),
      ],
    );

    group('asks', () {
      test('while unanswered or changing, not after an answer or a pause', () {
        expect(ready.asks, isTrue);
        final answered = ThisWeekState(
          status: ThisWeekStatus.ready,
          week: MyRondaFixtures.week(myAnswer: RsvpAnswer.yes),
        );
        expect(answered.asks, isFalse);
        expect(answered.copyWith(changing: true).asks, isTrue);
        final paused = ThisWeekState(
          status: ThisWeekStatus.ready,
          week: MyRondaFixtures.week(pausedUntil: DateTime(2026, 11, 14)),
        );
        expect(paused.asks, isFalse);
      });
    });
  });
}
