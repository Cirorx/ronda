import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(RondaPageTransitionsBuilder, () {
    const nextKey = Key('next');

    Future<void> push(WidgetTester tester, {bool reduced = false}) async {
      if (reduced) {
        // The setting reaches every route, and also shortens the framework's
        // own animations twentyfold.
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      await tester.pumpApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: SizedBox(key: nextKey)),
              ),
            ),
            child: const Text('Seguir'),
          ),
        ),
      );
      await tester.tap(find.text('Seguir'));
      await tester.pump();
      await tester.pump(Duration(milliseconds: reduced ? 5 : 100));
    }

    testWidgets('takes as long as the platform slide', (tester) async {
      expect(
        const RondaPageTransitionsBuilder().transitionDuration,
        const Duration(milliseconds: 500),
      );
    });

    testWidgets('brings a pushed screen in from the right', (tester) async {
      await push(tester);

      final left = tester.getTopLeft(find.byKey(nextKey)).dx;
      expect(left, greaterThan(0));
      expect(left, lessThan(phoneSize.width));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(nextKey)).dx, 0);
    });

    testWidgets('takes it back out to the right', (tester) async {
      await push(tester);
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byKey(nextKey))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.getTopLeft(find.byKey(nextKey)).dx, greaterThan(0));
      await tester.pumpAndSettle();
      expect(find.byKey(nextKey), findsNothing);
    });

    testWidgets('cross-fades in place with reduced motion', (tester) async {
      await push(tester, reduced: true);

      expect(tester.getTopLeft(find.byKey(nextKey)).dx, 0);
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(nextKey),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
    });
  });
}
