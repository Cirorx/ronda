import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_api/ronda_api.dart';

void main() {
  group('failure names', () {
    test('read as their own name, whatever the build minifies', () {
      expect(
        const UnreadableVoiceNoteException().toString(),
        equals('UnreadableVoiceNoteException'),
      );
      expect(const NotAHostException().toString(), equals('NotAHostException'));
      expect(
        const NothingToCutOutException().toString(),
        equals('NothingToCutOutException'),
      );
      expect(
        const NothingToDrawException().toString(),
        equals('NothingToDrawException'),
      );
      expect(
        const NotYourTurnException().toString(),
        equals('NotYourTurnException'),
      );
      expect(
        const AlreadyGuessedException().toString(),
        equals('AlreadyGuessedException'),
      );
      expect(
        const SharedPlanGoneException().toString(),
        equals('SharedPlanGoneException'),
      );
    });
  });
}
