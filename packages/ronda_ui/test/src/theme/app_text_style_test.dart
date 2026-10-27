import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

void main() {
  group(AppTextStyle, () {
    const titleFamily = 'packages/ronda_ui/YoungSerif';
    const textFamily = 'packages/ronda_ui/AtkinsonHyperlegible';

    test('sets titles in Young Serif from the package', () {
      for (final style in [
        AppTextStyle.displayLarge,
        AppTextStyle.displayMedium,
        AppTextStyle.displaySmall,
        AppTextStyle.headlineMedium,
        AppTextStyle.headlineSmall,
        AppTextStyle.titleLarge,
      ]) {
        expect(style.fontFamily, titleFamily);
      }
    });

    test('sets everything else in Atkinson Hyperlegible', () {
      for (final style in [
        AppTextStyle.headlineLarge,
        AppTextStyle.titleMedium,
        AppTextStyle.titleSmall,
        AppTextStyle.bodyLarge,
        AppTextStyle.bodyMedium,
        AppTextStyle.bodySmall,
        AppTextStyle.labelLarge,
        AppTextStyle.labelMedium,
        AppTextStyle.labelSmall,
      ]) {
        expect(style.fontFamily, textFamily);
      }
    });

    test('keeps body text at 17 and 18 with line height 1.45', () {
      expect(AppTextStyle.bodyMedium.fontSize, 17);
      expect(AppTextStyle.bodyLarge.fontSize, 18);
      expect(AppTextStyle.bodyMedium.height, 1.45);
    });

    test('tracks titles at -0.02 em', () {
      expect(AppTextStyle.displayMedium.fontSize, 36);
      expect(AppTextStyle.displayMedium.letterSpacing, closeTo(-0.72, 1e-9));
    });

    test('carries tabular figures for times', () {
      expect(
        AppTextStyle.headlineLarge.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    test('fills every $TextTheme slot', () {
      final textTheme = AppTextStyle.textTheme;
      expect(textTheme.displayLarge, AppTextStyle.displayLarge);
      expect(textTheme.displayMedium, AppTextStyle.displayMedium);
      expect(textTheme.displaySmall, AppTextStyle.displaySmall);
      expect(textTheme.headlineLarge, AppTextStyle.headlineLarge);
      expect(textTheme.headlineMedium, AppTextStyle.headlineMedium);
      expect(textTheme.headlineSmall, AppTextStyle.headlineSmall);
      expect(textTheme.titleLarge, AppTextStyle.titleLarge);
      expect(textTheme.titleMedium, AppTextStyle.titleMedium);
      expect(textTheme.titleSmall, AppTextStyle.titleSmall);
      expect(textTheme.bodyLarge, AppTextStyle.bodyLarge);
      expect(textTheme.bodyMedium, AppTextStyle.bodyMedium);
      expect(textTheme.bodySmall, AppTextStyle.bodySmall);
      expect(textTheme.labelLarge, AppTextStyle.labelLarge);
      expect(textTheme.labelMedium, AppTextStyle.labelMedium);
      expect(textTheme.labelSmall, AppTextStyle.labelSmall);
    });
  });
}
