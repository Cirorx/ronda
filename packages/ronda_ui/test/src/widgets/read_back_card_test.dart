import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(ReadBackCard, () {
    late List<String> edits;

    setUp(() => edits = []);

    Widget buildSubject() {
      return ReadBackCard(
        identifier: 'lectura',
        editLabel: 'Cambiar',
        fields: [
          ReadBackField(
            id: 'nombre',
            label: 'Te llamás',
            value: 'Graciela',
            editSemanticsLabel: 'Cambiar nombre',
            onEdit: () => edits.add('nombre'),
          ),
          ReadBackField(
            id: 'barrio',
            label: 'Barrio',
            value: 'Solymar Norte',
            editSemanticsLabel: 'Cambiar barrio',
            onEdit: () => edits.add('barrio'),
          ),
          ReadBackField(
            id: 'traes',
            label: 'Podés llevar',
            value: 'bizcochos caseros',
            editSemanticsLabel: 'Cambiar lo que traés',
            onEdit: () => edits.add('traes'),
          ),
        ],
      );
    }

    group('renders', () {
      testWidgets('every label and value', (tester) async {
        await tester.pumpApp(buildSubject());

        expect(find.text('Te llamás'), findsOneWidget);
        expect(find.text('Solymar Norte'), findsOneWidget);
        expect(find.text('Cambiar'), findsNWidgets(3));
      });

      testWidgets('only as tall as its fields', (tester) async {
        await tester.pumpApp(buildSubject());

        expect(
          tester.getSize(find.byType(ReadBackCard)).height,
          lessThan(phoneSize.height / 2),
        );
      });

      testWidgets('a divider between fields only', (tester) async {
        await tester.pumpApp(buildSubject());

        expect(find.byType(Divider), findsNWidgets(2));
      });

      testWidgets('each label and value read together', (tester) async {
        await tester.pumpApp(buildSubject());

        expect(
          tester.getSemantics(find.text('Graciela')),
          isSemantics(label: 'Te llamás\nGraciela'),
        );
      });

      testWidgets('each edit action with its own label and identifier', (
        tester,
      ) async {
        await tester.pumpApp(buildSubject());

        expect(
          tester.getSemantics(find.bySemanticsIdentifier('lectura.barrio')),
          isSemantics(
            label: 'Cambiar barrio',
            isButton: true,
            hasTapAction: true,
          ),
        );
      });

      testWidgets('edit actions with 48 dp tap targets', (tester) async {
        await tester.pumpApp(buildSubject());

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      });

      for (final MapEntry(key: name, value: theme) in themes.entries) {
        for (final scale in textScales) {
          testWidgets('without overflow in $name at ${scale}x text', (
            tester,
          ) async {
            await tester.pumpApp(
              SingleChildScrollView(child: buildSubject()),
              theme: theme(),
              textScale: scale,
            );

            expect(tester.takeException(), isNull);
            expect(find.text('bizcochos caseros'), findsOneWidget);
          });
        }
      }
    });

    group('calls onEdit', () {
      testWidgets('of the field whose edit action is tapped', (tester) async {
        await tester.pumpApp(buildSubject());

        await tester.tap(find.bySemanticsIdentifier('lectura.barrio'));

        expect(edits, ['barrio']);
      });

      testWidgets('through the semantics tap action', (tester) async {
        await tester.pumpApp(buildSubject());

        tester.semantics.tap(
          find.semantics.byPredicate(
            (node) => node.identifier == 'lectura.traes',
          ),
        );
        await tester.pump();

        expect(edits, ['traes']);
      });
    });
  });
}
