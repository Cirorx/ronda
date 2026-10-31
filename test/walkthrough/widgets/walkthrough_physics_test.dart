import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/walkthrough/walkthrough.dart';
import 'package:ronda_ui/ronda_ui.dart';

void main() {
  group(WalkthroughPhysics, () {
    test('settles on the standard spring', () {
      final spring = const WalkthroughPhysics().spring;

      expect(spring.stiffness, equals(AppMotion.standard.stiffness));
      expect(spring.damping, equals(AppMotion.standard.damping));
    });

    test('settles on a quicker spring with reduced motion', () {
      final spring = const WalkthroughPhysics(reduced: true).spring;

      expect(spring, same(WalkthroughPhysics.reducedSpring));
      expect(spring.stiffness, greaterThan(AppMotion.standard.stiffness));
    });

    test('keeps reduced motion when applied to a parent', () {
      final physics = const WalkthroughPhysics(reduced: true)
          .applyTo(const ClampingScrollPhysics());

      expect(physics.reduced, isTrue);
      expect(physics.parent, isA<ClampingScrollPhysics>());
    });
  });
}
