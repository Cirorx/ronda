/// {@template take_photo_failure}
/// The camera or the gallery couldn't be opened.
/// {@endtemplate}
class TakePhotoFailure implements Exception {
  /// {@macro take_photo_failure}
  const new();
}

/// {@template blur_photo_failure}
/// The photo couldn't be read or its faces blurred. Nothing left the phone.
/// {@endtemplate}
class BlurPhotoFailure implements Exception {
  /// {@macro blur_photo_failure}
  const new();
}

/// {@template not_a_host_failure}
/// Only the ronda's hosts (or, while it has none, its members) make its
/// flyer.
/// {@endtemplate}
class NotAHostFailure implements Exception {
  /// {@macro not_a_host_failure}
  const new();
}

/// {@template nothing_to_cut_out_failure}
/// No termo, mazo or mate was found in the photo. Another photo, closer,
/// may work.
/// {@endtemplate}
class NothingToCutOutFailure implements Exception {
  /// {@macro nothing_to_cut_out_failure}
  const new();
}

/// {@template make_flyer_failure}
/// The flyer couldn't be made: no connection, or the server failed.
/// {@endtemplate}
class MakeFlyerFailure implements Exception {
  /// {@macro make_flyer_failure}
  const new();
}

/// {@template share_flyer_failure}
/// The share sheet couldn't be opened.
/// {@endtemplate}
class ShareFlyerFailure implements Exception {
  /// {@macro share_flyer_failure}
  const new();
}
