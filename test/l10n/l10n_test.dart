import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ronda/l10n/l10n.dart';

void main() {
  group('resolveAppLocale', () {
    const es419 = Locale('es', '419');
    const en = Locale('en');

    for (final device in const [
      Locale('es', 'UY'),
      Locale('es', 'AR'),
      Locale('es', 'ES'),
      Locale('es'),
    ]) {
      test('returns es-419 for $device', () {
        expect(resolveAppLocale([device]), equals(es419));
      });
    }

    for (final device in const [Locale('en', 'US'), Locale('en', 'GB')]) {
      test('returns en for $device', () {
        expect(resolveAppLocale([device]), equals(en));
      });
    }

    test('returns en for a language Ronda does not ship', () {
      expect(resolveAppLocale(const [Locale('fr', 'FR')]), equals(en));
    });

    test('returns the first Spanish or English entry in preference order', () {
      expect(
        resolveAppLocale(const [Locale('pt', 'BR'), Locale('es', 'UY')]),
        equals(es419),
      );
      expect(
        resolveAppLocale(const [Locale('en', 'US'), Locale('es', 'UY')]),
        equals(en),
      );
    });

    test('returns en when the device reports no locales', () {
      expect(resolveAppLocale(null), equals(en));
      expect(resolveAppLocale(const []), equals(en));
    });
  });
}
