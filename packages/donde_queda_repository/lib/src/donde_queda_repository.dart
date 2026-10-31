import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:donde_queda_repository/src/donde_queda_failures.dart';
import 'package:donde_queda_repository/src/models/models.dart';
import 'package:face_blur/face_blur.dart';
import 'package:ronda_api/ronda_api.dart';

/// {@template donde_queda_repository}
/// ¿Dónde queda?, the ronda's weekly barrio photo game: this week's game
/// and last week's answer, the photo from the camera to the server, "Esta
/// semana no", and each member's one pin.
///
/// **Only a blurred photo leaves the phone.** [post] takes a
/// [BlurredPhoto], which only [FaceBlur] makes, through the same
/// `face_blur` pipeline as the "Un mate de más" flyer; the server then
/// blurs people and number plates and refuses house numbers.
///
/// Taking the photo is phones only: [canBlurFaces] is `false` on web.
/// Guessing works everywhere.
/// {@endtemplate}
class DondeQuedaRepository {
  /// {@macro donde_queda_repository}
  new({
    required this._faceBlur,
    required this._dondeQuedaApi,
    String Function()? newPhotoId,
  }) : _newPhotoId = newPhotoId ?? _randomPhotoId;

  final FaceBlur _faceBlur;
  final DondeQuedaApi _dondeQuedaApi;
  final String Function() _newPhotoId;

  static String _randomPhotoId() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  /// Whether this platform can blur faces, and so take the photo.
  bool get canBlurFaces => _faceBlur.isSupported;

  /// Ronda [rondaId]'s game as [uid] sees it, now and on every change.
  Stream<DondeQuedaWeek> watch({required String rondaId, required String uid}) {
    DondeQuedaViewDocument? view;
    DondeQuedaPlayerDocument? player;
    var heardView = false;
    var heardPlayer = false;
    final subscriptions = <StreamSubscription<Object?>>[];
    late final StreamController<DondeQuedaWeek> controller;

    void emit() {
      if (heardView && heardPlayer) controller.add(_week(view, player));
    }

    controller = StreamController<DondeQuedaWeek>(
      onListen: () {
        subscriptions
          ..add(
            _dondeQuedaApi.watchView(rondaId).listen((value) {
              view = value;
              heardView = true;
              emit();
            }, onError: controller.addError),
          )
          ..add(
            _dondeQuedaApi.watchPlayer(rondaId, uid).listen((value) {
              player = value;
              heardPlayer = true;
              emit();
            }, onError: controller.addError),
          );
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  static DondeQuedaWeek _week(
    DondeQuedaViewDocument? view,
    DondeQuedaPlayerDocument? player,
  ) {
    final reveal = view?.reveal;
    return DondeQuedaWeek(
      game: _game(view?.current, player),
      reveal: reveal == null
          ? null
          : DondeQuedaReveal(
              line: reveal.line,
              close: reveal.close,
              guessed: reveal.guessed,
            ),
    );
  }

  static DondeQuedaGame? _game(
    DondeQuedaCurrentDocument? current,
    DondeQuedaPlayerDocument? player,
  ) {
    if (current == null) return null;
    final status = DondeQuedaStatus.values.asNameMap()[current.status];
    final closesOn = DateTime.tryParse(current.closesOn);
    if (status == null || closesOn == null) return null;
    final mine = player?.week == current.week ? player : null;
    return DondeQuedaGame(
      week: current.week,
      status: status,
      centre: MapPoint(current.centre.lat, current.centre.lng),
      zoom: current.zoom,
      closesOn: closesOn,
      photoPath: current.photoPath,
      hint: current.hint ?? '',
      isMyTurn: status == DondeQuedaStatus.asking && (mine?.asked ?? false),
      posted: mine?.posted ?? false,
      guessed: mine?.guessed ?? false,
    );
  }

  /// Opens the camera or the gallery; `null` when the person backs out.
  ///
  /// Throws a [TakePhotoFailure] when neither opens.
  Future<TakenPhoto?> takePhoto(PhotoSource source) async {
    try {
      return await _faceBlur.takePhoto(source);
    } on Exception {
      throw const TakePhotoFailure();
    }
  }

  /// The photo the camera took while Android stopped the app, if any;
  /// `null` when there is none or it can't be read.
  Future<TakenPhoto?> retrieveLostPhoto() async {
    try {
      return await _faceBlur.retrieveLostPhoto();
    } on Exception {
      return null;
    }
  }

  /// [photo] with every face found pixelated.
  ///
  /// Throws a [BlurPhotoFailure] when it can't be read.
  Future<BlurredPhoto> blur(TakenPhoto photo) async {
    try {
      return await _faceBlur.blur(photo);
    } on Exception {
      throw const BlurPhotoFailure();
    }
  }

  /// [photo] with the face around ([x], [y]) pixelated too.
  ///
  /// Throws a [BlurPhotoFailure] when it can't be.
  Future<BlurredPhoto> blurTappedFace(
    BlurredPhoto photo, {
    required double x,
    required double y,
  }) async {
    try {
      return await _faceBlur.blurTappedFace(photo, x: x, y: y);
    } on Exception {
      throw const BlurPhotoFailure();
    }
  }

  /// Uploads [photo] and posts it as ronda [rondaId]'s photo of [week]:
  /// what it is ([line]), an optional [hint], and where ([pin]).
  ///
  /// Throws a [PhotoRefusedFailure] with the reason when the program
  /// refused it, a [NotYourTurnFailure] when the turn passed on, and a
  /// [DondeQuedaFailure] for anything else. The callable deletes the
  /// upload; when it never got to, this repository does.
  Future<void> post({
    required String uid,
    required String rondaId,
    required String week,
    required BlurredPhoto photo,
    required String line,
    required String hint,
    required MapPoint pin,
  }) async {
    final String path;
    try {
      path = await _dondeQuedaApi.uploadPhoto(
        uid: uid,
        photoId: _newPhotoId(),
        jpeg: photo.jpeg,
      );
    } on Exception {
      throw const DondeQuedaFailure();
    }
    try {
      await _dondeQuedaApi.post(
        rondaId: rondaId,
        week: week,
        photoPath: path,
        line: line,
        hint: hint,
        lat: pin.lat,
        lng: pin.lng,
      );
    } on DondeQuedaRefusedException catch (refused) {
      throw PhotoRefusedFailure(
        PhotoRefusal.values.asNameMap()[refused.reason] ?? PhotoRefusal.empty,
      );
    } on NotYourTurnException {
      throw const NotYourTurnFailure();
    } on Exception {
      await _deleteUnread(path);
      throw const DondeQuedaFailure();
    }
  }

  /// "Esta semana no": the turn passes on.
  ///
  /// Throws a [NotYourTurnFailure] when it already did, and a
  /// [DondeQuedaFailure] for anything else.
  Future<void> pass({required String rondaId, required String week}) async {
    try {
      await _dondeQuedaApi.pass(rondaId: rondaId, week: week);
    } on NotYourTurnException {
      throw const NotYourTurnFailure();
    } on Exception {
      throw const DondeQuedaFailure();
    }
  }

  /// Drops this member's one pin at [pin] on [week]'s photo.
  ///
  /// Throws an [AlreadyGuessedFailure] when they already did, a
  /// [NotYourTurnFailure] when the game closed, and a [DondeQuedaFailure]
  /// for anything else.
  Future<void> guess({
    required String rondaId,
    required String week,
    required MapPoint pin,
  }) async {
    try {
      await _dondeQuedaApi.guess(
        rondaId: rondaId,
        week: week,
        lat: pin.lat,
        lng: pin.lng,
      );
    } on AlreadyGuessedException {
      throw const AlreadyGuessedFailure();
    } on NotYourTurnException {
      throw const NotYourTurnFailure();
    } on Exception {
      throw const DondeQuedaFailure();
    }
  }

  /// The week's photo at [path], as JPEG bytes.
  ///
  /// Throws a [DondeQuedaFailure] when it can't be read.
  Future<Uint8List> photo(String path) async {
    try {
      return await _dondeQuedaApi.downloadPhoto(path);
    } on Exception {
      throw const DondeQuedaFailure();
    }
  }

  /// Deletes an upload the callable may not have reached; the bucket's
  /// 1-day lifecycle rule on `donde_queda_photos/` is the backstop.
  Future<void> _deleteUnread(String path) async {
    try {
      await _dondeQuedaApi.deletePhoto(path);
    } on Exception {
      // Already deleted, or unreachable: the lifecycle rule removes it.
    }
  }
}
