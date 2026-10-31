import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(ReadableColumn, () {
    const content = Key('content');
    const subject = ReadableColumn(child: SizedBox.expand(key: content));

    testWidgets('leaves a phone edge to edge, without a margin line', (
      tester,
    ) async {
      await tester.pumpApp(subject);

      expect(tester.getSize(find.byKey(content)).width, phoneSize.width);
      expect(find.byType(RuledMargin), findsNothing);
    });

    for (final size in [tabletSize, desktopSize]) {
      testWidgets('centres a readable column on a ${size.width} px window', (
        tester,
      ) async {
        await tester.pumpApp(subject, size: size);

        final rect = tester.getRect(find.byKey(content));
        expect(rect.width, WindowSize.readableWidth);
        expect(rect.center.dx, size.width / 2);
        expect(find.byType(RuledMargin), findsOneWidget);
      });
    }

    testWidgets('takes a narrower width when given one', (tester) async {
      const width = 400.0;
      const child = SizedBox.expand(key: content);
      await tester.pumpApp(
        // Built at run time, not as a constant.
        // ignore: prefer_const_constructors
        ReadableColumn(maxWidth: width, child: child),
        size: desktopSize,
      );

      expect(tester.getSize(find.byKey(content)).width, 400);
    });
  });

  group(RuledMargin, () {
    testWidgets('draws the margin line in margen and stays out of semantics', (
      tester,
    ) async {
      await tester.pumpApp(const RuledMargin(child: Text('Hola')));

      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text('Hola'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final border =
          (box.decoration as BoxDecoration).border! as BorderDirectional;
      expect(
        border.start.color,
        AppColors.margen.withValues(alpha: PersonRow.marginLineOpacity),
      );
      expect(
        tester.getSemantics(find.text('Hola')),
        isSemantics(label: 'Hola'),
      );
    });
  });
}
