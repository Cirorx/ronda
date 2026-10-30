import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AppMotion, () {
    group('spring', () {
      test("converts Apple's damping ratio and response", () {
        final spring = AppMotion.spring(dampingRatio: 1, response: 0.5);
        const angular = 2 * math.pi / 0.5;

        expect(spring.mass, 1);
        expect(spring.stiffness, closeTo(angular * angular, 1e-9));
        expect(spring.damping, closeTo(2 * angular, 1e-9));
      });

      test('makes the standard spring critically damped', () {
        final spring = AppMotion.standard;

        expect(
          spring.damping,
          closeTo(2 * math.sqrt(spring.stiffness * spring.mass), 1e-9),
        );
      });

      test('gives the sheet spring a little bounce', () {
        final spring = AppMotion.sheet;
        final critical = 2 * math.sqrt(spring.stiffness * spring.mass);

        expect(spring.damping / critical, closeTo(0.8, 1e-9));
      });
    });

    group('project', () {
      test('lands a throw where scrolling would stop', () {
        expect(AppMotion.project(1000), closeTo(499, 1e-9));
        expect(AppMotion.project(-1000), closeTo(-499, 1e-9));
        expect(AppMotion.project(0), 0);
      });

      test('lands shorter with a faster deceleration', () {
        expect(
          AppMotion.project(1000, decelerationRate: 0.99),
          closeTo(99, 1e-9),
        );
      });
    });

    group('rubberBand', () {
      test('gives less the further it goes', () {
        final near = AppMotion.rubberBand(50, 400);
        final far = AppMotion.rubberBand(500, 400);

        expect(near, lessThan(50));
        expect(far, lessThan(400));
        expect(far - near, lessThan(450));
      });

      test('keeps the direction of the overshoot', () {
        expect(AppMotion.rubberBand(-100, 400), lessThan(0));
        expect(
          AppMotion.rubberBand(-100, 400),
          closeTo(-AppMotion.rubberBand(100, 400), 1e-9),
        );
      });

      test('gives nothing in an empty area', () {
        expect(AppMotion.rubberBand(100, 0), 0);
      });
    });

    test('follows the standard spring as a curve from 0 to 1', () {
      const curve = AppMotion.standardCurve;

      expect(curve.transform(0), 0);
      expect(curve.transform(1), 1);
      expect(curve.transform(0.5), greaterThan(0.5));
      expect(curve.transform(0.25), lessThan(curve.transform(0.5)));
    });
  });

  group(RondaMotion, () {
    Future<RondaMotion> motionIn(
      WidgetTester tester, {
      required bool disableAnimations,
    }) async {
      late RondaMotion motion;
      await tester.pumpApp(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Builder(
            builder: (context) {
              motion = RondaMotion.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return motion;
    }

    testWidgets('moves on springs by default', (tester) async {
      final motion = await motionIn(tester, disableAnimations: false);

      expect(motion.reduced, isFalse);
      expect(motion.springOr(AppMotion.sheet), AppMotion.sheet);
      expect(motion.durationOr(AppMotion.press), AppMotion.press);
    });

    testWidgets('drops springs and durations with reduced motion', (
      tester,
    ) async {
      final motion = await motionIn(tester, disableAnimations: true);

      expect(motion.reduced, isTrue);
      expect(motion.springOr(AppMotion.sheet), isNull);
      expect(motion.durationOr(AppMotion.press), Duration.zero);
    });

    testWidgets('reads no reduced motion without a $MediaQuery', (
      tester,
    ) async {
      late RondaMotion motion;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            motion = RondaMotion.of(context);
            return const SizedBox.shrink();
          },
        ),
      );

      expect(motion.reduced, isFalse);
    });

    group('transition', () {
      Widget slide(Animation<double> animation, Widget child) =>
          SlideTransition(
            position: Tween(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );

      for (final disableAnimations in [false, true]) {
        testWidgets('${disableAnimations ? 'cross-fades' : 'moves'} '
            'with disableAnimations $disableAnimations', (tester) async {
          final motion = await motionIn(
            tester,
            disableAnimations: disableAnimations,
          );

          final built = motion.transition(
            animation: kAlwaysCompleteAnimation,
            child: const SizedBox.shrink(),
            moving: slide,
          );

          expect(
            built,
            disableAnimations ? isA<FadeTransition>() : isA<SlideTransition>(),
          );
        });
      }

      testWidgets('fades without a moving transition', (tester) async {
        final motion = await motionIn(tester, disableAnimations: false);

        expect(
          motion.transition(
            animation: kAlwaysCompleteAnimation,
            child: const SizedBox.shrink(),
          ),
          isA<FadeTransition>(),
        );
      });
    });
  });
}
