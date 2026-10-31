import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(PaperColumns, () {
    Widget buildSubject() => PaperColumns(
      main: Column(
        children: [
          // The side column is built first in the tree's order below the
          // main one, so focus order is the widget's doing.
          TextButton(onPressed: () {}, child: const Text('Main 1')),
          TextButton(onPressed: () {}, child: const Text('Main 2')),
        ],
      ),
      side: TextButton(onPressed: () {}, child: const Text('Side')),
    );

    testWidgets('puts the side column beside the main one', (tester) async {
      await tester.pumpApp(buildSubject(), size: desktopSize);

      final main = tester.getRect(find.text('Main 1'));
      final side = tester.getRect(find.text('Side'));
      expect(side.left, greaterThan(main.right));
      expect(find.byType(RuledMargin), findsOneWidget);
    });

    testWidgets('keeps both columns centred at their widths', (tester) async {
      await tester.pumpApp(buildSubject(), size: desktopSize);

      final row = tester.getRect(find.byType(Row).first);
      const width =
          WindowSize.readableWidth + 2 * AppSpacing.unit + WindowSize.sideWidth;
      expect(row.width, width);
      expect(row.center.dx, desktopSize.width / 2);
    });

    testWidgets('moves focus through the main column before the side one', (
      tester,
    ) async {
      await tester.pumpApp(buildSubject(), size: desktopSize);

      final order = <String>[];
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus!.context!;
        order.add(
          tester
              .widget<Text>(
                find.descendant(
                  of: find.byWidget(focused.widget),
                  matching: find.byType(Text),
                ),
              )
              .data!,
        );
      }
      expect(order, ['Main 1', 'Main 2', 'Side']);
    });
  });
}
