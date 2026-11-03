import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/app/app.dart';

class _MockProfileRepository extends Mock implements ProfileRepository;

class _MockNeedsRepository extends Mock implements NeedsRepository;

// Invented demo data.
final _profile = Profile(
  firstName: 'Marta',
  ageBand: AgeBand.sixties,
  barrio: Barrio.palermo,
  pretexts: const {Pretext.mate},
  slots: {const Slot(SlotDay.wednesday, SlotBand.evening)},
  brings: const {Bring.termo},
);

const _seat = PublishedSeat(
  seatId: 'palermo_mate_wed-evening',
  blocksFrom: {'palermo': 0},
  hasStairs: false,
  endsAfterDark: true,
  needsCar: false,
);

void main() {
  group(SeatRefreshCubit, () {
    late ProfileRepository profileRepository;
    late NeedsRepository needsRepository;

    setUpAll(() => registerFallbackValue(Needs.none));

    setUp(() {
      profileRepository = _MockProfileRepository();
      needsRepository = _MockNeedsRepository();
      when(profileRepository.publishedSeatCatalogVersion)
          .thenAnswer((_) async => 'v2');
      when(() => profileRepository.seatCatalogWorkedOut('demo-uid'))
          .thenAnswer((_) async => 'v1');
      when(() => profileRepository.watchProfile('demo-uid'))
          .thenAnswer((_) => Stream.value(_profile));
      when(profileRepository.publishedSeats)
          .thenAnswer((_) async => const [_seat]);
      when(
        () => profileRepository.saveEligibleSeatIds(
          uid: any(named: 'uid'),
          seatIds: any(named: 'seatIds'),
        ),
      ).thenAnswer((_) async {});
      when(() => profileRepository.holdSeatCatalogWorkedOut(any(), any()))
          .thenAnswer((_) async {});
      when(needsRepository.read).thenAnswer((_) async => Needs.none);
      when(() => needsRepository.eligibleSeatIds(any(), any())).thenAnswer(
        (invocation) => [
          for (final seat
              in invocation.positionalArguments[1] as List<SeatFacts>)
            seat.seatId,
        ],
      );
    });

    SeatRefreshCubit build() => SeatRefreshCubit(
      profileRepository: profileRepository,
      needsRepository: needsRepository,
    );

    test('starts idle', () {
      expect(build().state, equals(SeatRefreshStatus.idle));
    });

    blocTest<SeatRefreshCubit, SeatRefreshStatus>(
      'works the seats out again when the server published another '
      'catalogue',
      build: build,
      act: (cubit) => cubit.refresh('demo-uid'),
      expect: () => [SeatRefreshStatus.working, SeatRefreshStatus.refreshed],
      verify: (_) {
        verify(
          () => profileRepository.saveEligibleSeatIds(
            uid: 'demo-uid',
            seatIds: const ['palermo_mate_wed-evening'],
          ),
        ).called(1);
        verify(
          () => profileRepository.holdSeatCatalogWorkedOut('demo-uid', 'v2'),
        ).called(1);
      },
    );

    blocTest<SeatRefreshCubit, SeatRefreshStatus>(
      'leaves them when they were worked out against the published one',
      setUp: () =>
          when(() => profileRepository.seatCatalogWorkedOut('demo-uid'))
              .thenAnswer((_) async => 'v2'),
      build: build,
      act: (cubit) => cubit.refresh('demo-uid'),
      expect: () => [SeatRefreshStatus.working, SeatRefreshStatus.upToDate],
      verify: (_) => verifyNever(profileRepository.publishedSeats),
    );

    blocTest<SeatRefreshCubit, SeatRefreshStatus>(
      'leaves them when no catalogue is published yet',
      setUp: () =>
          when(profileRepository.publishedSeatCatalogVersion)
              .thenAnswer((_) async => null),
      build: build,
      act: (cubit) => cubit.refresh('demo-uid'),
      expect: () => [SeatRefreshStatus.working, SeatRefreshStatus.upToDate],
    );

    blocTest<SeatRefreshCubit, SeatRefreshStatus>(
      'does nothing for someone without a profile',
      setUp: () =>
          when(() => profileRepository.watchProfile('demo-uid'))
              .thenAnswer((_) => Stream.value(null)),
      build: build,
      act: (cubit) => cubit.refresh('demo-uid'),
      expect: () => [SeatRefreshStatus.working, SeatRefreshStatus.idle],
      verify: (_) => verifyNever(profileRepository.publishedSeats),
    );

    blocTest<SeatRefreshCubit, SeatRefreshStatus>(
      'reports a failed read and fails quietly',
      setUp: () =>
          when(profileRepository.publishedSeatCatalogVersion)
              .thenThrow(const ReadPublishedSeatsFailure()),
      build: build,
      act: (cubit) => cubit.refresh('demo-uid'),
      expect: () => [SeatRefreshStatus.working, SeatRefreshStatus.failed],
      errors: () => [isA<ReadPublishedSeatsFailure>()],
    );

    test('runs once while a refresh is under way', () async {
      final version = Completer<String?>();
      when(profileRepository.publishedSeatCatalogVersion)
          .thenAnswer((_) => version.future);
      final cubit = build();

      final first = cubit.refresh('demo-uid');
      await cubit.refresh('demo-uid');
      version.complete('v2');
      await first;

      verify(
        () => profileRepository.saveEligibleSeatIds(
          uid: 'demo-uid',
          seatIds: any(named: 'seatIds'),
        ),
      ).called(1);
      expect(cubit.state, equals(SeatRefreshStatus.refreshed));
      await cubit.close();
    });

    test('emits nothing once closed', () async {
      final version = Completer<String?>();
      when(profileRepository.publishedSeatCatalogVersion)
          .thenAnswer((_) => version.future);
      final cubit = build();

      final refresh = cubit.refresh('demo-uid');
      await cubit.close();
      version.complete(null);
      await refresh;

      expect(cubit.state, equals(SeatRefreshStatus.working));
    });
  });
}
