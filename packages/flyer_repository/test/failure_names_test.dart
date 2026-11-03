import 'package:flutter_test/flutter_test.dart';
import 'package:flyer_repository/flyer_repository.dart';

void main() {
  group('failure names', () {
    test('read as their own name, whatever the build minifies', () {
      expect(const TakePhotoFailure().toString(), equals('TakePhotoFailure'));
      expect(const BlurPhotoFailure().toString(), equals('BlurPhotoFailure'));
      expect(const NotAHostFailure().toString(), equals('NotAHostFailure'));
      expect(
        const NothingToCutOutFailure().toString(),
        equals('NothingToCutOutFailure'),
      );
      expect(const MakeFlyerFailure().toString(), equals('MakeFlyerFailure'));
      expect(const ShareFlyerFailure().toString(), equals('ShareFlyerFailure'));
    });
  });
}
