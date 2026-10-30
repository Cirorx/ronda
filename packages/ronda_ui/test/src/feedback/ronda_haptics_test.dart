import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(RondaHaptics, () {
    testWidgets('commit asks for a light impact', (tester) async {
      final haptics = recordHaptics(tester);

      await RondaHaptics.commit();

      expect(haptics, ['HapticFeedbackType.lightImpact']);
    });

    group('onCommit', () {
      testWidgets('is felt before the callback runs', (tester) async {
        final haptics = recordHaptics(tester);
        final felt = <int>[];

        RondaHaptics.onCommit(() => felt.add(haptics.length))!();

        expect(felt, [1]);
      });

      test('stays null for a disabled action', () {
        expect(RondaHaptics.onCommit(null), isNull);
      });
    });
  });
}
