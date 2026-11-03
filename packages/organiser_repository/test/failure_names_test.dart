import 'package:flutter_test/flutter_test.dart';
import 'package:organiser_repository/organiser_repository.dart';

void main() {
  group('failure names', () {
    test('read as their own name, whatever the build minifies', () {
      expect(
        const OrganiserFailure(OrganiserFailureReason.forbidden).toString(),
        equals('OrganiserFailure(forbidden)'),
      );
    });
  });
}
