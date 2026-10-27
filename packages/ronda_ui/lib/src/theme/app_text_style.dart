import 'package:ronda_ui/ronda_ui.dart';

/// {@template app_text_style}
/// Ronda's type scale: Young Serif for titles, Atkinson Hyperlegible for
/// everything else (`docs/DESIGN.md` § Tokens and the component sheet).
///
/// Every style carries tabular figures, so times line up wherever they
/// appear without a call-site style. Colours are left to the theme.
///
/// Widgets read these through `Theme.of(context).textTheme`, never directly.
/// {@endtemplate}
abstract final class AppTextStyle {
  /// The package that bundles the fonts, so the families resolve from an app.
  static const fontPackage = 'ronda_ui';

  /// Family name of the title face, as declared in `pubspec.yaml`.
  static const titleFamily = 'YoungSerif';

  /// Family name of the text face, as declared in `pubspec.yaml`.
  static const textFamily = 'AtkinsonHyperlegible';

  /// Tabular figures, for times such as "16:00".
  static const tabularFigures = <FontFeature>[FontFeature.tabularFigures()];

  /// Titles track tighter: −0.02 em.
  static const _titleTracking = -0.02;

  /// Labels track looser: +0.01 em.
  static const _labelTracking = 0.01;

  static const _title = TextStyle(
    fontFamily: titleFamily,
    package: fontPackage,
    fontWeight: FontWeight.w400,
    fontFeatures: tabularFigures,
  );

  static const _text = TextStyle(
    fontFamily: textFamily,
    package: fontPackage,
    fontWeight: FontWeight.w400,
    fontFeatures: tabularFigures,
  );

  static TextStyle _titleOf(double size, double height) => _title.copyWith(
    fontSize: size,
    height: height,
    letterSpacing: size * _titleTracking,
  );

  /// Young Serif 48: the largest heading.
  static final TextStyle displayLarge = _titleOf(48, 1.05);

  /// Young Serif 36: card titles ("Jueves 16:00").
  static final TextStyle displayMedium = _titleOf(36, 1.1);

  /// Young Serif 30: screen titles ("¿Qué podés llevar?").
  static final TextStyle displaySmall = _titleOf(30, 1.15);

  /// Atkinson Hyperlegible 28 bold: big times ("16:00 · 21:10").
  static final TextStyle headlineLarge = _text.copyWith(
    fontSize: 28,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  /// Young Serif 26: a question inside a card ("¿Venís?").
  static final TextStyle headlineMedium = _titleOf(26, 1.15);

  /// Young Serif 22: bottom sheet titles.
  static final TextStyle headlineSmall = _titleOf(22, 1.2);

  /// Young Serif 22: app bar titles.
  static final TextStyle titleLarge = _titleOf(22, 1.2);

  /// Atkinson Hyperlegible 18 bold: values and row titles.
  static final TextStyle titleMedium = _text.copyWith(
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  /// Atkinson Hyperlegible 17 bold: names and day labels.
  static final TextStyle titleSmall = _text.copyWith(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );

  /// Atkinson Hyperlegible 18: text fields and lead paragraphs.
  static final TextStyle bodyLarge = _text.copyWith(fontSize: 18, height: 1.45);

  /// Atkinson Hyperlegible 17, line height 1.45: body text.
  static final TextStyle bodyMedium = _text.copyWith(
    fontSize: 17,
    height: 1.45,
  );

  /// Atkinson Hyperlegible 14: footnotes and field labels.
  static final TextStyle bodySmall = _text.copyWith(
    fontSize: 14,
    height: 1.4,
    letterSpacing: 14 * _labelTracking,
  );

  /// Atkinson Hyperlegible 18 bold: buttons.
  static final TextStyle labelLarge = _text.copyWith(
    fontSize: 18,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  /// Atkinson Hyperlegible 15 bold, +0.01 em: labels and chips.
  static final TextStyle labelMedium = _text.copyWith(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: 15 * _labelTracking,
  );

  /// Atkinson Hyperlegible 13 bold: section heads and tab labels.
  static final TextStyle labelSmall = _text.copyWith(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: 13 * _labelTracking,
  );

  /// Every style above, in Material's slots.
  static TextTheme get textTheme => TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );
}
