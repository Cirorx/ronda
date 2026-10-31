import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(SpringBuilder, () {
    late List<double> values;

    setUp(() => values = []);

    Widget buildSubject(double value, {bool reduced = false, double? from}) =>
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: SpringBuilder(
            value: value,
            from: from,
            child: const SizedBox.shrink(),
            builder: (context, value, child) {
              values.add(value);
              return child!;
            },
          ),
        );

    testWidgets('starts at its value', (tester) async {
      await tester.pumpApp(buildSubject(0));

      expect(values.last, 0);
    });

    testWidgets('springs to a new value', (tester) async {
      await tester.pumpApp(buildSubject(0));

      await tester.pumpApp(buildSubject(1));
      await tester.pump(const Duration(milliseconds: 100));

      expect(values.last, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(values.last, closeTo(1, 1e-2));
    });

    testWidgets('retargets mid-flight from where it is', (tester) async {
      await tester.pumpApp(buildSubject(0));
      await tester.pumpApp(buildSubject(1));
      await tester.pump(const Duration(milliseconds: 100));
      final midway = values.last;

      await tester.pumpApp(buildSubject(0));
      await tester.pump(const Duration(milliseconds: 16));

      // Still moving up at first: it carries its speed into the new target.
      expect(values.last, greaterThan(midway - 0.05));
      await tester.pumpAndSettle();
      expect(values.last, closeTo(0, 1e-2));
    });

    testWidgets('jumps with reduced motion', (tester) async {
      await tester.pumpApp(buildSubject(0, reduced: true));

      await tester.pumpApp(buildSubject(1, reduced: true));

      expect(values.last, 1);
    });

    group('built with a value to come from', () {
      testWidgets('springs from it to its value', (tester) async {
        await tester.pumpApp(buildSubject(1, from: 0));

        expect(values.first, 0);
        await tester.pump(const Duration(milliseconds: 100));
        expect(values.last, inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
        expect(values.last, closeTo(1, 1e-2));
      });

      testWidgets('stays put when it is its value', (tester) async {
        await tester.pumpApp(buildSubject(1, from: 1));
        await tester.pump(const Duration(milliseconds: 100));

        expect(values, everyElement(1));
      });

      testWidgets('starts at its value with reduced motion', (tester) async {
        await tester.pumpApp(buildSubject(1, from: 0, reduced: true));

        expect(values.last, 1);
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('reads it only once', (tester) async {
        await tester.pumpApp(buildSubject(1, from: 0));
        await tester.pumpAndSettle();

        await tester.pumpApp(buildSubject(1, from: 0.5));
        await tester.pump(const Duration(milliseconds: 100));

        expect(values.last, closeTo(1, 1e-2));
      });
    });

    testWidgets('stays put when the value does not change', (tester) async {
      await tester.pumpApp(buildSubject(1));
      final builds = values.length;

      await tester.pumpApp(buildSubject(1));
      await tester.pump(const Duration(milliseconds: 100));

      expect(values.skip(builds), everyElement(1));
    });
  });
}
