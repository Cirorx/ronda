import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

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

      test('shrinks every button shape while pressed', () {
        for (final style in [
          theme.filledButtonTheme.style!,
          theme.outlinedButtonTheme.style!,
          theme.textButtonTheme.style!,
          theme.iconButtonTheme.style!,
        ]) {
          final pressed = style.shape!.resolve({WidgetState.pressed});
          final rest = style.shape!.resolve({});
          expect(pressed, isA<PressedShape>());
          expect((pressed! as PressedShape).factor, AppMotion.pressedScale);
          expect((rest! as PressedShape).factor, 1);
          expect(style.animationDuration, AppMotion.press);
          expect(style.foregroundBuilder, isNotNull);
        }
      });

      test('lifts the top bar only once content scrolls under it', () {
        final appBar = theme.appBarTheme;
        expect(appBar.elevation, 0);
        expect(appBar.scrolledUnderElevation, AppTheme.scrolledUnderElevation);
        expect(appBar.backgroundColor, AppColors.paper);
        expect(
          appBar.shadowColor,
          AppColors.ink.withValues(alpha: AppTheme.scrolledUnderShadowOpacity),
        );
      });

      test('dims behind a sheet with an ink scrim', () {
        expect(
          theme.bottomSheetTheme.modalBarrierColor,
          AppColors.ink.withValues(alpha: AppTheme.scrimOpacity),
        );
      });

      test('moves between screens with one rule on every platform', () {
        for (final platform in TargetPlatform.values) {
          expect(
            theme.pageTransitionsTheme.builders[platform],
            isA<RondaPageTransitionsBuilder>(),
          );
        }
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

      test('marks the selected tab in birome on the rail too', () {
        final rail = theme.navigationRailTheme;
        expect(rail.selectedIconTheme?.color, AppColors.birome);
        expect(rail.unselectedIconTheme?.color, AppColors.muted);
        expect(rail.selectedLabelTextStyle?.color, AppColors.birome);
        expect(rail.unselectedLabelTextStyle?.color, AppColors.muted);
        expect(rail.labelType, NavigationRailLabelType.all);
      });

      test('rings a button focused from a keyboard', () {
        const focused = {WidgetState.focused};
        expect(
          theme.filledButtonTheme.style!.side!.resolve(focused),
          const BorderSide(
            color: AppColors.paper,
            width: AppTheme.focusRingWidth,
          ),
        );
        for (final style in [
          theme.outlinedButtonTheme.style!,
          theme.textButtonTheme.style!,
          theme.iconButtonTheme.style!,
        ]) {
          expect(
            style.side!.resolve(focused),
            const BorderSide(
              color: AppColors.birome,
              width: AppTheme.focusRingWidth,
            ),
          );
        }
      });

      test('keeps each button its own border while not focused', () {
        expect(theme.filledButtonTheme.style!.side!.resolve({}), isNull);
        expect(
          theme.outlinedButtonTheme.style!.side!.resolve({}),
          const BorderSide(
            color: AppColors.birome,
            width: AppTheme.borderWidth,
          ),
        );
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

      test('shades and dims with the night shadow colour', () {
        expect(theme.colorScheme.shadow, AppColors.shadowDark);
        expect(
          theme.bottomSheetTheme.modalBarrierColor,
          AppColors.shadowDark.withValues(alpha: AppTheme.scrimOpacity),
        );
      });
    });

    group('buttons in use', () {
      late int taps;

      setUp(() => taps = 0);

      Widget buildSubject({bool reduced = false}) => MediaQuery(
        data: MediaQueryData(size: phoneSize, disableAnimations: reduced),
        child: Center(
          child: FilledButton(
            onPressed: () => taps++,
            child: const Text('Voy'),
          ),
        ),
      );

      PressedShape shapeOf(WidgetTester tester) =>
          tester
                  .widget<Material>(
                    find.descendant(
                      of: find.byType(FilledButton),
                      matching: find.byType(Material),
                    ),
                  )
                  .shape!
              as PressedShape;

      double labelScale(WidgetTester tester) => tester
          .widget<AnimatedScale>(
            find.ancestor(
              of: find.text('Voy'),
              matching: find.byType(AnimatedScale),
            ),
          )
          .scale;

      testWidgets('shrink on touch-down, before the tap', (tester) async {
        await tester.pumpApp(buildSubject());

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Voy')),
        );
        await tester.pump();

        expect(shapeOf(tester).factor, AppMotion.pressedScale);
        expect(labelScale(tester), AppMotion.pressedScale);
        expect(taps, 0);
        await gesture.up();
        await tester.pump();
        expect(shapeOf(tester).factor, 1);
        expect(taps, 1);
      });

      testWidgets('come back when the finger drags away', (tester) async {
        await tester.pumpApp(
          ListView(children: [const SizedBox(height: 300), buildSubject()]),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Voy')),
        );
        await tester.pump(kPressTimeout);
        expect(shapeOf(tester).factor, AppMotion.pressedScale);
        await gesture.moveBy(const Offset(0, -(kTouchSlop + 20)));
        await tester.pump();

        expect(shapeOf(tester).factor, 1);
        expect(labelScale(tester), 1);
        await gesture.up();
        expect(taps, 0);
      });

      group('inside a scroll view', () {
        Widget scrolling({VoidCallback? onPressed}) => ListView(
          children: [
            const SizedBox(height: 300),
            Center(
              child: FilledButton(
                onPressed: onPressed,
                child: const Text('Voy'),
              ),
            ),
            const SizedBox(height: 1000),
          ],
        );

        testWidgets('shrink on touch-down, before the scroll is ruled out', (
          tester,
        ) async {
          await tester.pumpApp(scrolling(onPressed: () => taps++));

          final gesture = await tester.startGesture(
            tester.getCenter(find.text('Voy')),
          );
          await tester.pump();

          expect(shapeOf(tester).factor, AppMotion.pressedScale);
          expect(labelScale(tester), AppMotion.pressedScale);
          await gesture.up();
          await tester.pump();
          expect(shapeOf(tester).factor, 1);
          expect(taps, 1);
        });

        testWidgets('come back, untapped, when the touch becomes a scroll', (
          tester,
        ) async {
          await tester.pumpApp(scrolling(onPressed: () => taps++));

          final gesture = await tester.startGesture(
            tester.getCenter(find.text('Voy')),
          );
          await tester.pump();
          await gesture.moveBy(const Offset(0, -(kTouchSlop + 20)));
          await tester.pump();

          expect(shapeOf(tester).factor, 1);
          expect(labelScale(tester), 1);
          await gesture.up();
          await tester.pumpAndSettle();
          expect(shapeOf(tester).factor, 1);
          expect(taps, 0);
        });

        testWidgets('come back when the touch is cancelled', (tester) async {
          await tester.pumpApp(scrolling(onPressed: () => taps++));

          final gesture = await tester.startGesture(
            tester.getCenter(find.text('Voy')),
          );
          await tester.pump();
          await gesture.cancel();
          await tester.pump();

          expect(shapeOf(tester).factor, 1);
          expect(taps, 0);
        });

        testWidgets('stay put when disabled', (tester) async {
          await tester.pumpApp(scrolling());

          final gesture = await tester.startGesture(
            tester.getCenter(find.text('Voy')),
          );
          await tester.pump();

          expect(shapeOf(tester).factor, 1);
          await gesture.up();
        });

        testWidgets('stay put under a secondary mouse button', (tester) async {
          await tester.pumpApp(scrolling(onPressed: () => taps++));

          final gesture = await tester.startGesture(
            tester.getCenter(find.text('Voy')),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          );
          await tester.pump();

          expect(shapeOf(tester).factor, 1);
          await gesture.up();
        });

        testWidgets('take one finger at a time', (tester) async {
          await tester.pumpApp(scrolling(onPressed: () => taps++));
          final center = tester.getCenter(find.text('Voy'));

          final first = await tester.startGesture(center);
          final second = await tester.startGesture(center, pointer: 7);
          await tester.pump();
          await second.up();
          await tester.pump();

          expect(shapeOf(tester).factor, AppMotion.pressedScale);
          await first.up();
          await tester.pumpAndSettle();
          expect(shapeOf(tester).factor, 1);
        });
      });

      testWidgets('step at once with reduced motion', (tester) async {
        await tester.pumpApp(buildSubject(reduced: true));

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Voy')),
        );
        await tester.pump();

        expect(
          tester
              .widget<AnimatedScale>(
                find.ancestor(
                  of: find.text('Voy'),
                  matching: find.byType(AnimatedScale),
                ),
              )
              .duration,
          Duration.zero,
        );
        await gesture.up();
      });
    });

    group('top bar in use', () {
      Material barOf(WidgetTester tester) => tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(Material),
            )
            .first,
      );

      testWidgets('lifts with a soft shadow once content scrolls under', (
        tester,
      ) async {
        await tester.pumpApp(
          Scaffold(
            appBar: AppBar(title: const Text('Ajustes')),
            body: ListView(
              children: [
                for (var i = 0; i < 40; i++)
                  SizedBox(height: 60, child: Text('$i')),
              ],
            ),
          ),
        );

        expect(barOf(tester).elevation, 0);
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();

        expect(barOf(tester).elevation, AppTheme.scrolledUnderElevation);
        expect(barOf(tester).color, AppColors.paper);
      });
    });
  });
}
