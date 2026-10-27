// Run outside Very Good CLI's optimizer: it merges test files, and its golden
// comparator then cannot find this file's directory. The optimizer and the
// test runner both read file-level `@Tags` as string literals, so these two
// stay literal; each test also carries `TestTag.golden`.
@Tags(['golden', 'skip_very_good_optimization'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

// Regenerate the images with the MCP `test` tool and
// `tags: golden, update_goldens: true`.
void main() {
  group(ReadBackCard, () {
    Widget buildSubject() {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.unit),
        child: ReadBackCard(
          identifier: 'lectura',
          editLabel: 'Cambiar',
          fields: [
            for (final (id, label, value) in const [
              ('nombre', 'Te llamás', 'Graciela'),
              ('edad', 'Edad', 'sesenta y pico'),
              ('barrio', 'Barrio', 'Solymar Norte'),
              ('gusta', 'Te gusta', 'mate en la rambla, truco'),
              ('dias', 'Días que podés', 'martes y jueves de tarde'),
              ('traes', 'Podés llevar', 'bizcochos caseros'),
            ])
              ReadBackField(
                id: id,
                label: label,
                value: value,
                editSemanticsLabel: 'Cambiar $label',
                onEdit: () {},
              ),
          ],
        ),
      );
    }

    for (final MapEntry(key: name, value: theme) in themes.entries) {
      testWidgets('matches the $name golden', tags: TestTag.golden, (
        tester,
      ) async {
        await tester.pumpApp(buildSubject(), theme: theme());

        await expectLater(
          find.byType(ReadBackCard),
          matchesGoldenFile('goldens/read_back_card_$name.png'),
        );
      });
    }
  });
}
