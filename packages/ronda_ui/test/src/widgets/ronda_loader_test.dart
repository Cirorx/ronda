import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(RondaLoader, () {
    testWidgets('gathers its dots and opens them again, round and round', (
      tester,
    ) async {
      await tester.pumpApp(const Center(child: RondaLoader()));

      expect(tester.getSize(find.byType(RondaLoader)), const Size.square(36));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(RondaLoader.loop * 0.5);
      await tester.pump(RondaLoader.loop * 0.5);
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('holds still as the mark with reduced motion', (tester) async {
      await tester.pumpApp(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(child: RondaLoader(size: 24, color: AppColors.birome)),
        ),
      );

      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.getSize(find.byType(RondaLoader)), const Size.square(24));
    });

    testWidgets('repaints in a new colour', (tester) async {
      await tester.pumpApp(const Center(child: RondaLoader()));
      await tester.pumpApp(
        const Center(child: RondaLoader(color: AppColors.birome)),
      );

      expect(find.byType(RondaLoader), paints..circle(color: AppColors.birome));
    });

    testWidgets('paints in the theme primary without a colour', (tester) async {
      await tester.pumpApp(const Center(child: RondaLoader()));

      expect(
        find.byType(RondaLoader),
        paints..circle(color: AppTheme.light.colorScheme.primary),
      );
    });
  });
}
