import 'package:bloc_test/bloc_test.dart';
import 'package:donde_queda_repository/donde_queda_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/donde_queda/cubit/donde_queda_guess_cubit.dart';

import '../fixtures.dart';

class _MockDondeQuedaRepository extends Mock implements DondeQuedaRepository;

void main() {
  group(DondeQuedaGuessCubit, () {
    late DondeQuedaRepository repository;

    final game = DondeQuedaFixtures.open();
    final jpeg = DondeQuedaFixtures.jpeg;

    setUpAll(() => registerFallbackValue(DondeQuedaFixtures.pin));

    void watching(DondeQuedaGame? game) => when(
      () => repository.watch(
        rondaId: DondeQuedaFixtures.rondaId,
        uid: DondeQuedaFixtures.uid,
      ),
    ).thenAnswer((_) => Stream.value(DondeQuedaWeek(game: game)));

    setUp(() {
      repository = _MockDondeQuedaRepository();
      watching(game);
      when(() => repository.photo(game.photoPath!))
          .thenAnswer((_) async => jpeg);
    });

    DondeQuedaGuessCubit build() => DondeQuedaGuessCubit(
      uid: DondeQuedaFixtures.uid,
      rondaId: DondeQuedaFixtures.rondaId,
      dondeQuedaRepository: repository,
    );

    final ready = DondeQuedaGuessState(
      status: DondeQuedaGuessStatus.ready,
      game: game,
      photo: jpeg,
    );

    group('started', () {
      blocTest<DondeQuedaGuessCubit, DondeQuedaGuessState>(
        'shows the photo of an open game',
        build: build,
        act: (cubit) => cubit.started(),
        expect: () => [ready],
      );

      blocTest<DondeQuedaGuessCubit, DondeQuedaGuessState>(
        'says the pin is in when they already guessed',
        setUp: () => watching(DondeQuedaFixtures.open(guessed: true)),
        build: build,
        act: (cubit) => cubit.started(),
        expect: () => [
          DondeQuedaGuessState(
            status: DondeQuedaGuessStatus.done,
            game: DondeQuedaFixtures.open(guessed: true),
          ),
        ],
      );

      for (final closed in [
        null,
        DondeQuedaFixtures.game(),
        DondeQuedaFixtures.open(posted: true),
      ]) {
        blocTest<DondeQuedaGuessCubit, DondeQuedaGuessState>(
          'closes with nothing to guess: ${closed?.status} '
          '${closed?.posted}',
          setUp: () => watching(closed),
          build: build,
          act: (cubit) => cubit.started(),
          expect: () => const [
            DondeQuedaGuessState(status: DondeQuedaGuessStatus.closed),
          ],
        );
      }

      blocTest<DondeQuedaGuessCubit, DondeQuedaGuessState>(
        'says when the photo could not be read',
        setUp: () =>
            when(() => repository.photo(any()))
                .thenThrow(const DondeQuedaFailure()),
        build: build,
        act: (cubit) => cubit.started(),
        expect: () => const [
          DondeQuedaGuessState(status: DondeQuedaGuessStatus.failure),
        ],
        errors: () => [isA<DondeQuedaFailure>()],
      );
    });

    group('the pin', () {
      void guessing(Exception? error) =>
          when(
            () => repository.guess(
              rondaId: any(named: 'rondaId'),
              week: any(named: 'week'),
              pin: any(named: 'pin'),
            ),
          ).thenAnswer((_) async {
            if (error != null) throw error;
          });

      final pinned = ready.copyWith(pin: DondeQuedaFixtures.pin);

      blocTest<DondeQuedaGuessCubit, DondeQuedaGuessState>(
        'moves until it is sent, then is in',
        setUp: () => guessing(null),
        build: () => build()..emit(ready),
        act: (cubit) async {
          cubit
            ..pinDropped(DondeQuedaFixtures.centre)
            ..pinDropped(DondeQuedaFixtures.pin);
          await cubit.confirmTapped();
          cubit.pinDropped(DondeQuedaFixtures.centre);
        },
        expect: () => [
          ready.copyWith(pin: DondeQuedaFixtures.centre),
          pinned,
          pinned.copyWith(status: DondeQuedaGuessStatus.sending),
          pinned.copyWith(status: DondeQuedaGuessStatus.done),
        ],
        verify: (_) => verify(
          () => repository.guess(
            rondaId: DondeQuedaFixtures.rondaId,
            week: DondeQuedaFixtures.week,
            pin: DondeQuedaFixtures.pin,
          ),
        ).called(1),
      );

      for (final (error, status) in [
        (const AlreadyGuessedFailure(), DondeQuedaGuessStatus.done),
        (const NotYourTurnFailure(), DondeQuedaGuessStatus.closed),
      ]) {
        blocTest<DondeQuedaGuessCubit, DondeQuedaGuessState>(
          'ends on $status for ${error.runtimeType}',
          setUp: () => guessing(error),
          build: () => build()..emit(pinned),
          act: (cubit) => cubit.confirmTapped(),
          expect: () => [
            pinned.copyWith(status: DondeQuedaGuessStatus.sending),
            pinned.copyWith(status: status),
          ],
        );
      }

      blocTest<DondeQuedaGuessCubit, DondeQuedaGuessState>(
        'stays and says when it failed',
        setUp: () => guessing(const DondeQuedaFailure()),
        build: () => build()..emit(pinned),
        act: (cubit) => cubit.confirmTapped(),
        expect: () => [
          pinned.copyWith(status: DondeQuedaGuessStatus.sending),
          pinned.copyWith(sendFailed: true),
        ],
        errors: () => [isA<DondeQuedaFailure>()],
      );

      blocTest<DondeQuedaGuessCubit, DondeQuedaGuessState>(
        'is not sent before it is dropped',
        build: () => build()..emit(ready),
        act: (cubit) => cubit.confirmTapped(),
        expect: () => const <DondeQuedaGuessState>[],
      );
    });
  });
}
