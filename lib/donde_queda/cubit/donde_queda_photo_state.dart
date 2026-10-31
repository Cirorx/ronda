part of 'donde_queda_photo_cubit.dart';

/// Where taking the week's photo stands.
enum DondeQuedaPhotoStatus {
  /// Reading the game.
  loading,

  /// Not this member's turn, or not any more.
  closed,

  /// On web: faces can't be blurred there, so the photo is taken from the
  /// phone app.
  unsupported,

  /// Waiting for a photo: the camera or the gallery.
  choosing,

  /// Finding and blurring faces on the phone.
  blurring,

  /// The blurred photo, what it is and the hint.
  preview,

  /// The map: the photographer's pin is the answer.
  pinning,

  /// The photo is up and the program is checking it.
  sending,

  /// Posted.
  done,
}

/// What went wrong last, shown until the next step.
enum DondeQuedaPhotoFailure {
  /// The photo couldn't be taken or blurred.
  photo,

  /// Refused: a house number shows.
  houseNumber,

  /// Refused: a person is the subject.
  person,

  /// Refused: nothing shows.
  empty,

  /// Refused: what was written.
  words,

  /// It couldn't be sent.
  send,
}

/// The photo, the words and the pin, step by step.
final class const DondeQuedaPhotoState({
  final DondeQuedaPhotoStatus status = DondeQuedaPhotoStatus.loading,

  /// This week's game, once read.
  final DondeQuedaGame? game,

  /// The photo with its faces blurred, from the preview on.
  final BlurredPhoto? photo,

  /// What the photo is.
  final GameText line = const GameText.pure(),

  /// The hint.
  final GameText hint = const GameText.pure(optional: true),

  /// The photographer's pin.
  final MapPoint? pin,

  /// The last failure, if the last step failed.
  final DondeQuedaPhotoFailure? failure,
}) extends Equatable {
  /// A copy with the given fields changed; a nullable one is passed as a
  /// function, so it can be set to `null`.
  DondeQuedaPhotoState copyWith({
    DondeQuedaPhotoStatus? status,
    BlurredPhoto? Function()? photo,
    GameText? line,
    GameText? hint,
    MapPoint? Function()? pin,
    DondeQuedaPhotoFailure? Function()? failure,
  }) => DondeQuedaPhotoState(
    status: status ?? this.status,
    game: game,
    photo: photo == null ? this.photo : photo(),
    line: line ?? this.line,
    hint: hint ?? this.hint,
    pin: pin == null ? this.pin : pin(),
    failure: failure == null ? this.failure : failure(),
  );

  @override
  List<Object?> get props => [status, game, photo, line, hint, pin, failure];
}
