import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/my_ronda/widgets/esta_no_sheet.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(EstaNoSheet, () {
    late List<String> calls;

    setUp(() => calls = []);

    Future<void> open(
      WidgetTester tester, {
      Locale locale = rioplatense,
    }) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => EstaNoSheet(
              onStay: () => calls.add('stay'),
              onPause: () => calls.add('pause'),
              onMistake: () => calls.add('mistake'),
            ).show(context),
            child: const Text('abrir'),
          ),
        ),
        locale: locale,
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('never asks why and offers the next weeks', (tester) async {
      await open(tester);

      expect(find.text('Listo, esta no.'), findsOneWidget);
      expect(find.text('Nadie pregunta por qué.'), findsOneWidget);
      expect(find.text('¿Y las próximas semanas?'), findsOneWidget);
    });

    for (final (label, call, commits) in [
      ('Sigo en la ronda', 'stay', false),
      ('Pausar 2 semanas', 'pause', true),
      ('Me equivoqué, voy', 'mistake', true),
    ]) {
      testWidgets('$label closes it and calls back', (tester) async {
        await open(tester);
        final haptics = recordHaptics(tester);

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(find.byType(EstaNoSheet), findsNothing);
        expect(calls, [call]);
        expect(haptics, commits ? [commitHaptic] : isEmpty);
      });
    }

    testWidgets('closes from its close button, recording nothing more', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      expect(find.byType(EstaNoSheet), findsNothing);
      expect(calls, isEmpty);
    });

    testWidgets('reads in English', (tester) async {
      await open(tester, locale: const Locale('en'));

      expect(find.text('Nobody asks why.'), findsOneWidget);
      expect(find.text('Pause for 2 weeks'), findsOneWidget);
    });
  });
}
