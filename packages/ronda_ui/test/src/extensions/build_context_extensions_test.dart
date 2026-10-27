import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppThemeBuildContext', () {
    for (final MapEntry(key: name, value: theme) in themes.entries) {
      testWidgets('reads the $name $RondaPalette and $AppSpacing', (
        tester,
      ) async {
        late RondaPalette palette;
        late AppSpacing spacing;
        await tester.pumpApp(
          Builder(
            builder: (context) {
              palette = context.rondaPalette;
              spacing = context.appSpacing;
              return const SizedBox.shrink();
            },
          ),
          theme: theme(),
        );

        expect(palette, theme().extension<RondaPalette>());
        expect(spacing.md, AppSpacing.unit);
      });
    }

    for (final (scale, expected) in [
      (1.0, false),
      (AppTheme.largeTextScale - 0.01, false),
      (AppTheme.largeTextScale, true),
      (2.0, true),
    ]) {
      testWidgets('usesLargeText is $expected at ${scale}x text', (
        tester,
      ) async {
        late bool usesLargeText;
        await tester.pumpApp(
          Builder(
            builder: (context) {
              usesLargeText = context.usesLargeText;
              return const SizedBox.shrink();
            },
          ),
          textScale: scale,
        );

        expect(usesLargeText, expected);
      });
    }
  });
}
