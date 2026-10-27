import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// A phone-sized test surface, in logical pixels, as in ronda_ui's helper.
const phoneSize = Size(360, 780);

/// Ronda's first locale. Page tests pump it by default, so a missing
/// delegate fails here before it fails in the app.
const rioplatense = Locale('es', '419');

/// Pumps widgets the way the app shows them.
extension PumpApp on WidgetTester {
  /// Pumps [widget] inside a [MaterialApp] with [AppTheme.light], [locale]
  /// ([rioplatense] by default) and the app's localization delegates.
  ///
  /// The surface is [phoneSize] for the rest of the test.
  Future<void> pumpApp(Widget widget, {Locale locale = rioplatense}) {
    view
      ..physicalSize = phoneSize
      ..devicePixelRatio = 1;
    addTearDown(view.reset);
    return pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: widget,
      ),
    );
  }
}
