import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The fonts this package bundles, with the asset that holds each one's
/// OFL 1.1 notice.
const _fontLicenses = [
  ('Young Serif', 'assets/fonts/OFL-YoungSerif.txt'),
  ('Atkinson Hyperlegible', 'assets/fonts/OFL-AtkinsonHyperlegible.txt'),
];

/// Adds the licence notices of the fonts `ronda_ui` bundles to
/// [LicenseRegistry], so they show on the app's licence page.
///
/// Call it once, from the app's bootstrap. The notices are read lazily from
/// [bundle] ([rootBundle] by default) under `packages/ronda_ui/`.
void registerRondaUiLicenses({AssetBundle? bundle}) {
  final assets = bundle ?? rootBundle;
  LicenseRegistry.addLicense(() => _fontLicenseEntries(assets));
}

Stream<LicenseEntry> _fontLicenseEntries(AssetBundle bundle) async* {
  for (final (font, path) in _fontLicenses) {
    final text = await bundle.loadString(
      'packages/${AppTextStyle.fontPackage}/$path',
    );
    yield LicenseEntryWithLineBreaks([font], text);
  }
}
