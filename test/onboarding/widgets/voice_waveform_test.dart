import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(VoiceWaveform, () {
    // 48 bars across 240 px: one every 5 px, the newest centred at 237.5.
    const width = 240.0;
    const length = 48;
    const middle = VoiceWaveform.height / 2;
    const tallest = (VoiceWaveform.height - VoiceWaveform.barWidth) / 2;

    Widget waveform(
      List<double> levels, {
      int? heard,
      TextDirection textDirection = TextDirection.ltr,
    }) => Directionality(
      textDirection: textDirection,
      child: Center(
        child: SizedBox(
          width: width,
          child: VoiceWaveform(
            levels: levels,
            heard: heard ?? levels.length,
            length: length,
          ),
        ),
      ),
    );

    Future<void> pump(
      WidgetTester tester,
      List<double> levels, {
      int? heard,
      bool reduced = false,
      TextDirection textDirection = TextDirection.ltr,
    }) => tester.pumpApp(
      reducedMotion(
        reduced: reduced,
        child: waveform(levels, heard: heard, textDirection: textDirection),
      ),
    );

    /// Pumps [first], then [next] into the same waveform.
    Future<void> pumpTwice(
      WidgetTester tester,
      List<double> first,
      List<double> next, {
      bool reduced = false,
    }) async {
      final levels = ValueNotifier(first);
      addTearDown(levels.dispose);
      await tester.pumpApp(
        reducedMotion(
          reduced: reduced,
          child: ValueListenableBuilder(
            valueListenable: levels,
            builder: (context, value, _) => waveform(value),
          ),
        ),
      );
      levels.value = next;
      await tester.pump();
    }

    RenderObject painter(WidgetTester tester) => tester.renderObject(
      find.descendant(
        of: find.byType(VoiceWaveform),
        matching: find.byType(CustomPaint),
      ),
    );

    testWidgets('draws silence as dots and speech as tall bars, newest at '
        'the end', (tester) async {
      await pump(tester, [0, 1]);

      expect(
        painter(tester),
        paints
          ..line(
            p1: const Offset(232.5, middle),
            p2: const Offset(232.5, middle),
          )
          ..line(
            p1: const Offset(237.5, middle - tallest),
            p2: const Offset(237.5, middle + tallest),
          ),
      );
    });

    testWidgets('a dead microphone draws only dots', (tester) async {
      await pump(tester, List.filled(length, 0));

      var dots = paints;
      for (var slot = 0; slot < length; slot++) {
        final x = slot * 5.0 + 2.5;
        dots = dots..line(p1: Offset(x, middle), p2: Offset(x, middle));
      }
      expect(painter(tester), dots);
    });

    testWidgets('draws its bars in birome', (tester) async {
      await pump(tester, [0.5]);

      expect(
        painter(tester),
        paints
          ..line(color: AppColors.birome, strokeWidth: VoiceWaveform.barWidth),
      );
    });

    testWidgets('keeps the newest bars when given more than fit', (
      tester,
    ) async {
      await pump(tester, [1, ...List.filled(length, 0)]);

      expect(
        painter(tester),
        isNot(
          paints..line(
            p1: const Offset(2.5, middle - tallest),
            p2: const Offset(2.5, middle + tallest),
          ),
        ),
      );
    });

    testWidgets('puts the newest bar at the start in right-to-left', (
      tester,
    ) async {
      await pump(tester, [1], textDirection: TextDirection.rtl);

      expect(
        painter(tester),
        paints..line(
          p1: const Offset(2.5, middle - tallest),
          p2: const Offset(2.5, middle + tallest),
        ),
      );
    });

    testWidgets('slides one bar along as a level arrives', (tester) async {
      await pumpTwice(tester, [1], [1, 1]);
      await tester.pump(const Duration(milliseconds: 20));

      // Halfway: the row is still half a bar further along.
      expect(
        painter(tester),
        paints
          ..line(p1: const Offset(235, middle - tallest))
          ..line(p1: const Offset(240, middle - tallest)),
      );

      await tester.pump(const Duration(milliseconds: 20));
      expect(
        painter(tester),
        paints
          ..line(p1: const Offset(232.5, middle - tallest))
          ..line(p1: const Offset(237.5, middle - tallest)),
      );
    });

    testWidgets('steps rather than slides with reduced motion', (tester) async {
      await pumpTwice(tester, [1], [1, 1], reduced: true);

      expect(
        painter(tester),
        paints
          ..line(p1: const Offset(232.5, middle - tallest))
          ..line(p1: const Offset(237.5, middle - tallest)),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('is silent to screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, [0.5]);

      expect(
        find.descendant(
          of: find.byType(VoiceWaveform),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });
}
