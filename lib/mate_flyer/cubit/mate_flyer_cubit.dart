import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flyer_repository/flyer_repository.dart';

part 'mate_flyer_state.dart';

/// The host's "Un mate de más" flyer for ronda [_rondaId]: a photo of the
/// group's things, its faces blurred on the phone, any missed face blurred
/// by a tap, then the flyer the server makes from it, to print or share.
///
/// Only a [BlurredPhoto] ever reaches [FlyerRepository.makeMateFlyer].
class MateFlyerCubit extends Cubit<MateFlyerState> {
  new({
    required this._uid,
    required this._rondaId,
    required this._flyerRepository,
  }) : super(
         MateFlyerState(
           status: _flyerRepository.canBlurFaces
               ? MateFlyerStatus.choosing
               : MateFlyerStatus.unsupported,
         ),
       );

  final String _uid;
  final String _rondaId;
  final FlyerRepository _flyerRepository;

  /// Picks up a photo the camera took while Android stopped the app.
  Future<void> started() async {
    if (state.status != MateFlyerStatus.choosing) return;
    final lost = await _flyerRepository.retrieveLostPhoto();
    if (lost != null) await _blur(lost);
  }

  /// [Sacar una foto] or [Elegir una de la galería].
  Future<void> photoRequested(PhotoSource source) async {
    if (state.status != MateFlyerStatus.choosing) return;
    final TakenPhoto? taken;
    try {
      taken = await _flyerRepository.takePhoto(source);
    } on Exception {
      emit(const MateFlyerState(failure: MateFlyerFailure.photo));
      return;
    }
    if (taken == null) {
      emit(const MateFlyerState());
      return;
    }
    await _blur(taken);
  }

  Future<void> _blur(TakenPhoto taken) async {
    emit(const MateFlyerState(status: MateFlyerStatus.blurring));
    try {
      final photo = await _flyerRepository.blur(taken);
      emit(MateFlyerState(status: MateFlyerStatus.preview, photo: photo));
    } on Exception {
      emit(const MateFlyerState(failure: MateFlyerFailure.photo));
    }
  }

  /// "Tocá una cara para borronearla": the face around ([x], [y]), each a
  /// share of the photo's width and height, is blurred too.
  Future<void> faceTapped({required double x, required double y}) async {
    final photo = state.photo;
    if (state.status != MateFlyerStatus.preview || photo == null) return;
    emit(MateFlyerState(status: MateFlyerStatus.blurring, photo: photo));
    try {
      final blurred = await _flyerRepository.blurTappedFace(photo, x: x, y: y);
      emit(MateFlyerState(status: MateFlyerStatus.preview, photo: blurred));
    } on Exception {
      emit(
        MateFlyerState(
          status: MateFlyerStatus.preview,
          photo: photo,
          failure: MateFlyerFailure.photo,
        ),
      );
    }
  }

  /// [Hacer el volante]: the blurred photo goes up and the flyer comes
  /// back.
  Future<void> flyerRequested() async {
    final photo = state.photo;
    if (state.status != MateFlyerStatus.preview || photo == null) return;
    emit(MateFlyerState(status: MateFlyerStatus.making, photo: photo));
    try {
      final flyer = await _flyerRepository.makeMateFlyer(
        uid: _uid,
        rondaId: _rondaId,
        photo: photo,
      );
      emit(MateFlyerState(status: MateFlyerStatus.ready, flyer: flyer));
    } on NothingToCutOutFailure {
      emit(const MateFlyerState(failure: MateFlyerFailure.nothingToCutOut));
    } on NotAHostFailure {
      emit(
        MateFlyerState(
          status: MateFlyerStatus.preview,
          photo: photo,
          failure: MateFlyerFailure.notHost,
        ),
      );
    } on Exception {
      emit(
        MateFlyerState(
          status: MateFlyerStatus.preview,
          photo: photo,
          failure: MateFlyerFailure.flyer,
        ),
      );
    }
  }

  /// [Imprimir o compartir]: the share sheet, titled [title].
  Future<void> shareRequested({required String title}) async {
    final flyer = state.flyer;
    if (state.status != MateFlyerStatus.ready || flyer == null) return;
    if (state.failure != null) {
      emit(MateFlyerState(status: MateFlyerStatus.ready, flyer: flyer));
    }
    try {
      await _flyerRepository.shareFlyer(flyer, title: title);
    } on Exception {
      emit(
        MateFlyerState(
          status: MateFlyerStatus.ready,
          flyer: flyer,
          failure: MateFlyerFailure.share,
        ),
      );
    }
  }

  /// [Sacar otra foto]: back to the start, the photo and the flyer
  /// dropped.
  void retakeRequested() {
    if (state.status == MateFlyerStatus.unsupported) return;
    emit(const MateFlyerState());
  }
}
