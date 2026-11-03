import 'package:needs_repository/needs_repository.dart';
import 'package:profile_repository/profile_repository.dart';

/// Filters the published seats with [needs] on this phone and writes only the
/// ids that pass to `users/{uid}/private/eligible`, then remembers on the
/// phone which catalogue version they were worked out against, so the app
/// works them out again on launch when the server publishes another
/// (`SeatRefreshCubit`).
///
/// Each walk is measured from the nearest of the profile's anchors (casa,
/// and trabajo when it has one), each reaching its own walk, or 1.5 times it
/// with its neighbours ([Anchor.reachBlocks]). Pretext and slot are not
/// filtered here: the solver matches those against the profile. Onboarding's
/// save and "Mis datos" both call it before writing the profile, so the
/// solver never reads a profile whose eligible ids it hasn't got.
///
/// Throws what [ProfileRepository.publishedSeatCatalogVersion],
/// [ProfileRepository.publishedSeats] and
/// [ProfileRepository.saveEligibleSeatIds] throw. A version the phone can't
/// keep only means working them out once more on the next launch.
Future<void> publishEligibleSeatIds({
  required String uid,
  required Needs needs,
  required Profile profile,
  required ProfileRepository profileRepository,
  required NeedsRepository needsRepository,
}) async {
  final version = await profileRepository.publishedSeatCatalogVersion();
  final seats = await profileRepository.publishedSeats();
  final facts = [
    for (final seat in seats)
      SeatFacts(
        seatId: seat.seatId,
        walkDistance: WalkDistance.nearest([
          for (final anchor in profile.anchors)
            WalkDistance.forMember(
              memberBarrio: anchor.barrio.id,
              blocksFrom: seat.blocksFrom,
              maxBlocks: anchor.reachBlocks,
            ),
        ]),
        hasStairs: seat.hasStairs,
        endsAfterDark: seat.endsAfterDark,
        needsCar: seat.needsCar,
      ),
  ];
  await profileRepository.saveEligibleSeatIds(
    uid: uid,
    seatIds: needsRepository.eligibleSeatIds(needs, facts),
  );
  if (version == null) return;
  try {
    await profileRepository.holdSeatCatalogWorkedOut(uid, version);
  } on HoldOnPhoneFailure {
    // Worked out again on the next launch.
  }
}
