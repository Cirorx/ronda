import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Records every key asked of the root bundle.
class _RecordingBundle(final List<String> requested)
    extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    requested.add(key);
    return rootBundle.load(key);
  }
}

void main() {
  group('registerRondaUiLicenses', () {
    setUp(LicenseRegistry.reset);
    tearDown(LicenseRegistry.reset);

    test(
      'adds the OFL notice of each bundled font from the root bundle',
      () async {
        registerRondaUiLicenses();

        final entries = await LicenseRegistry.licenses.toList();
        final byFont = {
          for (final entry in entries)
            entry.packages.single: entry.paragraphs.map((p) => p.text).join(),
        };

        expect(byFont.keys, ['Young Serif', 'Atkinson Hyperlegible']);
        expect(
          byFont['Young Serif'],
          contains('Copyright 2023 The Young Serif Project Authors'),
        );
        expect(
          byFont['Atkinson Hyperlegible'],
          contains('Copyright 2020 Braille Institute of America'),
        );
        expect(byFont.values, everyElement(contains('SIL Open Font License')));
      },
    );

    test('reads the notices under packages/ronda_ui/', () async {
      final requested = <String>[];
      registerRondaUiLicenses(bundle: _RecordingBundle(requested));

      await LicenseRegistry.licenses.toList();

      expect(requested, [
        'packages/ronda_ui/assets/fonts/OFL-YoungSerif.txt',
        'packages/ronda_ui/assets/fonts/OFL-AtkinsonHyperlegible.txt',
      ]);
    });
  });
}
