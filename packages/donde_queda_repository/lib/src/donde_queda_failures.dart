import 'package:donde_queda_repository/src/models/models.dart';

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

/// {@template photo_refused_failure}
/// The program refused the photo or what was written with it, for
/// [reason]. Nothing was published.
/// {@endtemplate}
class const PhotoRefusedFailure(
  /// Why.
  final PhotoRefusal reason,
) implements Exception {
  /// {@macro photo_refused_failure}
  this;
}

/// {@template not_your_turn_failure}
/// Too late or not this member's: the turn passed on, the game closed, or
/// the photo is their own.
/// {@endtemplate}
class NotYourTurnFailure implements Exception {
  /// {@macro not_your_turn_failure}
  const new();
}

/// {@template already_guessed_failure}
/// The member already dropped their one pin.
/// {@endtemplate}
class AlreadyGuessedFailure implements Exception {
  /// {@macro already_guessed_failure}
  const new();
}

/// {@template donde_queda_failure}
/// Anything else: no connection, or the server failed. Trying again may
/// work.
/// {@endtemplate}
class DondeQuedaFailure implements Exception {
  /// {@macro donde_queda_failure}
  const new();
}
