import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(FocusRing, () {
    const surfaceKey = Key('surface');

    Widget buildSubject({
      BorderRadius borderRadius = const BorderRadius.all(
        Radius.circular(AppRadius.md),
      ),
    }) => Center(
      child: FocusRing(
        borderRadius: borderRadius,
        child: InkWell(
          onTap: () {},
          child: const SizedBox(key: surfaceKey, width: 120, height: 48),
        ),
      ),
    );

    Finder ringPaint() => find.descendant(
      of: find.byType(FocusRing),
      matching: find.byType(CustomPaint),
    );

    bool ringShown(WidgetTester tester) =>
        tester.widget<CustomPaint>(ringPaint().first).foregroundPainter != null;

    /// The [InkWell]'s own focus node.
    FocusNode inkFocus(WidgetTester tester) =>
        Focus.of(tester.element(find.byKey(surfaceKey)));

    /// Focuses the subject from the keyboard: Tab, the one stop there is.
    Future<void> focusFromKeyboard(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }

    testWidgets('rings a control focused from a keyboard at once', (
      tester,
    ) async {
      await tester.pumpApp(buildSubject());

      await focusFromKeyboard(tester);

      // One frame, no animation: a keyboard action never animates.
      expect(ringShown(tester), isTrue);
    });

    testWidgets('draws ${AppTheme.focusRingWidth} px of primary, '
        '${AppTheme.focusRingOffset} px outside the edge', (tester) async {
      await tester.pumpApp(buildSubject());

      await focusFromKeyboard(tester);

      const outset = AppTheme.focusRingOffset + AppTheme.focusRingWidth / 2;
      final size = tester.getSize(find.byType(InkWell));
      expect(
        ringPaint().first,
        paints..rrect(
          rrect: const BorderRadius.all(Radius.circular(AppRadius.md))
              .toRRect(Offset.zero & size)
              .inflate(outset),
          color: AppColors.birome,
          strokeWidth: AppTheme.focusRingWidth,
          style: PaintingStyle.stroke,
        ),
      );
    });

    testWidgets('takes the night theme primary in the dark', (tester) async {
      await tester.pumpApp(buildSubject());
      await focusFromKeyboard(tester);

      await tester.pumpApp(buildSubject(), theme: AppTheme.dark);
      await tester.pumpAndSettle();

      expect(ringPaint().first, paints..rrect(color: AppColors.biromeDark));
    });

    testWidgets('follows a new shape', (tester) async {
      await tester.pumpApp(buildSubject());
      await focusFromKeyboard(tester);

      await tester.pumpApp(
        buildSubject(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        ),
      );

      final size = tester.getSize(find.byType(InkWell));
      expect(
        ringPaint().first,
        paints..rrect(
          rrect: const BorderRadius.all(Radius.circular(AppRadius.pill))
              .toRRect(Offset.zero & size)
              .inflate(AppTheme.focusRingOffset + AppTheme.focusRingWidth / 2),
        ),
      );
    });

    testWidgets('sits the same gap inside the edge when inset', (tester) async {
      await tester.pumpApp(
        Center(
          child: FocusRing(
            inset: true,
            child: InkWell(
              onTap: () {},
              child: const SizedBox(key: surfaceKey, width: 120, height: 48),
            ),
          ),
        ),
      );

      await focusFromKeyboard(tester);

      const gap = AppTheme.focusRingOffset + AppTheme.focusRingWidth / 2;
      expect(
        ringPaint().first,
        paints..rrect(
          rrect: const BorderRadius.all(Radius.circular(AppRadius.lg))
              .toRRect(Offset.zero & const Size(120, 48))
              .deflate(gap),
        ),
      );
    });

    testWidgets('shows nothing while nothing inside is focused', (
      tester,
    ) async {
      await tester.pumpApp(buildSubject());
      await tester.sendKeyEvent(LogicalKeyboardKey.shift);
      await tester.pump();

      expect(ringShown(tester), isFalse);
    });

    testWidgets('goes when focus leaves', (tester) async {
      await tester.pumpApp(buildSubject());
      await focusFromKeyboard(tester);

      inkFocus(tester).unfocus();
      await tester.pump();

      expect(ringShown(tester), isFalse);
    });

    testWidgets('never shows after a tap', (tester) async {
      await tester.pumpApp(buildSubject());

      await tester.tap(find.byType(InkWell));
      inkFocus(tester).requestFocus();
      await tester.pump();

      expect(inkFocus(tester).hasFocus, isTrue);
      expect(ringShown(tester), isFalse);
    });

    testWidgets('hides on a mouse click elsewhere and comes back with a key', (
      tester,
    ) async {
      await tester.pumpApp(buildSubject());
      await focusFromKeyboard(tester);

      final mouse = await tester.startGesture(
        Offset.zero,
        kind: PointerDeviceKind.mouse,
      );
      await mouse.up();
      await tester.pump();

      // Focus stays where it was, as in a browser, but unringed.
      expect(inkFocus(tester).hasFocus, isTrue);
      expect(ringShown(tester), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.shift);
      await tester.pump();

      expect(ringShown(tester), isTrue);
    });

    testWidgets('is neither a focus stop nor a node for screen readers', (
      tester,
    ) async {
      await tester.pumpApp(buildSubject());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(inkFocus(tester).hasPrimaryFocus, isTrue);
      final ringFocus = tester.widget<Focus>(
        find
            .descendant(
              of: find.byType(FocusRing),
              matching: find.byType(Focus),
            )
            .first,
      );
      expect(ringFocus.canRequestFocus, isFalse);
      expect(ringFocus.includeSemantics, isFalse);
    });
  });
}
