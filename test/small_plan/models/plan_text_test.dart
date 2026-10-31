import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/small_plan/models/models.dart';

void main() {
  group(PlanText, () {
    test('is untouched until the person types', () {
      expect(const PlanText.pure().isPure, isTrue);
      expect(const PlanText.dirty('x').isPure, isFalse);
    });

    test('needs something besides spaces', () {
      expect(
        const PlanText.dirty('   ').error,
        equals(PlanTextValidationError.empty),
      );
      expect(const PlanText.dirty('caminar').isValid, isTrue);
    });

    test('reads the words without the spaces around them', () {
      expect(const PlanText.dirty('  caminar  ').words, equals('caminar'));
    });

    test('is too long past ${PlanText.maxLength} characters', () {
      expect(PlanText.dirty('a' * PlanText.maxLength).isValid, isTrue);
      expect(
        PlanText.dirty('a' * (PlanText.maxLength + 1)).error,
        equals(PlanTextValidationError.tooLong),
      );
    });
  });
}
