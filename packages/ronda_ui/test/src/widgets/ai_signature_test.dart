import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AiSignature, () {
    testWidgets('draws the theme thread with no label', (tester) async {
      await tester.pumpApp(const AiSignature());

      final thread = tester.widget<Container>(
        find.byWidgetPredicate((widget) {
          if (widget is! Container || widget.decoration is! BoxDecoration) {
            return false;
          }
          return (widget.decoration! as BoxDecoration).gradient
              is LinearGradient;
        }),
      );
      final gradient =
          (thread.decoration! as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors, AiTreatment.light.gradient);
    });

    testWidgets('draws the night thread under the dark theme', (tester) async {
      await tester.pumpApp(const AiSignature(), theme: AppTheme.dark);

      final thread = tester.widget<Container>(
        find.byWidgetPredicate((widget) {
          if (widget is! Container || widget.decoration is! BoxDecoration) {
            return false;
          }
          return (widget.decoration! as BoxDecoration).gradient
              is LinearGradient;
        }),
      );
      final gradient =
          (thread.decoration! as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors, AiTreatment.dark.gradient);
    });

    testWidgets('names the work on the label chip', (tester) async {
      // Built at runtime, not const, so coverage sees the constructor run.
      // ignore: prefer_const_declarations
      final labelText = 'La armó el programa';
      await tester.pumpApp(AiSignature(label: labelText));

      expect(find.text('La armó el programa'), findsOneWidget);
      final label = tester.widget<Text>(find.text('La armó el programa'));
      expect(label.style?.color, AiTreatment.light.accent);
    });

    testWidgets('reads the label as ordinary text', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(const AiSignature(label: 'La armó el programa'));

      expect(
        tester.getSemantics(find.text('La armó el programa')),
        isSemantics(label: 'La armó el programa'),
      );
      semantics.dispose();
    });
  });
}
