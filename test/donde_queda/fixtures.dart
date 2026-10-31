import 'dart:typed_data';

import 'package:donde_queda_repository/donde_queda_repository.dart';

/// Invented data for the ¿Dónde queda? tests.
abstract final class DondeQuedaFixtures {
  static const uid = 'demo-uid';
  static const rondaId = 'ronda-1';
  static const week = '2026-W45';
  static const centre = MapPoint(-34.8, -55.885);
  static const pin = MapPoint(-34.801, -55.884);

  /// This week's game: the member's turn by default.
  static DondeQuedaGame game({
    DondeQuedaStatus status = DondeQuedaStatus.asking,
    bool isMyTurn = true,
    bool posted = false,
    bool guessed = false,
    String? photoPath,
    String hint = '',
  }) => DondeQuedaGame(
    week: week,
    status: status,
    centre: centre,
    zoom: 16,
    closesOn: DateTime(2026, 11, 5),
    photoPath: photoPath,
    hint: hint,
    isMyTurn: isMyTurn,
    posted: posted,
    guessed: guessed,
  );

  /// An open game to guess.
  static DondeQuedaGame open({bool posted = false, bool guessed = false}) =>
      game(
        status: DondeQuedaStatus.open,
        isMyTurn: false,
        posted: posted,
        guessed: guessed,
        photoPath: 'donde_queda/ronda-1/2026-W45.jpg',
        hint: 'cerca de la feria',
      );

  static const reveal = DondeQuedaReveal(
    line: 'la puerta verde de Gestido y Rivera',
    close: 3,
    guessed: 5,
  );

  static final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
}
