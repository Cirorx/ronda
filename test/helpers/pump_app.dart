import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// A phone-sized test surface, in logical pixels, as in ronda_ui's helper.
const phoneSize = Size(360, 780);

/// A tablet or a narrow window: [WindowSize.medium].
const tabletSize = Size(800, 1000);

/// A desktop window: [WindowSize.expanded].
const desktopSize = Size(1280, 800);

/// The three widths every wide-screen layout is checked at, one per
/// [WindowSize].
const windowSizes = <Size>[phoneSize, tabletSize, desktopSize];

/// Ronda's first locale. Page tests pump it by default, so a missing
/// delegate fails here before it fails in the app.
const rioplatense = Locale('es', '419');

/// Pumps widgets the way the app shows them.
extension PumpApp on WidgetTester {
  /// Pumps [widget] inside a [MaterialApp] with [AppTheme.light], [locale]
  /// ([rioplatense] by default) and the app's localization delegates.
  ///
  /// The surface is [size] ([phoneSize] by default) for the rest of the
  /// test, and the system text scale is [textScale].
  Future<void> pumpApp(
    Widget widget, {
    Locale locale = rioplatense,
    Size size = phoneSize,
    double textScale = 1,
  }) {
    view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(view.reset);
    return pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: textScale == 1
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
        home: widget,
      ),
    );
  }
}
