import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(WindowSize, () {
    group('forWidth', () {
      test('calls a phone compact', () {
        expect(WindowSize.forWidth(360), WindowSize.compact);
        expect(WindowSize.forWidth(599.9), WindowSize.compact);
      });

      test('calls a tablet or a narrow window medium', () {
        expect(WindowSize.forWidth(WindowSize.mediumWidth), WindowSize.medium);
        expect(WindowSize.forWidth(800), WindowSize.medium);
      });

      test('calls a desktop expanded', () {
        expect(
          WindowSize.forWidth(WindowSize.expandedWidth),
          WindowSize.expanded,
        );
        expect(WindowSize.forWidth(1280), WindowSize.expanded);
      });
    });

    test('is wide above a phone', () {
      expect(WindowSize.compact.isWide, isFalse);
      expect(WindowSize.medium.isWide, isTrue);
      expect(WindowSize.expanded.isWide, isTrue);
    });

    for (final (size, expected) in [
      (phoneSize, WindowSize.compact),
      (tabletSize, WindowSize.medium),
      (desktopSize, WindowSize.expanded),
    ]) {
      testWidgets('reads $expected from a ${size.width} px window', (
        tester,
      ) async {
        late WindowSize read;
        late WindowSize viaContext;
        await tester.pumpApp(
          Builder(
            builder: (context) {
              read = WindowSize.of(context);
              viaContext = context.windowSize;
              return const SizedBox();
            },
          ),
          size: size,
        );

        expect(read, expected);
        expect(viaContext, expected);
      });
    }
  });
}
