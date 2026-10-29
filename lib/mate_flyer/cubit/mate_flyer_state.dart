part of 'mate_flyer_cubit.dart';

/// Where the flyer stands.
enum MateFlyerStatus {
  /// On web: faces can't be blurred there, so no flyer either.
  unsupported,

  /// Waiting for a photo: the camera or the gallery.
  choosing,

  /// Finding and blurring faces on the phone; with a photo already shown,
  /// blurring a tapped face.
  blurring,

  /// The blurred photo, to check and tap any face the detector missed.
  preview,

  /// The photo is uploaded and the server is making the flyer.
  making,

  /// "Así queda tu volante".
  ready,
}

/// What went wrong last, shown until the next step.
enum MateFlyerFailure {
  /// The photo couldn't be taken or blurred.
  photo,

  /// The person doesn't host this ronda.
  notHost,

  /// Nothing to cut out of the photo: no termo, mazo or mate.
  nothingToCutOut,

  /// The flyer couldn't be made.
  flyer,

  /// The share sheet didn't open.
  share,
}

final class const MateFlyerState({
  final MateFlyerStatus status = MateFlyerStatus.choosing,

  /// The photo with its faces blurred, from [MateFlyerStatus.preview] on.
  final BlurredPhoto? photo,

  /// The finished flyer, once [MateFlyerStatus.ready].
  final MateFlyer? flyer,

  /// The last failure, if the last step failed.
  final MateFlyerFailure? failure,
}) extends Equatable {
  @override
  List<Object?> get props => [status, photo, flyer, failure];
}
