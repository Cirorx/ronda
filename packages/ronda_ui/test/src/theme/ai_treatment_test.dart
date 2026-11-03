import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AiTreatment, () {
    test('light holds the day virola values from docs/DESIGN.md', () {
      expect(AiTreatment.light.gradient, const [
        Color(0xFFB9C48A),
        Color(0xFFD9A441),
        Color(0xFFC9C2B8),
      ]);
      expect(AiTreatment.light.accent, const Color(0xFF8F5E0B));
      expect(AiTreatment.light.wash, const Color(0xFFFAF0DA));
    });

    test('dark holds the night virola values from docs/DESIGN.md', () {
      expect(AiTreatment.dark.gradient, const [
        Color(0xFFC2D191),
        Color(0xFFEBC078),
        Color(0xFFD8D2C8),
      ]);
      expect(AiTreatment.dark.accent, const Color(0xFFEBC078));
      expect(AiTreatment.dark.wash, const Color(0xFF3D2E14));
    });

    test('copyWith replaces only what it is given', () {
      const wash = Color(0xFF000000);
      final copied = AiTreatment.light.copyWith(wash: wash);

      expect(copied.gradient, AiTreatment.light.gradient);
      expect(copied.accent, AiTreatment.light.accent);
      expect(copied.wash, wash);
    });

    test('copyWith with nothing keeps every value', () {
      final copied = AiTreatment.dark.copyWith();

      expect(copied.gradient, AiTreatment.dark.gradient);
      expect(copied.accent, AiTreatment.dark.accent);
      expect(copied.wash, AiTreatment.dark.wash);
    });

    test('lerp reaches the other end at t=1 and stays at t=0', () {
      expect(
        AiTreatment.light.lerp(AiTreatment.dark, 0).gradient,
        AiTreatment.light.gradient,
      );
      expect(
        AiTreatment.light.lerp(AiTreatment.dark, 1).gradient,
        AiTreatment.dark.gradient,
      );
      expect(
        AiTreatment.light.lerp(AiTreatment.dark, 1).accent,
        AiTreatment.dark.accent,
      );
    });

    testWidgets('the extension reads the active theme', (tester) async {
      AiTreatment? read;
      Widget reader() => Builder(
        builder: (context) {
          read = context.aiTreatment;
          return const SizedBox();
        },
      );

      await tester.pumpApp(reader());
      expect(read?.gradient, AiTreatment.light.gradient);
      expect(read?.accent, AiTreatment.light.accent);

      await tester.pumpApp(reader(), theme: AppTheme.dark);
      // The theme crosses over on an animation: let it land before reading.
      await tester.pumpAndSettle();
      expect(read?.gradient, AiTreatment.dark.gradient);
      expect(read?.accent, AiTreatment.dark.accent);
      expect(read?.wash, AiTreatment.dark.wash);
    });
  });
}
