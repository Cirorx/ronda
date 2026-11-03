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
  group(RondaSketch, () {
    // Every scene on one sheet at a full screen's size, then the ones that
    // sit in cards at a card's, beside the object icons they share a line
    // with.
    Widget buildSubject() {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.unit),
        child: Wrap(
          key: const Key('sheet'),
          spacing: AppSpacing.unit,
          runSpacing: AppSpacing.unit,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            for (final scene in RondaScene.values) RondaSketch(scene),
            for (final scene in const [
              RondaScene.termoStamp,
              RondaScene.mateServed,
              RondaScene.objectsOnALine,
            ])
              RondaSketch(scene, height: RondaSketch.cardHeight),
            for (final object in RondaObject.values)
              RondaObjectIcon(object, size: RondaSketch.cardHeight),
          ],
        ),
      );
    }

    for (final MapEntry(key: name, value: theme) in themes.entries) {
      testWidgets('matches the $name golden', tags: TestTag.golden, (
        tester,
      ) async {
        await tester.pumpApp(
          buildSubject(),
          theme: theme(),
          size: const Size(760, 480),
        );

        await expectLater(
          find.byKey(const Key('sheet')),
          matchesGoldenFile('goldens/ronda_sketch_$name.png'),
        );
      });
    }
  });
}
