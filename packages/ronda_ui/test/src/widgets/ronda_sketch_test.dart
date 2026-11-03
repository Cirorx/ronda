import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(RondaSketch, () {
    Finder canvas() => find.descendant(
      of: find.byType(RondaSketch),
      matching: find.byType(CustomPaint),
    );

    for (final scene in RondaScene.values) {
      testWidgets('draws ${scene.name} at its height and width', (
        tester,
      ) async {
        await tester.pumpApp(Center(child: RondaSketch(scene, height: 96)));

        expect(
          tester.getSize(find.byType(RondaSketch)),
          Size(96 * scene.width / RondaSketch.grid, 96),
        );
        expect(
          find.byType(RondaSketch),
          paints..scale(x: 96 / RondaSketch.grid),
        );
      });
    }

    testWidgets('takes the default height', (tester) async {
      await tester.pumpApp(
        const Center(child: RondaSketch(RondaScene.mateServed)),
      );

      expect(
        tester.getSize(find.byType(RondaSketch)).height,
        RondaSketch.defaultHeight,
      );
    });

    testWidgets('shrinks to fit a narrow room, keeping its shape', (
      tester,
    ) async {
      await tester.pumpApp(
        const Center(
          child: SizedBox(
            width: 120,
            child: RondaSketch(RondaScene.objectsOnALine),
          ),
        ),
      );

      final size = tester.getSize(canvas());
      expect(size.width, 120);
      expect(
        size.height,
        closeTo(120 * RondaSketch.grid / RondaScene.objectsOnALine.width, 0.01),
      );
    });

    testWidgets('keeps its own size inside a stretched column', (tester) async {
      await tester.pumpApp(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RondaSketch(RondaScene.termoStamp, height: RondaSketch.cardHeight),
          ],
        ),
      );

      expect(
        tester.getSize(canvas()),
        const Size.square(RondaSketch.cardHeight),
      );
    });

    testWidgets('draws the taken chair in the primary colour', (tester) async {
      await tester.pumpApp(
        const Center(child: RondaSketch(RondaScene.emptyChairs)),
        theme: AppTheme.dark,
      );

      expect(
        find.byType(RondaSketch),
        paints..rrect(color: AppColors.biromeDark),
      );
    });

    testWidgets('is decoration', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const Center(child: RondaSketch(RondaScene.firstLine)),
      );

      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
      handle.dispose();
    });

    testWidgets('is dropped at large text', (tester) async {
      await tester.pumpApp(
        const Center(child: RondaSketch(RondaScene.openCuaderno)),
        textScale: AppTheme.largeTextScale,
      );

      expect(canvas(), findsNothing);
    });

    testWidgets('repaints only when the scene or the theme changes', (
      tester,
    ) async {
      Future<CustomPainter> painterFor(
        Widget sketch, {
        ThemeData? theme,
      }) async {
        await tester.pumpApp(Center(child: sketch), theme: theme);
        // The app's theme eases from one to the next.
        await tester.pumpAndSettle();
        return tester.widget<CustomPaint>(canvas()).painter!;
      }

      final mate = await painterFor(const RondaSketch(RondaScene.mateServed));
      final sameMate = await painterFor(
        const RondaSketch(RondaScene.mateServed),
      );
      final chairs = await painterFor(
        const RondaSketch(RondaScene.emptyChairs),
      );
      final darkMate = await painterFor(
        const RondaSketch(RondaScene.mateServed),
        theme: AppTheme.dark,
      );

      expect(sameMate.shouldRepaint(mate), isFalse);
      expect(chairs.shouldRepaint(mate), isTrue);
      expect(darkMate.shouldRepaint(mate), isTrue);
    });
  });
}
