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

    testWidgets(
      'cross-fades over the full ${AppMotion.crossFade} when the phone '
      'removes animations',
      (tester) async {
        removeAnimations(tester);
        Widget swap(String text) =>
            RondaSwap(child: Text(text, key: ValueKey(text)));
        await tester.pumpApp(swap('Esta no'));
        expect(
          MediaQuery.disableAnimationsOf(tester.element(find.text('Esta no'))),
          isTrue,
        );

        await tester.pumpApp(swap('Vas'));
        // The first frame starts the clock.
        await tester.pump();
        await tester.pump(AppMotion.crossFade ~/ 2);

        final leaving = tester.widget<FadeTransition>(
          find
              .ancestor(
                of: find.text('Esta no'),
                matching: find.byType(FadeTransition),
              )
              .first,
        );
        expect(leaving.opacity.value, inExclusiveRange(0, 1));
        // A controller is done just after its duration.
        await tester.pump(AppMotion.crossFade ~/ 2 + _tick);
        await tester.pump();
        expect(find.text('Esta no'), findsNothing);
      },
    );

    testWidgets('lets only the new state be touched while they swap', (
      tester,
    ) async {
      final taps = <String>[];
      Widget swap(String text) => RondaSwap(
        child: TextButton(
          key: ValueKey(text),
          onPressed: () => taps.add(text),
          child: Text(text),
        ),
      );
      await tester.pumpApp(swap('Voy'));

      await tester.pumpApp(swap('Cambiar'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Voy'), warnIfMissed: false);
      await tester.tap(find.text('Cambiar'));

      expect(taps, isNot(contains('Voy')));
      expect(taps, contains('Cambiar'));
    });

    testWidgets('lays states out from the top start with topStartLayout', (
      tester,
    ) async {
      // Without the settle's scale, so positions read true mid-swap.
      Widget swap(Widget child) => MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(
            width: 200,
            child: RondaSwap(
              layoutBuilder: RondaSwap.topStartLayout,
              child: child,
            ),
          ),
        ),
      );
      await tester.pumpApp(
        swap(const SizedBox(key: ValueKey('tall'), height: 200)),
      );

      await tester.pumpApp(swap(const Text('corto', key: ValueKey('short'))));
      await tester.pump(const Duration(milliseconds: 50));

      final origin = tester.getTopLeft(find.byType(RondaSwap));
      expect(tester.getTopLeft(find.text('corto')), origin);
      expect(tester.getSize(find.text('corto')).width, 200);
    });

    testWidgets('keeps the state of a child that only changes', (tester) async {
      await tester.pumpApp(buildSubject('Esta no'));

      await tester.pumpApp(
        const MediaQuery(
          data: MediaQueryData(),
          child: RondaSwap(child: Text('Esta no!', key: ValueKey('Esta no'))),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Esta no!'), findsOneWidget);
      expect(find.text('Esta no'), findsNothing);
    });

    testWidgets('cross-fades the next swap once motion is reduced', (
      tester,
    ) async {
      await tester.pumpApp(buildSubject('Esta no'));
      await tester.pumpApp(buildSubject('Esta no', reduced: true));

      await tester.pumpApp(buildSubject('Vas', reduced: true));
      await tester.pump();
      await tester.pump(AppMotion.crossFade + _tick);
      await tester.pump();

      expect(find.text('Esta no'), findsNothing);
    });

    testWidgets('lets go of a swap when it is removed mid-way', (tester) async {
      await tester.pumpApp(buildSubject('Esta no'));
      await tester.pumpApp(buildSubject('Vas'));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpApp(const SizedBox());
      await tester.pump(AppMotion.standardDuration);

      expect(tester.takeException(), isNull);
    });
  });
}

/// One millisecond: a controller is done only once its time has passed.
const _tick = Duration(milliseconds: 1);
