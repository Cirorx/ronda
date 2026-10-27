import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

// The app builds options from its own data at runtime, so the tests do too.
const _optionData = [
  ('termo', 'Termo'),
  ('pan', 'Pan'),
  ('truco', 'Enseño truco'),
  ('auto', 'Tengo auto'),
];

List<ChipPickerOption> _options() => [
  for (final (value, label) in _optionData)
    ChipPickerOption(value: value, label: label, enabled: value != 'auto'),
];

void main() {
  group(ChipPicker, () {
    late List<Set<String>> changes;

    setUp(() => changes = []);

    Widget buildSubject({
      Set<String> selected = const {},
      bool multiSelect = true,
    }) {
      return ChipPicker(
        identifier: 'traes',
        options: _options(),
        selected: selected,
        multiSelect: multiSelect,
        onChanged: changes.add,
      );
    }

    group('renders', () {
      testWidgets('a $FilterChip per option when multiSelect', (tester) async {
        await tester.pumpApp(buildSubject());

        expect(find.byType(FilterChip), findsNWidgets(_optionData.length));
        expect(find.text('Enseño truco'), findsOneWidget);
      });

      testWidgets('a $ChoiceChip per option when single select', (
        tester,
      ) async {
        await tester.pumpApp(buildSubject(multiSelect: false));

        expect(find.byType(ChoiceChip), findsNWidgets(_optionData.length));
      });

      testWidgets('chips as selected when their value is selected', (
        tester,
      ) async {
        await tester.pumpApp(buildSubject(selected: {'pan'}));

        expect(
          tester.getSemantics(find.bySemanticsIdentifier('traes.pan')),
          isSemantics(isSelected: true, hasTapAction: true),
        );
        expect(
          tester.getSemantics(find.bySemanticsIdentifier('traes.termo')),
          isSemantics(isSelected: false),
        );
      });

      testWidgets('a disabled option as not tappable', (tester) async {
        await tester.pumpApp(buildSubject());

        expect(
          tester.getSemantics(find.bySemanticsIdentifier('traes.auto')),
          isSemantics(isEnabled: false, hasTapAction: false),
        );
      });

      testWidgets('every chip with a 48 dp tap target', (tester) async {
        await tester.pumpApp(buildSubject());

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      });

      for (final MapEntry(key: name, value: theme) in themes.entries) {
        for (final scale in textScales) {
          testWidgets('without overflow in $name at ${scale}x text', (
            tester,
          ) async {
            await tester.pumpApp(
              buildSubject(selected: {'termo'}),
              theme: theme(),
              textScale: scale,
            );

            expect(tester.takeException(), isNull);
            expect(find.text('Termo'), findsOneWidget);
          });
        }
      }
    });

    group('calls onChanged', () {
      testWidgets('with the value added when an unselected chip is tapped', (
        tester,
      ) async {
        await tester.pumpApp(buildSubject(selected: {'termo'}));

        await tester.tap(find.bySemanticsIdentifier('traes.pan'));

        expect(changes, [
          {'termo', 'pan'},
        ]);
      });

      testWidgets('with the value removed when a selected chip is tapped', (
        tester,
      ) async {
        await tester.pumpApp(buildSubject(selected: {'termo', 'pan'}));

        await tester.tap(find.text('Termo'));

        expect(changes, [
          {'pan'},
        ]);
      });

      testWidgets('with only the tapped value when single select', (
        tester,
      ) async {
        await tester.pumpApp(
          buildSubject(selected: {'termo'}, multiSelect: false),
        );

        await tester.tap(find.text('Pan'));

        expect(changes, [
          {'pan'},
        ]);
      });

      testWidgets('never when the chosen chip is tapped in single select', (
        tester,
      ) async {
        await tester.pumpApp(
          buildSubject(selected: {'termo'}, multiSelect: false),
        );

        await tester.tap(find.text('Termo'));

        expect(changes, isEmpty);
      });

      testWidgets('never when a disabled chip is tapped', (tester) async {
        await tester.pumpApp(buildSubject());

        await tester.tap(find.text('Tengo auto'), warnIfMissed: false);

        expect(changes, isEmpty);
      });
    });
  });
}
