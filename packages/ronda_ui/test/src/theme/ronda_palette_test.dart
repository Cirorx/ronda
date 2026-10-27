import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

void main() {
  group(RondaPalette, () {
    const subject = RondaPalette.light;
    const black = Color(0xFF000000);

    group('copyWith', () {
      test('returns the same values when nothing is given', () {
        final copy = subject.copyWith();
        expect(copy.yerba, subject.yerba);
        expect(copy.ambar, subject.ambar);
        expect(copy.margen, subject.margen);
        expect(copy.danger, subject.danger);
        expect(copy.biromeTint, subject.biromeTint);
        expect(copy.ambarTint, subject.ambarTint);
        expect(copy.yerbaTint, subject.yerbaTint);
        expect(copy.neutralTint, subject.neutralTint);
        expect(copy.biromePressed, subject.biromePressed);
        expect(copy.neutralFill, subject.neutralFill);
        expect(copy.controlOff, subject.controlOff);
      });

      test('replaces every given value', () {
        final copy = subject.copyWith(
          yerba: black,
          ambar: black,
          margen: black,
          danger: black,
          biromeTint: black,
          ambarTint: black,
          yerbaTint: black,
          neutralTint: black,
          biromePressed: black,
          neutralFill: black,
          controlOff: black,
        );
        expect([
          copy.yerba,
          copy.ambar,
          copy.margen,
          copy.danger,
          copy.biromeTint,
          copy.ambarTint,
          copy.yerbaTint,
          copy.neutralTint,
          copy.biromePressed,
          copy.neutralFill,
          copy.controlOff,
        ], everyElement(black));
      });
    });

    group('lerp', () {
      test('returns this when other is null', () {
        expect(subject.lerp(null, 0.5), same(subject));
      });

      test('returns the night palette at t = 1', () {
        final result = subject.lerp(RondaPalette.dark, 1);
        expect(result.yerba, AppColors.yerbaDark);
        expect(result.ambar, AppColors.ambarDark);
        expect(result.margen, AppColors.margenDark);
        expect(result.danger, AppColors.dangerDark);
        expect(result.biromeTint, AppColors.biromeTintDark);
        expect(result.ambarTint, AppColors.ambarTintDark);
        expect(result.yerbaTint, AppColors.yerbaTintDark);
        expect(result.neutralTint, AppColors.neutralTintDark);
        expect(result.biromePressed, AppColors.biromePressedDark);
        expect(result.neutralFill, AppColors.neutralFillDark);
        expect(result.controlOff, AppColors.controlOffDark);
      });
    });
  });
}
