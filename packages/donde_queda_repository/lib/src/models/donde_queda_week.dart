import 'package:equatable/equatable.dart';

/// {@template map_point}
/// A point on the barrio's map: a pin, or the map's centre.
/// {@endtemplate}
final class const MapPoint(
  /// The latitude.
  final double lat,

  /// The longitude.
  final double lng,
) extends Equatable {
  /// {@macro map_point}
  this;

  @override
  List<Object?> get props => [lat, lng];
}

/// Where this week's game stands for everyone.
enum DondeQuedaStatus {
  /// Someone in the ronda was asked for the photo (who, nobody says).
  asking,

  /// The photo is up: the others drop their pins.
  open,

  /// Everyone passed: no game this week.
  nobody,
}

/// {@template donde_queda_game}
/// This week's ¿Dónde queda? as one member sees it: the game itself, plus
/// whether it is their turn, whether they posted and whether they guessed.
/// {@endtemplate}
final class const DondeQuedaGame({
  /// The meeting's ISO week the game belongs to.
  required final String week,

  /// Where it stands.
  required final DondeQuedaStatus status,

  /// The map's centre: the barrio's.
  required final MapPoint centre,

  /// The map's zoom level.
  required final int zoom,

  /// The day guessing closes: the meeting's.
  required final DateTime closesOn,

  /// The photo's Storage path, once [DondeQuedaStatus.open].
  final String? photoPath,

  /// The photographer's hint; empty when they gave none.
  final String hint = '',

  /// Whether it is this member's turn to take the photo.
  final bool isMyTurn = false,

  /// Whether this member posted the photo.
  final bool posted = false,

  /// Whether this member already dropped their pin.
  final bool guessed = false,
}) extends Equatable {
  /// {@macro donde_queda_game}
  this;

  @override
  List<Object?> get props => [
    week,
    status,
    centre,
    zoom,
    closesOn,
    photoPath,
    hint,
    isMyTurn,
    posted,
    guessed,
  ];
}

/// {@template donde_queda_reveal}
/// Last week's answer, on this week's card: "Era la puerta verde de
/// Gestido y Rivera." and "Cerca: 3 de 5". Counts only, no names.
/// {@endtemplate}
final class const DondeQuedaReveal({
  /// What the photo was.
  required final String line,

  /// How many came close.
  required final int close,

  /// How many guessed.
  required final int guessed,
}) extends Equatable {
  /// {@macro donde_queda_reveal}
  this;

  @override
  List<Object?> get props => [line, close, guessed];
}

/// {@template donde_queda_week}
/// What Mi ronda shows of ¿Dónde queda?: this week's game and last week's
/// answer, each `null` when there is none.
/// {@endtemplate}
final class const DondeQuedaWeek({
  /// This week's game.
  final DondeQuedaGame? game,

  /// Last week's answer.
  final DondeQuedaReveal? reveal,
}) extends Equatable {
  /// {@macro donde_queda_week}
  this;

  @override
  List<Object?> get props => [game, reveal];
}

/// Why a photo was refused, in plain words on the screen.
enum PhotoRefusal {
  /// A house number shows.
  houseNumber,

  /// A person is the subject.
  person,

  /// Nothing shows: dark, blank or blurry.
  empty,

  /// What was written points at a home or a person, or fails the gates.
  words,
}
