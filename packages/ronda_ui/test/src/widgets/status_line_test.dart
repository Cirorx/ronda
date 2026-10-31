import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(StatusLine, () {
    testWidgets('says what is happening, read out as it changes', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(const StatusLine('Guardando tu respuesta…'));

      expect(
        tester.getSemantics(find.text('Guardando tu respuesta…')),
        isSemantics(label: 'Guardando tu respuesta…', isLiveRegion: true),
      );
      semantics.dispose();
    });

    testWidgets('takes the style it is given', (tester) async {
      const style = TextStyle(fontSize: 30);
      await tester.pumpApp(const StatusLine('No pudimos leer', style: style));

      expect(tester.widget<Text>(find.text('No pudimos leer')).style, style);
    });
  });
}
