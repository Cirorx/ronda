import 'package:bloc/bloc.dart';
import 'package:donde_queda_repository/donde_queda_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:error_reporter/error_reporter.dart';
import 'package:ronda/donde_queda/models/game_text.dart';

part 'donde_queda_photo_state.dart';

/// The member whose turn it is takes this week's ¿Dónde queda? photo for
/// ronda [_rondaId]: a photo of the barrio with its faces blurred on the
/// phone (any missed face blurred by a tap, as for the flyer), what it is
/// and an optional hint, then their pin on the map, which is the answer.
///
/// Only a [BlurredPhoto] ever reaches [DondeQuedaRepository.post]. A photo
/// the program refuses comes back with the reason: a house number, a
/// person or an empty photo asks for another one; words it holds go back
/// to the words.
class DondeQuedaPhotoCubit extends Cubit<DondeQuedaPhotoState>
    implements StepNamed {
  new({
    required this._uid,
    required this._rondaId,
    required this._dondeQuedaRepository,
  }) : super(const DondeQuedaPhotoState());

  final String _uid;
  final String _rondaId;
  final DondeQuedaRepository _dondeQuedaRepository;

  /// Reads the game: only the member whose turn it is goes on, and only on
  /// a phone. Picks up a photo the camera took while Android stopped the
  /// app.
  Future<void> started() async {
    final DondeQuedaGame? game;
    try {
      game =
          (await _dondeQuedaRepository
                  .watch(rondaId: _rondaId, uid: _uid)
                  .first)
              .game;
    } on Exception catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(const DondeQuedaPhotoState(status: DondeQuedaPhotoStatus.closed));
      return;
    }
    if (game == null || !game.isMyTurn) {
      emit(const DondeQuedaPhotoState(status: DondeQuedaPhotoStatus.closed));
      return;
    }
    if (!_dondeQuedaRepository.canBlurFaces) {
      emit(
        DondeQuedaPhotoState(
          status: DondeQuedaPhotoStatus.unsupported,
          game: game,
        ),
      );
      return;
    }
    emit(
      DondeQuedaPhotoState(status: DondeQuedaPhotoStatus.choosing, game: game),
    );
    final lost = await _dondeQuedaRepository.retrieveLostPhoto();
    if (lost != null) await _blur(lost);
  }

  /// «Sacar una foto» or «Elegir una de la galería».
  Future<void> photoRequested(PhotoSource source) async {
    if (state.status != DondeQuedaPhotoStatus.choosing) return;
    final TakenPhoto? taken;
    try {
      taken = await _dondeQuedaRepository.takePhoto(source);
    } on TakePhotoFailure {
      emit(state.copyWith(failure: () => DondeQuedaPhotoFailure.photo));
      return;
    }
    if (taken == null) return;
    await _blur(taken);
  }

  Future<void> _blur(TakenPhoto taken) async {
    emit(
      state.copyWith(
        status: DondeQuedaPhotoStatus.blurring,
        failure: () => null,
      ),
    );
    try {
      final photo = await _dondeQuedaRepository.blur(taken);
      emit(
        state.copyWith(
          status: DondeQuedaPhotoStatus.preview,
          photo: () => photo,
        ),
      );
    } on BlurPhotoFailure {
      emit(
        state.copyWith(
          status: DondeQuedaPhotoStatus.choosing,
          failure: () => DondeQuedaPhotoFailure.photo,
        ),
      );
    }
  }

  /// "Tocá una cara para borronearla": the face around ([x], [y]) is
  /// blurred too.
  Future<void> faceTapped({required double x, required double y}) async {
    final photo = state.photo;
    if (state.status != DondeQuedaPhotoStatus.preview || photo == null) return;
    emit(
      state.copyWith(
        status: DondeQuedaPhotoStatus.blurring,
        failure: () => null,
      ),
    );
    try {
      final blurred = await _dondeQuedaRepository.blurTappedFace(
        photo,
        x: x,
        y: y,
      );
      emit(
        state.copyWith(
          status: DondeQuedaPhotoStatus.preview,
          photo: () => blurred,
        ),
      );
    } on BlurPhotoFailure {
      emit(
        state.copyWith(
          status: DondeQuedaPhotoStatus.preview,
          failure: () => DondeQuedaPhotoFailure.photo,
        ),
      );
    }
  }

  /// What the photo is, as typed.
  void lineChanged(String value) =>
      emit(state.copyWith(line: GameText.dirty(value)));

  /// The hint, as typed.
  void hintChanged(String value) =>
      emit(state.copyWith(hint: GameText.dirty(value, optional: true)));

  /// «Seguir» from the photo and the words to the map.
  void wordsDone() {
    if (state.status != DondeQuedaPhotoStatus.preview) return;
    if (!state.line.isValid || !state.hint.isValid) {
      emit(state.copyWith(line: GameText.dirty(state.line.value)));
      return;
    }
    emit(
      state.copyWith(
        status: DondeQuedaPhotoStatus.pinning,
        failure: () => null,
      ),
    );
  }

  /// A tap on the map: the pin goes there.
  void pinDropped(MapPoint pin) {
    if (state.status != DondeQuedaPhotoStatus.pinning) return;
    emit(state.copyWith(pin: () => pin));
  }

  /// Back from the map to the photo and the words.
  void backToWords() {
    if (state.status != DondeQuedaPhotoStatus.pinning) return;
    emit(state.copyWith(status: DondeQuedaPhotoStatus.preview));
  }

  /// «Mandar la foto»: the blurred photo goes up and the program checks it.
  Future<void> sendTapped() async {
    final (game, photo, pin) = (state.game, state.photo, state.pin);
    if (state.status != DondeQuedaPhotoStatus.pinning ||
        game == null ||
        photo == null ||
        pin == null) {
      return;
    }
    emit(
      state.copyWith(
        status: DondeQuedaPhotoStatus.sending,
        failure: () => null,
      ),
    );
    try {
      await _dondeQuedaRepository.post(
        uid: _uid,
        rondaId: _rondaId,
        week: game.week,
        photo: photo,
        line: state.line.text,
        hint: state.hint.text,
        pin: pin,
      );
      emit(state.copyWith(status: DondeQuedaPhotoStatus.done));
    } on PhotoRefusedFailure catch (refused) {
      emit(
        refused.reason == PhotoRefusal.words
            ? state.copyWith(
                status: DondeQuedaPhotoStatus.preview,
                failure: () => DondeQuedaPhotoFailure.words,
              )
            : state.copyWith(
                status: DondeQuedaPhotoStatus.choosing,
                photo: () => null,
                pin: () => null,
                failure: () => switch (refused.reason) {
                  PhotoRefusal.houseNumber =>
                    DondeQuedaPhotoFailure.houseNumber,
                  PhotoRefusal.person => DondeQuedaPhotoFailure.person,
                  _ => DondeQuedaPhotoFailure.empty,
                },
              ),
      );
    } on NotYourTurnFailure {
      emit(const DondeQuedaPhotoState(status: DondeQuedaPhotoStatus.closed));
    } on DondeQuedaFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      emit(
        state.copyWith(
          status: DondeQuedaPhotoStatus.pinning,
          failure: () => DondeQuedaPhotoFailure.send,
        ),
      );
    }
  }

  /// «Sacar otra foto»: back to the camera, the words kept.
  void retakeRequested() {
    if (state.status != DondeQuedaPhotoStatus.preview) return;
    emit(
      state.copyWith(
        status: DondeQuedaPhotoStatus.choosing,
        photo: () => null,
        failure: () => null,
      ),
    );
  }

  @override
  String get reportStep => 'DondeQuedaPhotoCubit';
}
