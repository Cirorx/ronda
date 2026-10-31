import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(BusyLabel, () {
    Widget buildSubject({required bool busy}) => Center(
      child: FilledButton(
        onPressed: () {},
        child: BusyLabel('Mandarlo', busy: busy),
      ),
    );

    testWidgets('is only the words while idle', (tester) async {
      await tester.pumpApp(buildSubject(busy: false));

      expect(find.text('Mandarlo'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('carries a ring in the button colour while busy', (
      tester,
    ) async {
      await tester.pumpApp(buildSubject(busy: true));

      final ring = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(ring.color, AppTheme.light.colorScheme.onPrimary);
      expect(ring.strokeWidth, BusyLabel.strokeWidth);
      expect(find.text('Mandarlo'), findsOneWidget);
    });

    testWidgets('keeps the ring out of what is read', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(buildSubject(busy: true));

      expect(
        tester.getSemantics(find.byType(FilledButton)),
        isSemantics(label: 'Mandarlo', isButton: true),
      );
      semantics.dispose();
    });
  });
}
