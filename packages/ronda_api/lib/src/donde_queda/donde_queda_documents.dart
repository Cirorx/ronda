/// {@template donde_queda_point}
/// A point on the map: a pin, or the centre of the ronda's area.
/// {@endtemplate}
class const DondeQuedaPoint({
  /// The latitude.
  required final double lat,

  /// The longitude.
  required final double lng,
}) {
  /// {@macro donde_queda_point}
  this;
}

/// {@template donde_queda_current_document}
/// This week's game as members read it on `rondas/{id}/views/donde_queda`
/// (`functions/donde_queda.py`): never who was asked, the pin or anyone's
/// guess.
/// {@endtemplate}
class const DondeQuedaCurrentDocument({
  /// The meeting's ISO week the game belongs to.
  required final String week,

  /// `asking`, `open` or `nobody`.
  required final String status,

  /// The centre of the map: the barrio's centroid.
  required final DondeQuedaPoint centre,

  /// The map's zoom level.
  required final int zoom,

  /// The day guessing closes (`YYYY-MM-DD`): the meeting's.
  required final String closesOn,

  /// The published photo's Storage path, once `open`.
  final String? photoPath,

  /// The photographer's hint, once `open`; empty when they gave none.
  final String? hint,
}) {
  /// {@macro donde_queda_current_document}
  this;

  /// Reads the view's `current` map.
  ///
  /// Throws a [FormatException] for any other shape.
  factory fromJson(Object? json) {
    if (json case {
      'week': final String week,
      'status': final String status,
      'area': {
        'lat': final num lat,
        'lng': final num lng,
        'zoom': final num zoom,
      },
      'closesOn': final String closesOn,
    }) {
      return DondeQuedaCurrentDocument(
        week: week,
        status: status,
        centre: DondeQuedaPoint(lat: lat.toDouble(), lng: lng.toDouble()),
        zoom: zoom.toInt(),
        closesOn: closesOn,
        photoPath: json['photoPath'] as String?,
        hint: json['hint'] as String?,
      );
    }
    throw const FormatException('the game has another shape');
  }
}

/// {@template donde_queda_reveal_document}
/// Last week's answer on `rondas/{id}/views/donde_queda`: what it was and
/// how many came close. Counts only.
/// {@endtemplate}
class const DondeQuedaRevealDocument({
  /// The ISO week of the game it closes.
  required final String week,

  /// What the photo was ("la puerta verde de Gestido y Rivera").
  required final String line,

  /// How many guesses came close.
  required final int close,

  /// How many guessed.
  required final int guessed,
}) {
  /// {@macro donde_queda_reveal_document}
  this;

  /// Reads the view's `reveal` map.
  ///
  /// Throws a [FormatException] for any other shape.
  factory fromJson(Object? json) {
    if (json case {
      'week': final String week,
      'line': final String line,
      'close': final num close,
      'guessed': final num guessed,
    }) {
      return DondeQuedaRevealDocument(
        week: week,
        line: line,
        close: close.toInt(),
        guessed: guessed.toInt(),
      );
    }
    throw const FormatException('the reveal has another shape');
  }
}

/// {@template donde_queda_view_document}
/// `rondas/{id}/views/donde_queda`: this week's game and last week's
/// answer, each `null` when there is none. Read by the ronda's members.
/// {@endtemplate}
class const DondeQuedaViewDocument({
  final DondeQuedaCurrentDocument? current,
  final DondeQuedaRevealDocument? reveal,
}) {
  /// {@macro donde_queda_view_document}
  this;

  /// Reads the view.
  ///
  /// Throws a [FormatException] when `current` or `reveal` has another
  /// shape.
  factory fromJson(Map<String, dynamic> json) => DondeQuedaViewDocument(
    current: switch (json['current']) {
      null => null,
      final current => DondeQuedaCurrentDocument.fromJson(current),
    },
    reveal: switch (json['reveal']) {
      null => null,
      final reveal => DondeQuedaRevealDocument.fromJson(reveal),
    },
  );
}

/// {@template donde_queda_player_document}
/// `rondas/{id}/donde_queda_players/{uid}`: where one member stands in a
/// week's game. Only that member reads it.
/// {@endtemplate}
class const DondeQuedaPlayerDocument({
  /// The game's ISO week.
  required final String week,

  /// Whether it is their turn to take the photo.
  required final bool asked,

  /// Whether they posted it.
  required final bool posted,

  /// Whether they dropped their pin.
  required final bool guessed,
}) {
  /// {@macro donde_queda_player_document}
  this;

  /// Reads the card; a missing flag reads as `false`.
  ///
  /// Throws a [FormatException] without a week.
  factory fromJson(Map<String, dynamic> json) {
    if (json case {'week': final String week}) {
      return DondeQuedaPlayerDocument(
        week: week,
        asked: json['asked'] == true,
        posted: json['posted'] == true,
        guessed: json['guessed'] == true,
      );
    }
    throw const FormatException('the card has no week');
  }
}
