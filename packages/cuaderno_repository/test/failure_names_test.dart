import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('failure names', () {
    test('read as their own name, whatever the build minifies', () {
      expect(
        const NothingToDrawFailure().toString(),
        equals('NothingToDrawFailure'),
      );
      expect(
        const MakePostcardFailure().toString(),
        equals('MakePostcardFailure'),
      );
      expect(
        const SharePostcardFailure().toString(),
        equals('SharePostcardFailure'),
      );
    });
  });
}
