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

  /// Tracking by size, in em, as (size, tracking) pairs: large titles
  /// tighter, 17–18 sp body at 0, small text a little looser. Sizes in
  /// between are interpolated; see [trackingFor].
  static const trackingTable = <(double, double)>[
    (13, 0.015),
    (15, 0.008),
    (17, 0),
    (18, 0),
    (22, -0.01),
    (30, -0.018),
    (48, -0.025),
  ];

  /// The tracking for text set at [size], in em ([trackingTable]).
  static double trackingFor(double size) {
    final (firstSize, firstTracking) = trackingTable.first;
    if (size <= firstSize) return firstTracking;
    for (var i = 1; i < trackingTable.length; i++) {
      final (upper, upperTracking) = trackingTable[i];
      if (size <= upper) {
        final (lower, lowerTracking) = trackingTable[i - 1];
        final t = (size - lower) / (upper - lower);
        return lowerTracking + (upperTracking - lowerTracking) * t;
      }
    }
    return trackingTable.last.$2;
  }

  /// [style] at [size] with its line [height] and its size's tracking.
  static TextStyle _sized(TextStyle style, double size, double height) =>
      style.copyWith(
        fontSize: size,
        height: height,
        letterSpacing: size * trackingFor(size),
      );

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

  static TextStyle _titleOf(double size, double height) =>
      _sized(_title, size, height);

  static TextStyle _textOf(
    double size,
    double height, {
    FontWeight fontWeight = FontWeight.w400,
  }) => _sized(_text.copyWith(fontWeight: fontWeight), size, height);

  /// Young Serif 48: the largest heading.
  static final TextStyle displayLarge = _titleOf(48, 1.05);

  /// Young Serif 36: card titles ("Jueves 16:00").
  static final TextStyle displayMedium = _titleOf(36, 1.1);

  /// Young Serif 30: screen titles ("¿Qué podés llevar?").
  static final TextStyle displaySmall = _titleOf(30, 1.15);

  /// Atkinson Hyperlegible 28 bold: big times ("16:00 · 21:10").
  static final TextStyle headlineLarge = _textOf(
    28,
    1.2,
    fontWeight: FontWeight.w700,
  );

  /// Young Serif 26: a question inside a card ("¿Venís?").
  static final TextStyle headlineMedium = _titleOf(26, 1.15);

  /// Young Serif 22: bottom sheet titles.
  static final TextStyle headlineSmall = _titleOf(22, 1.2);

  /// Young Serif 22: app bar titles.
  static final TextStyle titleLarge = _titleOf(22, 1.2);

  /// Atkinson Hyperlegible 18 bold: values and row titles.
  static final TextStyle titleMedium = _textOf(
    18,
    1.3,
    fontWeight: FontWeight.w700,
  );

  /// Atkinson Hyperlegible 17 bold: names and day labels.
  static final TextStyle titleSmall = _textOf(
    17,
    1.3,
    fontWeight: FontWeight.w700,
  );

  /// Atkinson Hyperlegible 18: text fields and lead paragraphs.
  static final TextStyle bodyLarge = _textOf(18, 1.45);

  /// Atkinson Hyperlegible 17, line height 1.45: body text.
  static final TextStyle bodyMedium = _textOf(17, 1.45);

  /// Atkinson Hyperlegible 14: footnotes and field labels.
  static final TextStyle bodySmall = _textOf(14, 1.4);

  /// Atkinson Hyperlegible 18 bold: buttons.
  static final TextStyle labelLarge = _textOf(
    18,
    1.2,
    fontWeight: FontWeight.w700,
  );

  /// Atkinson Hyperlegible 15 bold: labels and chips.
  static final TextStyle labelMedium = _textOf(
    15,
    1.3,
    fontWeight: FontWeight.w700,
  );

  /// Atkinson Hyperlegible 13 bold: section heads and tab labels.
  static final TextStyle labelSmall = _textOf(
    13,
    1.3,
    fontWeight: FontWeight.w700,
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
