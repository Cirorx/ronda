import 'package:material_ui/material_ui.dart';
import 'package:ronda/l10n/gen/app_localizations.dart';

export 'package:ronda/l10n/gen/app_localizations.dart';

/// Ronda's strings plus the Material, Cupertino and widgets localizations.
///
/// Use this instead of the generated `AppLocalizations.localizationsDelegates`:
/// gen-l10n wires `flutter_localizations`' Global*Localizations, which provide
/// the framework's `MaterialLocalizations`, not `material_ui`'s, so every
/// locale but English would fail to find Material strings.
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The locale Ronda shows for a device's preferred [locales], most preferred
/// first.
///
/// The first Spanish or English entry wins: any Spanish (`es`, `es_UY`,
/// `es_ES`, ...) maps to rioplatense es-419, English to `en`. A device with
/// neither falls back to English.
Locale resolveAppLocale(List<Locale>? locales) {
  for (final locale in locales ?? const <Locale>[]) {
    switch (locale.languageCode) {
      case 'es':
        return const Locale('es', '419');
      case 'en':
        return const Locale('en');
    }
  }
  return const Locale('en');
}
