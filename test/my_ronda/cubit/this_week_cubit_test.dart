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
            ..emit(
              ready.copyWith(answering: () => RsvpAnswer.no, estaNoSheet: true),
            );
          weeks.add(MyRondaFixtures.week(myAnswer: RsvpAnswer.no));
        },
        skip: 2,
        expect: () => [
          ThisWeekState(
            status: ThisWeekStatus.ready,
            week: MyRondaFixtures.week(myAnswer: RsvpAnswer.no),
            answering: RsvpAnswer.no,
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
        expect: () => [ready.copyWith(answering: () => RsvpAnswer.yes), ready],
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
          ready.copyWith(answering: () => RsvpAnswer.no),
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
        expect: () => [ready.copyWith(answering: () => RsvpAnswer.no), ready],
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
        expect: () => [
          ready.copyWith(changing: true, answering: () => RsvpAnswer.yes),
          ready,
        ],
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
          ready.copyWith(answering: () => RsvpAnswer.no),
          ready.copyWith(answerFailed: true),
        ],
        errors: () => [isA<RsvpFailure>()],
      );

      blocTest<ThisWeekCubit, ThisWeekState>(
        'does nothing without a week or while an answer is on its way',
        build: build,
        act: (cubit) async {
          await cubit.yesTapped();
          cubit.emit(ready.copyWith(answering: () => RsvpAnswer.yes));
          await cubit.noTapped();
        },
        expect: () => [ready.copyWith(answering: () => RsvpAnswer.yes)],
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
        expect: () => [ready.copyWith(answering: () => RsvpAnswer.yes)],
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
        expect: () => [ready.copyWith(answering: () => RsvpAnswer.yes)],
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
      group('what the card asks this member', () {
        final asked = ThisWeekState(
          status: ThisWeekStatus.ready,
          week: MyRondaFixtures.week(
            handoffAsk: MyRondaFixtures.handoffAsk,
            despues: MyRondaFixtures.homeDespues,
          ),
        );

        setUp(() {
          when(
            () => rondaRepository.answerHandoff(
              rondaId: any(named: 'rondaId'),
              week: any(named: 'week'),
              yes: any(named: 'yes'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => rondaRepository.answerDespues(
              rondaId: any(named: 'rondaId'),
              week: any(named: 'week'),
              yes: any(named: 'yes'),
            ),
          ).thenAnswer((_) async {});
        });

        blocTest<ThisWeekCubit, ThisWeekState>(
          '"Sí, abro yo" answers the open "¿Abrís vos?"',
          build: build,
          seed: () => asked,
          act: (cubit) => cubit.handoffAnswered(yes: true),
          expect: () => [asked.copyWith(acting: true), asked],
          verify: (_) => verify(
            () => rondaRepository.answerHandoff(
              rondaId: 'r1',
              week: '2026-W44',
              yes: true,
            ),
          ).called(1),
        );

        blocTest<ThisWeekCubit, ThisWeekState>(
          '"Mejor no" answers the después at their home for the week',
          build: build,
          seed: () => asked,
          act: (cubit) => cubit.homeAnswered(yes: false),
          expect: () => [asked.copyWith(acting: true), asked],
          verify: (_) => verify(
            () => rondaRepository.answerDespues(
              rondaId: 'r1',
              week: '2026-W44',
              yes: false,
            ),
          ).called(1),
        );

        blocTest<ThisWeekCubit, ThisWeekState>(
          'says why an answer was not saved',
          setUp: () => when(
            () => rondaRepository.answerHandoff(
              rondaId: any(named: 'rondaId'),
              week: any(named: 'week'),
              yes: any(named: 'yes'),
            ),
          ).thenThrow(const HostsFailure(HostsFailureReason.passed)),
          build: build,
          seed: () => asked,
          act: (cubit) => cubit.handoffAnswered(yes: true),
          expect: () => [
            asked.copyWith(acting: true),
            asked.copyWith(actionFailure: () => HostsFailureReason.passed),
          ],
          errors: () => [isA<HostsFailure>()],
        );

        blocTest<ThisWeekCubit, ThisWeekState>(
          'does nothing without a question, a week, or while one is on its way',
          build: build,
          act: (cubit) async {
            await cubit.handoffAnswered(yes: true);
            await cubit.homeAnswered(yes: true);
            cubit.emit(ready);
            await cubit.handoffAnswered(yes: true);
            cubit.emit(
              ThisWeekState(
                status: ThisWeekStatus.ready,
                week: MyRondaFixtures.week(withView: false),
              ),
            );
            await cubit.homeAnswered(yes: true);
            cubit.emit(asked.copyWith(acting: true));
            await cubit.handoffAnswered(yes: true);
          },
          skip: 3,
          expect: () => <ThisWeekState>[],
          verify: (_) {
            verifyNever(
              () => rondaRepository.answerHandoff(
                rondaId: any(named: 'rondaId'),
                week: any(named: 'week'),
                yes: any(named: 'yes'),
              ),
            );
            verifyNever(
              () => rondaRepository.answerDespues(
                rondaId: any(named: 'rondaId'),
                week: any(named: 'week'),
                yes: any(named: 'yes'),
              ),
            );
          },
        );

        test('a week arriving keeps an answer on its way', () async {
          final cubit = build()..subscribe();
          addTearDown(cubit.close);
          weeks.add(
            MyRondaFixtures.week(handoffAsk: MyRondaFixtures.handoffAsk),
          );
          await Future<void>.delayed(Duration.zero);
          final pending = Completer<void>();
          when(
            () => rondaRepository.answerHandoff(
              rondaId: any(named: 'rondaId'),
              week: any(named: 'week'),
              yes: any(named: 'yes'),
            ),
          ).thenAnswer((_) => pending.future);

          final answering = cubit.handoffAnswered(yes: true);
          weeks.add(
            MyRondaFixtures.week(handoffAsk: MyRondaFixtures.handoffAsk),
          );
          await Future<void>.delayed(Duration.zero);

          expect(cubit.state.acting, isTrue);
          pending.complete();
          await answering;
          expect(cubit.state.acting, isFalse);
        });

        test('an answer finishing after close emits nothing', () async {
          final pending = Completer<void>();
          when(
            () => rondaRepository.answerDespues(
              rondaId: any(named: 'rondaId'),
              week: any(named: 'week'),
              yes: any(named: 'yes'),
            ),
          ).thenAnswer((_) => pending.future);
          final failing = Completer<void>();
          when(
            () => rondaRepository.answerHandoff(
              rondaId: any(named: 'rondaId'),
              week: any(named: 'week'),
              yes: any(named: 'yes'),
            ),
          ).thenAnswer((_) => failing.future);
          final ok = build()..emit(asked);
          final bad = build()..emit(asked);

          final first = ok.homeAnswered(yes: true);
          final second = bad.handoffAnswered(yes: true);
          await ok.close();
          await bad.close();
          pending.complete();
          failing.completeError(const HostsFailure(HostsFailureReason.other));
          await first;
          await second;

          expect(ok.state.acting, isTrue);
        });
      });
    });
  });
}
