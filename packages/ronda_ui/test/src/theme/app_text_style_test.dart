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

    group('trackingFor', () {
      test('tightens large titles', () {
        expect(AppTextStyle.trackingFor(48), -0.025);
        expect(AppTextStyle.trackingFor(64), -0.025);
        expect(AppTextStyle.trackingFor(30), -0.018);
      });

      test('keeps 17 and 18 sp body at 0', () {
        expect(AppTextStyle.trackingFor(17), 0);
        expect(AppTextStyle.trackingFor(18), 0);
      });

      test('loosens small text', () {
        expect(AppTextStyle.trackingFor(13), 0.015);
        expect(AppTextStyle.trackingFor(10), 0.015);
        expect(AppTextStyle.trackingFor(14), closeTo(0.0115, 1e-9));
      });

      test('interpolates between sizes', () {
        expect(AppTextStyle.trackingFor(26), closeTo(-0.014, 1e-9));
      });
    });

    test('tracks every style for its size', () {
      for (final style in AppTextStyle.textTheme.apply().toStyles()) {
        expect(
          style.letterSpacing,
          closeTo(
            style.fontSize! * AppTextStyle.trackingFor(style.fontSize!),
            1e-9,
          ),
        );
      }
      expect(AppTextStyle.displayMedium.letterSpacing, lessThan(0));
      expect(AppTextStyle.bodyMedium.letterSpacing, 0);
      expect(AppTextStyle.labelSmall.letterSpacing, greaterThan(0));
    });

    test('sets titles tighter than body text', () {
      expect(
        AppTextStyle.displayLarge.height,
        lessThan(AppTextStyle.bodyMedium.height!),
      );
      expect(
        AppTextStyle.headlineSmall.height,
        lessThan(AppTextStyle.bodyLarge.height!),
      );
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

extension on TextTheme {
  List<TextStyle> toStyles() => [
    displayLarge!,
    displayMedium!,
    displaySmall!,
    headlineLarge!,
    headlineMedium!,
    headlineSmall!,
    titleLarge!,
    titleMedium!,
    titleSmall!,
    bodyLarge!,
    bodyMedium!,
    bodySmall!,
    labelLarge!,
    labelMedium!,
    labelSmall!,
  ];
}
