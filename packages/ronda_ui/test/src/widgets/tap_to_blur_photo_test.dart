import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(TapToBlurPhoto, () {
    Widget photo({required bool busy, void Function(double, double)? tap}) =>
        SizedBox(
          width: 200,
          height: 100,
          child: TapToBlurPhoto(
            image: const ColoredBox(color: Color(0xFF808080)),
            busy: busy,
            onTapped: tap ?? (_, _) {},
          ),
        );

    testWidgets('a tap gives the spot as shares of the photo', (tester) async {
      final taps = <(double, double)>[];
      await tester.pumpApp(photo(busy: false, tap: (x, y) => taps.add((x, y))));

      final rect = tester.getRect(find.byType(TapToBlurPhoto));
      await tester.tapAt(rect.topLeft + const Offset(50, 75));

      expect(taps.single.$1, closeTo(0.25, 0.01));
      expect(taps.single.$2, closeTo(0.75, 0.01));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('while busy, a ring sits in the middle and taps do '
        'nothing', (tester) async {
      var tapped = false;
      await tester.pumpApp(photo(busy: true, tap: (_, _) => tapped = true));

      await tester.tap(find.byType(TapToBlurPhoto));

      expect(tapped, isFalse);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
