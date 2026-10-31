import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/donde_queda/models/game_text.dart';

void main() {
  group(GameText, () {
    test('collapses spaces and line breaks into one line', () {
      expect(
        const GameText.dirty('  la puerta\n verde  ').text,
        'la puerta verde',
      );
    });

    test('needs something, unless it is the optional hint', () {
      expect(const GameText.dirty('   ').error, GameTextError.empty);
      expect(const GameText.dirty('', optional: true).isValid, isTrue);
      expect(const GameText.pure().isPure, isTrue);
      expect(const GameText.pure(optional: true).optional, isTrue);
    });

    test('takes up to 80 letters', () {
      expect(GameText.dirty('x' * 80).isValid, isTrue);
      expect(GameText.dirty('x' * 81).error, GameTextError.tooLong);
    });
  });
}
