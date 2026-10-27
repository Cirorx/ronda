import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

void main() {
  group(AppSpacing, () {
    const subject = AppSpacing();

    test('steps 4, 8, 12, 16, 24, 32 from a unit of 16', () {
      expect(AppSpacing.unit, 16);
      expect(
        [
          subject.xxs,
          subject.xs,
          subject.sm,
          subject.md,
          subject.lg,
          subject.xlg,
        ],
        [4, 8, 12, 16, 24, 32],
      );
    });

    group('copyWith', () {
      test('returns the same values when nothing is given', () {
        final copy = subject.copyWith();
        expect(
          [copy.xxs, copy.xs, copy.sm, copy.md, copy.lg, copy.xlg],
          [4, 8, 12, 16, 24, 32],
        );
      });

      test('replaces every given value', () {
        final copy = subject.copyWith(
          xxs: 1,
          xs: 2,
          sm: 3,
          md: 4,
          lg: 5,
          xlg: 6,
        );
        expect(
          [copy.xxs, copy.xs, copy.sm, copy.md, copy.lg, copy.xlg],
          [1, 2, 3, 4, 5, 6],
        );
      });
    });

    group('lerp', () {
      test('returns this when other is null', () {
        expect(subject.lerp(null, 0.5), same(subject));
      });

      test('interpolates every step', () {
        const other = AppSpacing(
          xxs: 8,
          xs: 16,
          sm: 24,
          md: 32,
          lg: 48,
          xlg: 64,
        );
        final result = subject.lerp(other, 0.5);
        expect(
          [result.xxs, result.xs, result.sm, result.md, result.lg, result.xlg],
          [6, 12, 18, 24, 36, 48],
        );
      });
    });
  });
}
