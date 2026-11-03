import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/onboarding/models/eligible_seats.dart';

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

void main() {
  group('publishEligibleSeatIds', () {
    late ProfileRepository profileRepository;
    late NeedsRepository needsRepository;

    setUpAll(() => registerFallbackValue(Needs.none));

    setUp(() {
      profileRepository = _MockProfileRepository();
      needsRepository = _MockNeedsRepository();
      when(profileRepository.publishedSeatCatalogVersion)
          .thenAnswer((_) async => 'v2');
      when(profileRepository.publishedSeats).thenAnswer((_) async => const []);
      when(
        () => profileRepository.saveEligibleSeatIds(
          uid: any(named: 'uid'),
          seatIds: any(named: 'seatIds'),
        ),
      ).thenAnswer((_) async {});
      when(() => profileRepository.holdSeatCatalogWorkedOut(any(), any()))
          .thenAnswer((_) async {});
      when(() => needsRepository.eligibleSeatIds(any(), any()))
          .thenReturn(const []);
    });

    Future<void> publish() => publishEligibleSeatIds(
      uid: 'demo-uid',
      needs: Needs.none,
      profile: _profile,
      profileRepository: profileRepository,
      needsRepository: needsRepository,
    );

    test('remembers the catalogue version after saving the seats', () async {
      await publish();

      verifyInOrder([
        () => profileRepository.saveEligibleSeatIds(
          uid: 'demo-uid',
          seatIds: const [],
        ),
        () => profileRepository.holdSeatCatalogWorkedOut('demo-uid', 'v2'),
      ]);
    });

    test('remembers nothing before a catalogue is published', () async {
      when(profileRepository.publishedSeatCatalogVersion)
          .thenAnswer((_) async => null);

      await publish();

      verifyNever(
        () => profileRepository.holdSeatCatalogWorkedOut(any(), any()),
      );
    });

    test('still succeeds when the phone cannot keep the version', () async {
      when(() => profileRepository.holdSeatCatalogWorkedOut(any(), any()))
          .thenThrow(const HoldOnPhoneFailure());

      await expectLater(publish(), completes);
    });
  });
}
