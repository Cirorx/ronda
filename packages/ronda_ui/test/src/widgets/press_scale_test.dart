import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(PressScale, () {
    late int taps;

    setUp(() => taps = 0);

    Widget buildSubject({bool enabled = true}) => Center(
      child: PressScale(
        enabled: enabled,
        child: InkWell(
          onTap: () => taps++,
          child: const SizedBox(width: 200, height: 80),
        ),
      ),
    );

    double scaleOf(WidgetTester tester) =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    testWidgets('shrinks on touch-down, before any tap', (tester) async {
      await tester.pumpApp(buildSubject());

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InkWell)),
      );
      await tester.pump();

      expect(scaleOf(tester), AppMotion.pressedScale);
      expect(taps, 0);
      await gesture.up();
    });

    testWidgets('reaches the pressed size in ${AppMotion.press.inMilliseconds}'
        ' ms', (tester) async {
      await tester.pumpApp(buildSubject());

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InkWell)),
      );
      await tester.pump();
      await tester.pump(AppMotion.press);

      final transition = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(AnimatedScale),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(transition.scale.value, closeTo(AppMotion.pressedScale, 1e-6));
      await gesture.up();
    });

    testWidgets('grows back and taps on release', (tester) async {
      await tester.pumpApp(buildSubject());

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(scaleOf(tester), 1);
      expect(taps, 1);
    });

    testWidgets('cancels when the finger drags away', (tester) async {
      await tester.pumpApp(buildSubject());

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InkWell)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0, kTouchSlop + 1));
      await tester.pump();

      expect(scaleOf(tester), 1);
      await gesture.up();
      expect(taps, 0);
    });

    testWidgets('stays pressed within the touch slop', (tester) async {
      await tester.pumpApp(buildSubject());

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InkWell)),
      );
      await gesture.moveBy(const Offset(0, kTouchSlop / 2));
      await tester.pump();

      expect(scaleOf(tester), AppMotion.pressedScale);
      await gesture.up();
    });

    testWidgets('grows back when the pointer is cancelled', (tester) async {
      await tester.pumpApp(buildSubject());

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InkWell)),
      );
      await tester.pump();
      await gesture.cancel();
      await tester.pump();

      expect(scaleOf(tester), 1);
    });

    testWidgets('follows only the first finger', (tester) async {
      await tester.pumpApp(buildSubject());
      final center = tester.getCenter(find.byType(InkWell));

      final first = await tester.startGesture(center);
      final second = await tester.startGesture(center, pointer: 99);
      await second.moveBy(const Offset(0, kTouchSlop + 1));
      await second.up();
      await tester.pump();

      expect(scaleOf(tester), AppMotion.pressedScale);
      await first.up();
    });

    testWidgets('does nothing while disabled', (tester) async {
      await tester.pumpApp(buildSubject(enabled: false));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InkWell)),
      );
      await tester.pump();

      expect(scaleOf(tester), 1);
      await gesture.up();
    });

    testWidgets('lets go when it is disabled mid-press', (tester) async {
      await tester.pumpApp(buildSubject());
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InkWell)),
      );
      await tester.pump();

      await tester.pumpApp(buildSubject(enabled: false));

      expect(scaleOf(tester), 1);
      await gesture.up();
    });

    testWidgets('changes size at once with reduced motion', (tester) async {
      await tester.pumpApp(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: buildSubject(),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InkWell)),
      );
      await tester.pump();

      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
        Duration.zero,
      );
      await gesture.up();
    });
  });
}
