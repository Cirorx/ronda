import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

void main() {
  group(AppTheme, () {
    group('light', () {
      late ThemeData theme;

      setUp(() => theme = AppTheme.light);

      test('maps the day tokens onto the $ColorScheme', () {
        final scheme = theme.colorScheme;
        expect(scheme.brightness, Brightness.light);
        expect(scheme.surface, AppColors.paper);
        expect(scheme.surfaceContainer, AppColors.surface);
        expect(scheme.onSurface, AppColors.ink);
        expect(scheme.primary, AppColors.birome);
        expect(scheme.tertiary, AppColors.yerba);
        expect(scheme.secondary, AppColors.ambar);
        expect(scheme.error, AppColors.danger);
        expect(scheme.outlineVariant, AppColors.line);
        expect(scheme.onSurfaceVariant, AppColors.muted);
        expect(theme.scaffoldBackgroundColor, AppColors.paper);
      });

      test('registers the day $RondaPalette and $AppSpacing', () {
        expect(theme.extension<RondaPalette>(), RondaPalette.light);
        expect(theme.extension<AppSpacing>(), isA<AppSpacing>());
      });

      test('uses $AppTextStyle for the text theme', () {
        expect(
          theme.textTheme.displayMedium?.fontFamily,
          AppTextStyle.displayMedium.fontFamily,
        );
        expect(theme.textTheme.bodyMedium?.fontSize, 17);
      });

      test('presses the filled button to birome pressed', () {
        final background = theme.filledButtonTheme.style!.backgroundColor!;
        expect(
          background.resolve({WidgetState.pressed}),
          AppColors.biromePressed,
        );
        expect(background.resolve({}), isNull);
      });

      test('gives every button a 48 dp minimum', () {
        for (final style in [
          theme.filledButtonTheme.style!,
          theme.outlinedButtonTheme.style!,
          theme.textButtonTheme.style!,
          theme.iconButtonTheme.style!,
        ]) {
          final size = style.minimumSize!.resolve({})!;
          expect(size.height, greaterThanOrEqualTo(AppTheme.minTarget));
          expect(size.width, greaterThanOrEqualTo(AppTheme.minTarget));
        }
      });

      test('borders a chip in birome only when selected', () {
        final side = theme.chipTheme.side! as WidgetStateBorderSide;
        expect(side.resolve({WidgetState.selected})?.color, AppColors.birome);
        expect(side.resolve({})?.color, AppColors.line);
      });

      test('colours chip labels by state', () {
        final color = theme.chipTheme.labelStyle!.color! as WidgetStateColor;
        expect(color.resolve({WidgetState.disabled}), AppColors.muted);
        expect(color.resolve({WidgetState.selected}), AppColors.birome);
        expect(color.resolve({}), AppColors.ink);
      });

      test('marks the selected tab in birome', () {
        final nav = theme.navigationBarTheme;
        expect(
          nav.iconTheme!.resolve({WidgetState.selected})?.color,
          AppColors.birome,
        );
        expect(nav.iconTheme!.resolve({})?.color, AppColors.muted);
        expect(
          nav.labelTextStyle!.resolve({WidgetState.selected})?.color,
          AppColors.birome,
        );
        expect(nav.labelTextStyle!.resolve({})?.color, AppColors.muted);
      });

      test('turns a switch track yerba when on', () {
        final track = theme.switchTheme.trackColor!;
        expect(track.resolve({WidgetState.selected}), AppColors.yerba);
        expect(track.resolve({}), AppColors.controlOff);
      });

      test('fills a radio in birome when selected', () {
        final fill = theme.radioTheme.fillColor!;
        expect(fill.resolve({WidgetState.selected}), AppColors.birome);
        expect(fill.resolve({}), AppColors.controlOff);
      });
    });

    group('dark', () {
      late ThemeData theme;

      setUp(() => theme = AppTheme.dark);

      test('maps the night tokens onto the $ColorScheme', () {
        final scheme = theme.colorScheme;
        expect(scheme.brightness, Brightness.dark);
        expect(scheme.surface, AppColors.paperDark);
        expect(scheme.surfaceContainer, AppColors.surfaceDark);
        expect(scheme.onSurface, AppColors.inkDark);
        expect(scheme.primary, AppColors.biromeDark);
        expect(scheme.tertiary, AppColors.yerbaDark);
        expect(scheme.secondary, AppColors.ambarDark);
        expect(scheme.error, AppColors.dangerDark);
        expect(scheme.outlineVariant, AppColors.lineDark);
        expect(scheme.onSurfaceVariant, AppColors.mutedDark);
      });

      test('registers the night $RondaPalette', () {
        expect(theme.extension<RondaPalette>(), RondaPalette.dark);
      });
    });
  });
}
