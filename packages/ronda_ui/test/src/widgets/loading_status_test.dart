import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(LoadingStatus, () {
    testWidgets('shows a ring over a line that is read out', (tester) async {
      final semantics = tester.ensureSemantics();
      final words = ['Buscando tu ronda…'];
      // Built at run time, not as a constant.
      await tester.pumpApp(LoadingStatus(words.single));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(CircularProgressIndicator)).dy,
        lessThan(tester.getTopLeft(find.text('Buscando tu ronda…')).dy),
      );
      expect(
        tester.getSemantics(find.text('Buscando tu ronda…')),
        isSemantics(label: 'Buscando tu ronda…', isLiveRegion: true),
      );
      semantics.dispose();
    });

    testWidgets('inline, puts the ring at the start of a row', (tester) async {
      final words = ['Contando…'];
      await tester.pumpApp(LoadingStatus.inline(words.single));

      final ring = tester.getRect(find.byType(CircularProgressIndicator));
      final line = tester.getRect(find.text('Contando…'));
      expect(ring.right, lessThanOrEqualTo(line.left));
      expect(ring.size, const Size.square(LoadingStatus.inlineSize));
      expect(find.byType(StatusLine), findsOneWidget);
    });

    for (final scale in textScales) {
      testWidgets('holds at ${scale}x text', (tester) async {
        await tester.pumpApp(
          const Column(
            children: [
              LoadingStatus('Buscando tu ronda, esperá un poquito…'),
              LoadingStatus.inline('Buscando tu ronda, esperá un poquito…'),
            ],
          ),
          textScale: scale,
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
