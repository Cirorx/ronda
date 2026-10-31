import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(RondaObjectIcon, () {
    for (final object in RondaObject.values) {
      testWidgets('draws ${object.name} on its grid', (tester) async {
        await tester.pumpApp(Center(child: RondaObjectIcon(object)));

        expect(
          tester.getSize(find.byType(RondaObjectIcon)),
          const Size.square(RondaObjectIcon.grid),
        );
        expect(find.byType(RondaObjectIcon), paints..path());
      });
    }

    testWidgets('takes the size it is given', (tester) async {
      await tester.pumpApp(
        const Center(child: RondaObjectIcon(RondaObject.mate, size: 64)),
      );

      expect(
        tester.getSize(find.byType(RondaObjectIcon)),
        const Size.square(64),
      );
    });

    testWidgets("takes the icon theme's size and colour", (tester) async {
      await tester.pumpApp(
        const Center(
          child: IconTheme(
            data: IconThemeData(size: 40, color: AppColors.yerba),
            child: RondaObjectIcon(RondaObject.termo),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(RondaObjectIcon)),
        const Size.square(40),
      );
      expect(
        find.byType(RondaObjectIcon),
        paints..path(color: AppColors.yerba),
      );
    });

    testWidgets('draws in the colour it is given', (tester) async {
      await tester.pumpApp(
        const Center(
          child: RondaObjectIcon(RondaObject.pelota, color: AppColors.ambar),
        ),
      );

      expect(
        find.byType(RondaObjectIcon),
        paints..path(color: AppColors.ambar),
      );
    });

    testWidgets('is decoration without a label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const Center(child: RondaObjectIcon(RondaObject.sillas)),
      );

      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
      handle.dispose();
    });

    testWidgets('is read as an image with its label', (tester) async {
      await tester.pumpApp(
        const Center(
          child: RondaObjectIcon(
            RondaObject.bizcochos,
            semanticLabel: 'Bizcochos',
          ),
        ),
      );

      expect(find.bySemanticsLabel('Bizcochos'), findsOneWidget);
    });

    testWidgets('repaints only when the object or colour changes', (
      tester,
    ) async {
      Future<CustomPainter> painterFor(Widget icon) async {
        await tester.pumpApp(Center(child: icon));
        return tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(RondaObjectIcon),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!;
      }

      final mate = await painterFor(const RondaObjectIcon(RondaObject.mate));
      final sameMate = await painterFor(
        const RondaObjectIcon(RondaObject.mate),
      );
      final termo = await painterFor(const RondaObjectIcon(RondaObject.termo));
      final yerbaMate = await painterFor(
        const RondaObjectIcon(RondaObject.mate, color: AppColors.yerba),
      );

      expect(sameMate.shouldRepaint(mate), isFalse);
      expect(termo.shouldRepaint(mate), isTrue);
      expect(yerbaMate.shouldRepaint(mate), isTrue);
    });
  });
}
