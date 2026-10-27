import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(StepSheet, () {
    late List<String> taps;

    setUp(() => taps = []);

    StepSheet buildSubject({bool withSecondary = true, Widget? child}) {
      return StepSheet(
        identifier: 'microfono',
        title: 'No podemos usar el micrófono',
        body: 'Para grabar, dale permiso al micrófono en los ajustes.',
        primaryLabel: 'Abrir ajustes',
        onPrimary: () => taps.add('primary'),
        secondaryLabel: withSecondary ? 'Prefiero tocar botones' : null,
        onSecondary: withSecondary ? () => taps.add('secondary') : null,
        child: child,
      );
    }

    group('renders', () {
      testWidgets('the title as a header, the body and both actions', (
        tester,
      ) async {
        await tester.pumpApp(buildSubject());

        expect(
          tester.getSemantics(find.text('No podemos usar el micrófono')),
          isSemantics(isHeader: true),
        );
        expect(find.byType(FilledButton), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);
      });

      testWidgets('no secondary action without one', (tester) async {
        await tester.pumpApp(buildSubject(withSecondary: false));

        expect(find.byType(OutlinedButton), findsNothing);
      });

      testWidgets('the child between body and actions', (tester) async {
        await tester.pumpApp(buildSubject(child: const Text('1. Ajustes')));

        expect(find.text('1. Ajustes'), findsOneWidget);
      });

      testWidgets('actions with identifiers and 48 dp targets', (tester) async {
        await tester.pumpApp(buildSubject());

        expect(
          tester.getSemantics(find.bySemanticsIdentifier('microfono.primary')),
          isSemantics(label: 'Abrir ajustes', hasTapAction: true),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      });

      for (final MapEntry(key: name, value: theme) in themes.entries) {
        for (final scale in textScales) {
          testWidgets('without overflow in $name at ${scale}x text', (
            tester,
          ) async {
            await tester.pumpApp(
              buildSubject(),
              theme: theme(),
              textScale: scale,
            );

            expect(tester.takeException(), isNull);
          });
        }
      }
    });

    group('calls', () {
      testWidgets('onPrimary when the primary action is tapped', (
        tester,
      ) async {
        await tester.pumpApp(buildSubject());

        await tester.tap(find.bySemanticsIdentifier('microfono.primary'));

        expect(taps, ['primary']);
      });

      testWidgets('onSecondary when the secondary action is tapped', (
        tester,
      ) async {
        await tester.pumpApp(buildSubject());

        await tester.tap(find.bySemanticsIdentifier('microfono.secondary'));

        expect(taps, ['secondary']);
      });
    });

    group('show', () {
      testWidgets('opens the sheet as a modal bottom sheet', (tester) async {
        final sheet = buildSubject();
        await tester.pumpApp(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => sheet.show<void>(context),
              child: const Text('Abrir'),
            ),
          ),
        );

        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('No podemos usar el micrófono'), findsOneWidget);
      });

      for (final locale in supportedLocales) {
        testWidgets('finds its localizations in $locale', (tester) async {
          final sheet = buildSubject();
          await tester.pumpApp(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => sheet.show<void>(context),
                child: const Text('Abrir'),
              ),
            ),
            locale: locale,
          );

          await tester.tap(find.text('Abrir'));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(StepSheet), findsOneWidget);
        });
      }

      for (final MapEntry(key: name, value: theme) in themes.entries) {
        testWidgets('holds at 2x text in $name', (tester) async {
          final sheet = buildSubject(
            child: const Text(
              '1. Abrí Ajustes. 2. Tocá Ronda. 3. Prendé el micrófono.',
            ),
          );
          await tester.pumpApp(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => sheet.show<void>(context),
                child: const Text('Abrir'),
              ),
            ),
            theme: theme(),
            textScale: 2,
          );

          await tester.tap(find.text('Abrir'));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(StepSheet), findsOneWidget);
        });
      }
    });
  });
}
