import 'package:flutter/services.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Registers the bundled fonts with the engine under the family names
/// [AppTextStyle] asks for, so tests and goldens render real glyphs instead
/// of the test font's boxes.
///
/// In this package's own tests the assets sit at `assets/fonts/…`, without
/// the `packages/ronda_ui/` prefix an app sees, while [AppTextStyle] names
/// the prefixed families; so each family is loaded by hand.
Future<void> loadRondaFonts() async {
  const prefix = 'packages/${AppTextStyle.fontPackage}';
  final families = <String, List<String>>{
    '$prefix/${AppTextStyle.titleFamily}': [
      'assets/fonts/YoungSerif-Regular.ttf',
    ],
    '$prefix/${AppTextStyle.textFamily}': [
      'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
      'assets/fonts/AtkinsonHyperlegible-Bold.ttf',
    ],
    'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
  };
  for (final MapEntry(key: family, value: assets) in families.entries) {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}
