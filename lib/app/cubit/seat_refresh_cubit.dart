import 'package:bloc/bloc.dart';
import 'package:error_reporter/error_reporter.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/onboarding/models/eligible_seats.dart';

/// Where working out a member's eligible seats on launch stands.
enum SeatRefreshStatus {
  /// Nothing asked yet, or nobody with a profile to work them out for.
  idle,

  /// Reading the catalogue's version, or working the seats out.
  working,

  /// The seats on the server were worked out against the published
  /// catalogue, or no catalogue is published yet.
  upToDate,

  /// The server published another catalogue, so they were worked out again.
  refreshed,

  /// A read or a write failed; the next launch tries again.
  failed,
}

/// Works out a member's eligible seats again, quietly, when the server has
/// published a seat catalogue other than the one this phone last used for
/// them. Otherwise a member keeps the seats of the catalogue they signed up
/// with until they save "Mis datos".
///
/// The needs filter runs here on the phone, as at sign-up: only the seat ids
/// that pass go to the server. Failures are reported to the observer, never
/// shown.
class SeatRefreshCubit extends Cubit<SeatRefreshStatus> implements StepNamed {
  new({required this._profileRepository, required this._needsRepository})
    : super(SeatRefreshStatus.idle);

  final ProfileRepository _profileRepository;
  final NeedsRepository _needsRepository;

  /// Checks the published catalogue for [uid], who has a profile, and works
  /// their seats out again when it changed.
  Future<void> refresh(String uid) async {
    if (state == SeatRefreshStatus.working) return;
    emit(SeatRefreshStatus.working);
    try {
      final published = await _profileRepository.publishedSeatCatalogVersion();
      if (published == null ||
          published == await _profileRepository.seatCatalogWorkedOut(uid)) {
        _finish(SeatRefreshStatus.upToDate);
        return;
      }
      final profile = await _profileRepository.watchProfile(uid).first;
      if (profile == null) {
        _finish(SeatRefreshStatus.idle);
        return;
      }
      await publishEligibleSeatIds(
        uid: uid,
        needs: await _needsRepository.read(),
        profile: profile,
        profileRepository: _profileRepository,
        needsRepository: _needsRepository,
      );
      _finish(SeatRefreshStatus.refreshed);
    } on Exception catch (error, stackTrace) {
      addError(error, stackTrace);
      _finish(SeatRefreshStatus.failed);
    }
  }

  void _finish(SeatRefreshStatus status) {
    if (!isClosed) emit(status);
  }

  @override
  String get reportStep => 'SeatRefreshCubit';
}
