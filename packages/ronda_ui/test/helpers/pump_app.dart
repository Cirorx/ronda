import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// A phone-sized test surface, in logical pixels: narrow enough that a row
/// which doesn't wrap overflows.
const phoneSize = Size(360, 780);

/// Ronda's first locale. Tests pump it by default, so a component that needs
/// [MaterialLocalizations] fails here rather than only in the app.
const rioplatense = Locale('es', '419');

/// The locales the app ships.
const List<Locale> supportedLocales = [rioplatense, Locale('es'), Locale('en')];

/// Pumps widgets inside Ronda's theme.
extension PumpApp on WidgetTester {
  /// Pumps [widget] in a [Scaffold] inside a [MaterialApp] with [theme]
  /// ([AppTheme.light] by default), [locale] ([rioplatense] by default) and
  /// the system text scale set to [textScale].
  ///
  /// The localization delegates are `material_ui`'s: the framework's
  /// `flutter_localizations` ones serve the framework's
  /// [MaterialLocalizations], which `material_ui` widgets don't read.
  ///
  /// The surface is [phoneSize] for the rest of the test.
  Future<void> pumpApp(
    Widget widget, {
    ThemeData? theme,
    Locale locale = rioplatense,
    double textScale = 1,
  }) {
    view
      ..physicalSize = phoneSize
      ..devicePixelRatio = 1;
    addTearDown(view.reset);
    return pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        locale: locale,
        supportedLocales: supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: widget),
      ),
    );
  }
}
