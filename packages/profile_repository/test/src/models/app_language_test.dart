import 'package:flutter_test/flutter_test.dart';
import 'package:profile_repository/profile_repository.dart';

void main() {
  group(AppLanguage, () {
    test('stores Spanish as es and English as en', () {
      expect(
        AppLanguage.values.map((language) => language.id),
        equals(['es', 'en']),
      );
    });

    test('fromId reads every id back and returns null otherwise', () {
      for (final language in AppLanguage.values) {
        expect(AppLanguage.fromId(language.id), equals(language));
      }
      expect(AppLanguage.fromId('fr'), isNull);
      expect(AppLanguage.fromId(null), isNull);
    });
  });
}
