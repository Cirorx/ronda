import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(RondaSwap, () {
    Widget buildSubject(String text, {bool reduced = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: RondaSwap(child: Text(text, key: ValueKey(text))),
    );

    testWidgets('shows its child', (tester) async {
      await tester.pumpApp(buildSubject('Esta no'));

      expect(find.text('Esta no'), findsOneWidget);
    });

    testWidgets('settles the new state in with a scale', (tester) async {
      await tester.pumpApp(buildSubject('Esta no'));

      await tester.pumpApp(buildSubject('Vas'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Esta no'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Vas'),
          matching: find.byType(ScaleTransition),
        ),
        findsWidgets,
      );
      await tester.pumpAndSettle();
      expect(find.text('Esta no'), findsNothing);
      expect(find.text('Vas'), findsOneWidget);
    });

    testWidgets('reads out only the current state', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(buildSubject('Esta no'));

      await tester.pumpApp(buildSubject('Vas'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.semantics.byLabel('Vas'), findsOne);
      expect(find.semantics.byLabel('Esta no'), findsNothing);
      semantics.dispose();
    });

    testWidgets('only cross-fades with reduced motion', (tester) async {
      await tester.pumpApp(buildSubject('Esta no', reduced: true));

      await tester.pumpApp(buildSubject('Vas', reduced: true));
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.ancestor(
          of: find.text('Vas'),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text('Vas'),
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
      );
      await tester.pump(AppMotion.crossFade);
      expect(find.text('Esta no'), findsNothing);
    });
  });
}
