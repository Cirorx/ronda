import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/onboarding/models/models.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'my_data_state.dart';

/// "Mis datos": the member changes what they gave at sign-up, casa and
/// trabajo included, and saves it as onboarding does: the seat ids their
/// needs let through first (measured from casa and trabajo), then the
/// profile, keeping when it was first saved.
///
/// A member already in a ronda stays in it: a new barrio or new times count
/// from the next time the solver groups people, and the screen says so.
class MyDataCubit extends Cubit<MyDataState> {
  new({
    required this._uid,
    required this._profileRepository,
    required this._needsRepository,
    required this._rondaRepository,
  }) : super(const MyDataState());

  final String _uid;
  final ProfileRepository _profileRepository;
  final NeedsRepository _needsRepository;
  final RondaRepository _rondaRepository;

  /// Reads the profile and whether the member sits in a ronda.
  Future<void> load() async {
    emit(const MyDataState());
    final Profile? profile;
    try {
      profile = await _profileRepository.watchProfile(_uid).first;
    } on Exception {
      if (!isClosed) emit(const MyDataState(status: MyDataStatus.loadFailure));
      return;
    }
    final seated = await _seated();
    if (isClosed) return;
    emit(
      profile == null
          ? const MyDataState(status: MyDataStatus.loadFailure)
          : MyDataState.fromProfile(profile, seated: seated),
    );
  }

  Future<bool> _seated() async {
    try {
      final week = await _rondaRepository.watchThisWeek(_uid).first;
      return week != null && !week.hasLeft;
    } on Exception {
      // Not knowing only leaves out the note.
      return false;
    }
  }

  void _edit(MyDataState next) =>
      emit(next.copyWith(status: MyDataStatus.editing));

  /// The first name as typed.
  void firstNameChanged(String value) =>
      _edit(state.copyWith(firstName: FirstName.dirty(value)));

  /// The age band.
  void ageBandChanged(AgeBand ageBand) =>
      _edit(state.copyWith(ageBand: ageBand));

  /// Casa moves to [barrio]; trabajo goes when it was that barrio.
  void homeChanged(Barrio barrio) => _edit(
    state.copyWith(
      home: Anchor(barrio: barrio, neighbours: state.home?.neighbours ?? false),
      work: state.work?.barrio == barrio ? () => null : null,
    ),
  );

  /// Casa's neighbours switched.
  void homeNeighboursChanged({required bool neighbours}) {
    if (state.home case final home?) {
      _edit(state.copyWith(home: home.withNeighbours(neighbours: neighbours)));
    }
  }

  /// Trabajo set to [barrio]; casa itself is not a trabajo.
  void workChanged(Barrio barrio) {
    if (barrio == state.home?.barrio) return;
    final neighbours = state.work?.neighbours ?? false;
    _edit(
      state.copyWith(
        work: () => Anchor(barrio: barrio, neighbours: neighbours),
      ),
    );
  }

  /// Trabajo's neighbours switched.
  void workNeighboursChanged({required bool neighbours}) {
    if (state.work case final work?) {
      _edit(
        state.copyWith(work: () => work.withNeighbours(neighbours: neighbours)),
      );
    }
  }

  /// "Sacar trabajo".
  void workRemoved() => _edit(state.copyWith(work: () => null));

  /// What they'd like to do.
  void pretextsChanged(Set<Pretext> pretexts) =>
      _edit(state.copyWith(pretexts: pretexts));

  /// When they can.
  void slotsChanged(Set<Slot> slots) => _edit(state.copyWith(slots: slots));

  /// What they bring.
  void bringsChanged(Set<Bring> brings) =>
      _edit(state.copyWith(brings: brings));

  /// "Guardar": the eligible ids for the new barrios, then the profile.
  /// Either failing writes no profile and the answers stay for a retry.
  Future<void> save() async {
    final profile = state.profile;
    if (profile == null || state.status.isUnderway) return;
    emit(state.copyWith(status: MyDataStatus.saving));
    try {
      await publishEligibleSeatIds(
        uid: _uid,
        needs: await _needsRepository.read(),
        profile: profile,
        profileRepository: _profileRepository,
        needsRepository: _needsRepository,
      );
      await _profileRepository.updateProfile(_uid, profile);
    } on Exception {
      if (!isClosed) emit(state.copyWith(status: MyDataStatus.saveFailure));
      return;
    }
    if (!isClosed) {
      emit(state.copyWith(status: MyDataStatus.saved, saved: profile));
    }
  }
}
