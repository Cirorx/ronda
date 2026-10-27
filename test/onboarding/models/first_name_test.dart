import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/onboarding/onboarding.dart';

void main() {
  group(FirstName, () {
    test('pure starts empty and untouched', () {
      const name = FirstName.pure();
      expect(name.value, isEmpty);
      expect(name.isPure, isTrue);
    });

    group('validator', () {
      for (final valid in const [
        'Marta',
        'María José',
        'Ñandú',
        "D'Angelo",
        'Ana-Laura',
        '  Facu  ',
      ]) {
        test('accepts "$valid"', () {
          expect(FirstName.dirty(valid).isValid, isTrue);
        });
      }

      test('rejects an empty or blank name', () {
        expect(
          const FirstName.dirty().error,
          equals(FirstNameValidationError.empty),
        );
        expect(
          const FirstName.dirty('   ').error,
          equals(FirstNameValidationError.empty),
        );
      });

      test('rejects names longer than ${FirstName.maxLength} letters', () {
        expect(
          FirstName.dirty('a' * (FirstName.maxLength + 1)).error,
          equals(FirstNameValidationError.tooLong),
        );
        expect(FirstName.dirty('a' * FirstName.maxLength).isValid, isTrue);
      });

      for (final invalid in const ['Marta2', 'ana@mail', '-Ana', 'Ana!']) {
        test('rejects "$invalid"', () {
          expect(
            FirstName.dirty(invalid).error,
            equals(FirstNameValidationError.invalid),
          );
        });
      }
    });

    test('name drops leading and trailing spaces', () {
      expect(const FirstName.dirty('  Marta ').name, equals('Marta'));
    });
  });
}
