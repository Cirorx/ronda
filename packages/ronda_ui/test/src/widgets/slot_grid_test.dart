import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

const _days = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _bands = ['Mañana', 'Tarde', 'Noche'];

void main() {
  group(SlotGrid, () {
    late List<Set<SlotGridCell>> changes;

    setUp(() => changes = []);

    Widget buildSubject({Set<SlotGridCell> selected = const {}}) {
      return SingleChildScrollView(
        child: SlotGrid(
          identifier: 'horarios',
          dayLabels: _days,
          bandLabels: _bands,
          cellSemanticsLabel: (day, band) =>
              '${_days[day]} de ${_bands[band].toLowerCase()}',
          selected: selected,
          onChanged: changes.add,
        ),
      );
    }

    group('renders', () {
      testWidgets('a grid with every day and band at normal text', (
        tester,
      ) async {
        await tester.pumpApp(buildSubject());

        expect(find.byType(Table), findsOneWidget);
        expect(find.byType(FilterChip), findsNothing);
        expect(find.text('Miércoles'), findsOneWidget);
        expect(find.text('Noche'), findsOneWidget);
      });

      testWidgets('per-day chips from ${SlotGrid.chipsTextScale}x text', (
        tester,
      ) async {
        await tester.pumpApp(
          buildSubject(),
          textScale: SlotGrid.chipsTextScale,
        );

        expect(find.byType(Table), findsNothing);
        expect(
          find.byType(FilterChip),
          findsNWidgets(_days.length * _bands.length),
        );
      });

      for (final scale in textScales) {
        testWidgets('a marked cell as selected, with its label, at ${scale}x', (
          tester,
        ) async {
          await tester.pumpApp(
            buildSubject(selected: {(day: 1, band: 1)}),
            textScale: scale,
          );

          expect(
            tester.getSemantics(find.bySemanticsIdentifier('horarios.1.1')),
            isSemantics(
              label: 'Martes de tarde',
              isButton: true,
              isSelected: true,
              hasTapAction: true,
            ),
          );
          expect(
            tester.getSemantics(find.bySemanticsIdentifier('horarios.1.2')),
            isSemantics(isSelected: false),
          );
        });
      }

      testWidgets('a check only on marked cells', (tester) async {
        await tester.pumpApp(buildSubject(selected: {(day: 0, band: 0)}));

        expect(find.byIcon(Icons.check), findsOneWidget);
      });

      testWidgets('cells with 48 dp tap targets', (tester) async {
        await tester.pumpApp(buildSubject());

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      });

      for (final MapEntry(key: name, value: theme) in themes.entries) {
        for (final scale in textScales) {
          testWidgets('without overflow in $name at ${scale}x text', (
            tester,
          ) async {
            await tester.pumpApp(
              buildSubject(selected: {(day: 2, band: 0)}),
              theme: theme(),
              textScale: scale,
            );

            expect(tester.takeException(), isNull);
          });
        }
      }
    });

    group('calls onChanged', () {
      for (final scale in textScales) {
        testWidgets('with the cell added when an empty cell is tapped '
            'at ${scale}x', (tester) async {
          await tester.pumpApp(
            buildSubject(selected: {(day: 0, band: 0)}),
            textScale: scale,
          );

          await tester.tap(find.bySemanticsIdentifier('horarios.0.1'));

          expect(changes, [
            {(day: 0, band: 0), (day: 0, band: 1)},
          ]);
        });

        testWidgets('with the cell removed when a marked cell is tapped '
            'at ${scale}x', (tester) async {
          await tester.pumpApp(
            buildSubject(selected: {(day: 0, band: 0), (day: 3, band: 1)}),
            textScale: scale,
          );

          await tester.ensureVisible(
            find.bySemanticsIdentifier('horarios.3.1'),
          );
          await tester.tap(find.bySemanticsIdentifier('horarios.3.1'));

          expect(changes, [
            {(day: 0, band: 0)},
          ]);
        });
      }

      testWidgets('through the semantics tap action', (tester) async {
        await tester.pumpApp(buildSubject());

        tester.semantics.tap(
          find.semantics.byPredicate(
            (node) => node.identifier == 'horarios.6.2',
          ),
        );
        await tester.pump();

        expect(changes, [
          {(day: 6, band: 2)},
        ]);
      });
    });
  });
}
