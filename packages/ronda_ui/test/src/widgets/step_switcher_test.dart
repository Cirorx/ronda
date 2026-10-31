import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(StepSwitcher, () {
    Widget step(int number) => Center(
      child: TextButton(onPressed: () {}, child: Text('paso $number')),
    );

    Widget buildSubject(int open, {bool Function(int from, int to)? forward}) =>
        StepSwitcher<int>(
          step: open,
          forward: forward ?? (from, to) => to > from,
          child: Builder(
            builder: (context) => Column(
              children: [
                Text('desde ${StepSwitcher.previousOf<int>(context)}'),
                Expanded(child: step(open)),
              ],
            ),
          ),
        );

    /// How far across the step [number] is, as a share of the width.
    double across(WidgetTester tester, int number) => tester
        .widget<SlideTransition>(
          find
              .ancestor(
                of: find.text('paso $number'),
                matching: find.byType(SlideTransition),
              )
              .first,
        )
        .position
        .value
        .dx;

    testWidgets('shows the open step', (tester) async {
      await tester.pumpApp(buildSubject(1));

      expect(find.text('paso 1'), findsOneWidget);
      expect(find.text('desde null'), findsOneWidget);
    });

    testWidgets('tells the new step which one came before', (tester) async {
      await tester.pumpApp(buildSubject(1));

      await tester.pumpApp(buildSubject(2));
      await tester.pumpAndSettle();

      expect(find.text('paso 2'), findsOneWidget);
      expect(find.text('paso 1'), findsNothing);
      expect(find.text('desde 1'), findsOneWidget);
    });

    testWidgets('brings a step forward in from the end side', (tester) async {
      await tester.pumpApp(buildSubject(1));

      await tester.pumpApp(buildSubject(2));
      await tester.pump(const Duration(milliseconds: 50));

      expect(across(tester, 2), inExclusiveRange(0, 1));
      expect(across(tester, 1), inExclusiveRange(-StepSwitcher.drift, 0));
    });

    testWidgets('takes a step back out the way it came', (tester) async {
      await tester.pumpApp(buildSubject(2));

      await tester.pumpApp(buildSubject(1));
      await tester.pump(const Duration(milliseconds: 50));

      expect(across(tester, 2), inExclusiveRange(0, 1));
      expect(across(tester, 1), inExclusiveRange(-StepSwitcher.drift, 0));
    });

    testWidgets('moves forward when it is not told which way', (tester) async {
      await tester.pumpApp(StepSwitcher<int>(step: 2, child: step(2)));

      await tester.pumpApp(StepSwitcher<int>(step: 1, child: step(1)));
      await tester.pump(const Duration(milliseconds: 50));

      expect(across(tester, 1), inExclusiveRange(0, 1));
    });

    testWidgets('lets only the new step be read and touched', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(buildSubject(1));

      await tester.pumpApp(buildSubject(2));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('paso 1'), findsOneWidget);
      expect(find.semantics.byLabel('paso 2'), findsOne);
      expect(find.semantics.byLabel('paso 1'), findsNothing);
      final leaving = tester.widget<IgnorePointer>(
        find
            .ancestor(
              of: find.text('paso 1'),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(leaving.ignoring, isTrue);
      semantics.dispose();
    });

    testWidgets('slides in from the left in a right-to-left language', (
      tester,
    ) async {
      Widget rtl(int open) => Directionality(
        textDirection: TextDirection.rtl,
        child: buildSubject(open),
      );
      await tester.pumpApp(rtl(1));

      await tester.pumpApp(rtl(2));
      await tester.pump(const Duration(milliseconds: 50));

      expect(across(tester, 2), inExclusiveRange(-1, 0));
    });

    testWidgets(
      'only cross-fades, over the full ${AppMotion.crossFade}, when the '
      'phone removes animations',
      (tester) async {
        removeAnimations(tester);
        await tester.pumpApp(buildSubject(1));

        await tester.pumpApp(buildSubject(2));
        // The first frame starts the clock.
        await tester.pump();
        await tester.pump(AppMotion.crossFade ~/ 2);

        expect(find.byType(SlideTransition), findsNothing);
        final leaving = tester.widget<FadeTransition>(
          find
              .ancestor(
                of: find.text('paso 1'),
                matching: find.byType(FadeTransition),
              )
              .first,
        );
        expect(leaving.opacity.value, inExclusiveRange(0, 1));
        // A controller is done just after its duration.
        await tester.pump(AppMotion.crossFade ~/ 2 + _tick);
        await tester.pump();
        expect(find.text('paso 1'), findsNothing);
      },
    );

    testWidgets('changes at once while the page itself is coming in', (
      tester,
    ) async {
      final open = ValueNotifier(1);
      addTearDown(open.dispose);
      await tester.pumpApp(const SizedBox());
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));

      navigator
          .push(
            MaterialPageRoute<void>(
              builder: (_) => ValueListenableBuilder(
                valueListenable: open,
                builder: (_, number, _) => buildSubject(number),
              ),
            ),
          )
          .ignore();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      open.value = 3;
      await tester.pump();

      expect(find.text('paso 1'), findsNothing);
      expect(find.text('paso 3'), findsOneWidget);
    });
  });
}

/// One millisecond: a controller is done only once its time has passed.
const _tick = Duration(milliseconds: 1);
