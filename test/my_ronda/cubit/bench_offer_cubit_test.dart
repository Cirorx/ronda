import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/my_ronda/cubit/bench_offer_cubit.dart';
import 'package:ronda_repository/ronda_repository.dart';

import '../fixtures.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

final _now = DateTime(2026, 11, 4, 10);

void main() {
  group(BenchOfferCubit, () {
    late RondaRepository rondaRepository;
    late StreamController<List<BenchOffer>> offers;

    setUp(() {
      rondaRepository = _MockRondaRepository();
      offers = StreamController<List<BenchOffer>>.broadcast();
      addTearDown(offers.close);
      when(() => rondaRepository.watchBenchOffers(MyRondaFixtures.uid))
          .thenAnswer((_) => offers.stream);
      when(
        () => rondaRepository.answerBenchOffer(
          offerId: any(named: 'offerId'),
          take: any(named: 'take'),
        ),
      ).thenAnswer((_) async {});
    });

    BenchOfferCubit build() => BenchOfferCubit(
      uid: MyRondaFixtures.uid,
      rondaRepository: rondaRepository,
      now: () => _now,
    );

    final pending = MyRondaFixtures.offer();
    final ready = BenchOfferState(
      status: BenchOfferCardStatus.ready,
      offer: pending,
    );

    test('starts loading and reads the clock when none is given', () {
      expect(build().state, const BenchOfferState());
      expect(
        BenchOfferCubit(
          uid: MyRondaFixtures.uid,
          rondaRepository: rondaRepository,
        ).state,
        const BenchOfferState(),
      );
    });

    group('current', () {
      test('is the pending offer before its deadline', () {
        expect(BenchOfferCubit.current([pending], _now), pending);
      });

      test('is a taken offer until its meeting day is over', () {
        final taken = MyRondaFixtures.offer(status: BenchOfferStatus.taken);
        final old = MyRondaFixtures.offer(
          status: BenchOfferStatus.taken,
          date: DateTime(2026, 10, 29),
        );

        expect(BenchOfferCubit.current([old, taken], _now), taken);
        expect(
          BenchOfferCubit.current([taken], DateTime(2026, 11, 5, 23)),
          taken,
        );
        expect(BenchOfferCubit.current([taken], DateTime(2026, 11, 6)), null);
      });

      test('is nothing for an offer past its deadline or over', () {
        final late = MyRondaFixtures.offer(deadline: DateTime(2026, 11, 4, 9));
        final over = MyRondaFixtures.offer(status: BenchOfferStatus.over);

        expect(BenchOfferCubit.current([late, over], _now), isNull);
      });
    });

    group('subscribe', () {
      blocTest<BenchOfferCubit, BenchOfferState>(
        'shows the offer that matters, or nothing',
        build: build,
        act: (cubit) async {
          cubit.subscribe();
          offers.add([pending]);
          await Future<void>.delayed(Duration.zero);
          offers.add([]);
        },
        expect: () => [
          const BenchOfferState(),
          ready,
          const BenchOfferState(status: BenchOfferCardStatus.none),
        ],
      );

      blocTest<BenchOfferCubit, BenchOfferState>(
        'says so when the offers cannot be read',
        build: build,
        act: (cubit) {
          cubit.subscribe();
          offers.addError(const RsvpFailure(RsvpFailureReason.other));
        },
        expect: () => [
          const BenchOfferState(),
          const BenchOfferState(status: BenchOfferCardStatus.failure),
        ],
        errors: () => [isA<RsvpFailure>()],
      );
    });

    group('answers', () {
      blocTest<BenchOfferCubit, BenchOfferState>(
        'takes the seat with "Lo tomo"',
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.takeTapped(),
        expect: () => [ready.copyWith(saving: true), ready],
        verify: (_) => verify(
          () => rondaRepository.answerBenchOffer(
            offerId: 'r1_2026-W45_01',
            take: true,
          ),
        ).called(1),
      );

      blocTest<BenchOfferCubit, BenchOfferState>(
        'passes with "Esta vez no"',
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.passTapped(),
        verify: (_) => verify(
          () => rondaRepository.answerBenchOffer(
            offerId: 'r1_2026-W45_01',
            take: false,
          ),
        ).called(1),
      );

      blocTest<BenchOfferCubit, BenchOfferState>(
        'does nothing without an offer or while one answer is on its way',
        build: build,
        seed: () => ready.copyWith(saving: true),
        act: (cubit) async {
          await cubit.takeTapped();
          cubit.emit(const BenchOfferState());
          await cubit.passTapped();
        },
        expect: () => [const BenchOfferState()],
        verify: (_) => verifyNever(
          () => rondaRepository.answerBenchOffer(
            offerId: any(named: 'offerId'),
            take: any(named: 'take'),
          ),
        ),
      );

      blocTest<BenchOfferCubit, BenchOfferState>(
        'says the offer is over when the server says so',
        setUp: () => when(
          () => rondaRepository.answerBenchOffer(
            offerId: any(named: 'offerId'),
            take: any(named: 'take'),
          ),
        ).thenThrow(const RsvpFailure(RsvpFailureReason.passed)),
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.takeTapped(),
        expect: () => [
          ready.copyWith(saving: true),
          ready.copyWith(over: true),
        ],
        errors: () => [isA<RsvpFailure>()],
      );

      blocTest<BenchOfferCubit, BenchOfferState>(
        'says it was not saved on any other failure',
        setUp: () => when(
          () => rondaRepository.answerBenchOffer(
            offerId: any(named: 'offerId'),
            take: any(named: 'take'),
          ),
        ).thenThrow(const RsvpFailure(RsvpFailureReason.other)),
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.passTapped(),
        expect: () => [
          ready.copyWith(saving: true),
          ready.copyWith(saveFailed: true),
        ],
        errors: () => [isA<RsvpFailure>()],
      );

      test('emits nothing once closed while answering', () async {
        final answered = Completer<void>();
        when(
          () => rondaRepository.answerBenchOffer(
            offerId: any(named: 'offerId'),
            take: any(named: 'take'),
          ),
        ).thenAnswer((_) => answered.future);
        final cubit = build()..emit(ready);
        final answering = cubit.takeTapped();
        await cubit.close();
        answered.complete();
        await answering;

        final failing = build()..emit(ready);
        when(
          () => rondaRepository.answerBenchOffer(
            offerId: any(named: 'offerId'),
            take: any(named: 'take'),
          ),
        ).thenAnswer(
          (_) => Future.delayed(
            Duration.zero,
            () => throw const RsvpFailure(RsvpFailureReason.other),
          ),
        );
        final failed = failing.passTapped();
        await failing.close();
        await failed;
        expect(failing.state.saving, isTrue);
      });
    });
  });
}
