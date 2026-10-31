import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(ScrollEdgeFade, () {
    Widget buildSubject({required double contentHeight, bool enabled = true}) =>
        SizedBox(
          height: 300,
          child: ScrollEdgeFade(
            enabled: enabled,
            child: ListView(children: [SizedBox(height: contentHeight)]),
          ),
        );

    double fadeOpacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: find.byType(ScrollEdgeFade),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    testWidgets('fades the bottom edge while there is more below', (
      tester,
    ) async {
      await tester.pumpApp(buildSubject(contentHeight: 1000));
      await tester.pumpAndSettle();

      expect(fadeOpacity(tester), 1);
      final fade = find.descendant(
        of: find.byType(ScrollEdgeFade),
        matching: find.byType(DecoratedBox),
      );
      expect(tester.getSize(fade).height, AppSpacing.unit * 2);
      expect(
        tester.getBottomLeft(fade).dy,
        tester.getBottomLeft(find.byType(ListView)).dy,
      );
    });

    testWidgets('shows nothing once scrolled to the end', (tester) async {
      await tester.pumpApp(buildSubject(contentHeight: 1000));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(fadeOpacity(tester), 0);
    });

    testWidgets('shows nothing when the content fits', (tester) async {
      await tester.pumpApp(buildSubject(contentHeight: 100));
      await tester.pumpAndSettle();

      expect(fadeOpacity(tester), 0);
    });

    testWidgets('comes in over ${AppMotion.crossFade.inMilliseconds} ms', (
      tester,
    ) async {
      await tester.pumpApp(buildSubject(contentHeight: 1000));

      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration,
        AppMotion.crossFade,
      );
    });

    testWidgets('lets taps and screen readers through to the content', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpApp(
        SizedBox(
          height: 300,
          child: ScrollEdgeFade(
            child: ListView(
              children: [
                const SizedBox(height: 270),
                TextButton(
                  onPressed: () => taps++,
                  child: const Text('Seguir'),
                ),
                const SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(180, 290));
      expect(taps, 1);
      expect(find.bySemanticsLabel('Seguir'), findsOneWidget);
    });

    testWidgets('ignores scroll views nested inside the content', (
      tester,
    ) async {
      await tester.pumpApp(
        SizedBox(
          height: 300,
          child: ScrollEdgeFade(
            child: ListView(
              children: [
                SizedBox(
                  height: 100,
                  child: ListView(children: const [SizedBox(height: 1000)]),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fadeOpacity(tester), 0);
    });

    testWidgets('is its content alone when off', (tester) async {
      await tester.pumpApp(buildSubject(contentHeight: 1000, enabled: false));

      expect(
        find.descendant(
          of: find.byType(ScrollEdgeFade),
          matching: find.byType(AnimatedOpacity),
        ),
        findsNothing,
      );
    });
  });
}
