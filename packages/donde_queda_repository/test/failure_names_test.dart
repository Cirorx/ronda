import 'package:donde_queda_repository/donde_queda_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('failure names', () {
    test('read as their own name, whatever the build minifies', () {
      expect(const TakePhotoFailure().toString(), equals('TakePhotoFailure'));
      expect(const BlurPhotoFailure().toString(), equals('BlurPhotoFailure'));
      expect(
        const PhotoRefusedFailure(PhotoRefusal.houseNumber).toString(),
        equals('PhotoRefusedFailure(houseNumber)'),
      );
      expect(
        const NotYourTurnFailure().toString(),
        equals('NotYourTurnFailure'),
      );
      expect(
        const AlreadyGuessedFailure().toString(),
        equals('AlreadyGuessedFailure'),
      );
      expect(const DondeQuedaFailure().toString(), equals('DondeQuedaFailure'));
    });
  });
}
