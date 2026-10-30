import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/my_ronda/cubit/seguimos_cubit.dart';
import 'package:ronda_repository/ronda_repository.dart';

import '../fixtures.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  setUpAll(() {
    registerFallbackValue(SeguimosAnswer.yes);
    registerFallbackValue(SeguimosChoice.join);
  });

  group(SeguimosCubit, () {
    late RondaRepository rondaRepository;
    late StreamController<Seguimos?> questions;

    setUp(() {
      rondaRepository = _MockRondaRepository();
      questions = StreamController<Seguimos?>.broadcast();
      addTearDown(questions.close);
      when(() => rondaRepository.watchSeguimos(MyRondaFixtures.uid))
          .thenAnswer((_) => questions.stream);
      when(
        () => rondaRepository.answerSeguimos(
          rondaId: any(named: 'rondaId'),
          answer: any(named: 'answer'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => rondaRepository.chooseAfterSeguimos(
          rondaId: any(named: 'rondaId'),
          choice: any(named: 'choice'),
        ),
      ).thenAnswer((_) async {});
    });

    SeguimosCubit build() => SeguimosCubit(
      uid: MyRondaFixtures.uid,
      rondaRepository: rondaRepository,
    );

    final open = MyRondaFixtures.seguimos();
    final ready = SeguimosState(
      status: SeguimosCardStatus.ready,
      seguimos: open,
    );

    test('starts loading', () {
      expect(build().state, const SeguimosState());
    });

    group('subscribe', () {
      blocTest<SeguimosCubit, SeguimosState>(
        'shows the question, or nothing before the member is asked',
        build: build,
        act: (cubit) async {
          cubit.subscribe();
          questions.add(open);
          await Future<void>.delayed(Duration.zero);
          questions.add(null);
        },
        expect: () => [
          const SeguimosState(),
          ready,
          const SeguimosState(status: SeguimosCardStatus.none),
        ],
      );

      blocTest<SeguimosCubit, SeguimosState>(
        'fails when it cannot be read',
        build: build,
        act: (cubit) {
          cubit.subscribe();
          questions.addError(const RsvpFailure(RsvpFailureReason.other));
        },
        expect: () => [
          const SeguimosState(),
          const SeguimosState(status: SeguimosCardStatus.failure),
        ],
        errors: () => [isA<RsvpFailure>()],
      );

      blocTest<SeguimosCubit, SeguimosState>(
        'stops changing once the question closes',
        build: build,
        seed: () => ready.copyWith(changing: true),
        act: (cubit) async {
          cubit.subscribe();
          questions.add(
            MyRondaFixtures.seguimos(
              open: false,
              outcome: SeguimosOutcome.season,
            ),
          );
        },
        skip: 1,
        expect: () => [
          isA<SeguimosState>().having((s) => s.changing, 'changing', isFalse),
        ],
      );
    });

    group('answering', () {
      blocTest<SeguimosCubit, SeguimosState>(
        'records Sí',
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.yesTapped(),
        expect: () => [ready.copyWith(saving: true), ready],
        verify: (_) => verify(
          () => rondaRepository.answerSeguimos(
            rondaId: 'r1',
            answer: SeguimosAnswer.yes,
          ),
        ).called(1),
      );

      blocTest<SeguimosCubit, SeguimosState>(
        'records No after Cambiar, and the question hides again',
        build: build,
        seed: () => ready,
        act: (cubit) async {
          cubit.changeTapped();
          await cubit.noTapped();
        },
        expect: () => [
          ready.copyWith(changing: true),
          ready.copyWith(changing: true, saving: true),
          ready,
        ],
        verify: (_) => verify(
          () => rondaRepository.answerSeguimos(
            rondaId: 'r1',
            answer: SeguimosAnswer.no,
          ),
        ).called(1),
      );

      blocTest<SeguimosCubit, SeguimosState>(
        'says so when it fails',
        setUp: () => when(
          () => rondaRepository.answerSeguimos(
            rondaId: any(named: 'rondaId'),
            answer: any(named: 'answer'),
          ),
        ).thenThrow(const RsvpFailure(RsvpFailureReason.other)),
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.yesTapped(),
        expect: () => [
          ready.copyWith(saving: true),
          ready.copyWith(saveFailed: true),
        ],
        errors: () => [isA<RsvpFailure>()],
      );

      blocTest<SeguimosCubit, SeguimosState>(
        'says the question closed when it had',
        setUp: () => when(
          () => rondaRepository.answerSeguimos(
            rondaId: any(named: 'rondaId'),
            answer: any(named: 'answer'),
          ),
        ).thenThrow(const RsvpFailure(RsvpFailureReason.passed)),
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.noTapped(),
        expect: () => [
          ready.copyWith(saving: true),
          ready.copyWith(closed: true),
        ],
        errors: () => [isA<RsvpFailure>()],
      );

      blocTest<SeguimosCubit, SeguimosState>(
        'does nothing before there is a question, or while saving',
        build: build,
        act: (cubit) async {
          await cubit.yesTapped();
          cubit.emit(ready.copyWith(saving: true));
          await cubit.noTapped();
        },
        expect: () => [ready.copyWith(saving: true)],
        verify: (_) => verifyNever(
          () => rondaRepository.answerSeguimos(
            rondaId: any(named: 'rondaId'),
            answer: any(named: 'answer'),
          ),
        ),
      );

      test('drops the result when closed meanwhile', () async {
        final saved = Completer<void>();
        final failed = Completer<void>();
        when(
          () => rondaRepository.answerSeguimos(
            rondaId: any(named: 'rondaId'),
            answer: SeguimosAnswer.yes,
          ),
        ).thenAnswer((_) => saved.future);
        when(
          () => rondaRepository.answerSeguimos(
            rondaId: any(named: 'rondaId'),
            answer: SeguimosAnswer.no,
          ),
        ).thenAnswer((_) => failed.future);
        final first = build()..emit(ready);
        final second = build()..emit(ready);

        final yes = first.yesTapped();
        final no = second.noTapped();
        await first.close();
        await second.close();
        saved.complete();
        failed.completeError(const RsvpFailure(RsvpFailureReason.other));
        await yes;
        await no;

        expect(first.state.saving, isTrue);
        expect(second.state.saving, isTrue);
      });
    });

    group('choosing below the floor', () {
      final closed = SeguimosState(
        status: SeguimosCardStatus.ready,
        seguimos: MyRondaFixtures.seguimos(
          open: false,
          outcome: SeguimosOutcome.didntFill,
        ),
      );

      blocTest<SeguimosCubit, SeguimosState>(
        'records another ronda now',
        build: build,
        seed: () => closed,
        act: (cubit) => cubit.joinTapped(),
        expect: () => [closed.copyWith(saving: true), closed],
        verify: (_) => verify(
          () => rondaRepository.chooseAfterSeguimos(
            rondaId: 'r1',
            choice: SeguimosChoice.join,
          ),
        ).called(1),
      );

      blocTest<SeguimosCubit, SeguimosState>(
        'records waiting two weeks',
        build: build,
        seed: () => closed,
        act: (cubit) => cubit.waitTapped(),
        expect: () => [closed.copyWith(saving: true), closed],
        verify: (_) => verify(
          () => rondaRepository.chooseAfterSeguimos(
            rondaId: 'r1',
            choice: SeguimosChoice.wait,
          ),
        ).called(1),
      );
    });

    group('asks', () {
      test('while open and unanswered, or while changing', () {
        expect(ready.asks, isTrue);
        final answered = SeguimosState(
          status: SeguimosCardStatus.ready,
          seguimos: MyRondaFixtures.seguimos(myAnswer: SeguimosAnswer.yes),
        );
        expect(answered.asks, isFalse);
        expect(answered.copyWith(changing: true).asks, isTrue);
        expect(const SeguimosState().asks, isFalse);
      });
    });
  });
}
