import 'package:ronda_ui/ronda_ui.dart';

/// {@template app_colors}
/// Ronda's colour tokens, light and dark, from `docs/DESIGN.md` and the
/// component sheet.
///
/// Only [AppTheme] and [RondaPalette] read these. Widgets read colours from
/// `Theme.of(context).colorScheme` or `context.rondaPalette`, never from here.
///
/// The names are the roles: `birome` is the primary action, `yerba` the
/// tertiary, `ambar` warnings, `margen` the ruled sheet's margin line. Since
/// the Mate y alpaca direction the hues are yerba green, ochre and alpaca
/// silver, not the old birome blue.
/// {@endtemplate}
abstract final class AppColors {
  // Light (day).

  /// Background: the camionero paper.
  static const paper = Color(0xFFF8F3EA);

  /// Text.
  static const ink = Color(0xFF241B12);

  /// Primary action, links, what neighbours read: yerba green.
  static const birome = Color(0xFF4E6428);

  /// [birome] while pressed.
  static const biromePressed = Color(0xFF3E5020);

  /// Tertiary, confirmed, "vino", "seguimos": alpaca silver, one shade
  /// deeper than the direction's swatch so white text on it passes AA.
  static const yerba = Color(0xFF5C6B7A);

  /// Warnings, rain moves: ochre.
  static const ambar = Color(0xFF8F5E0B);

  /// The ruled sheet's margin line. Rare accents only, never for errors alone.
  static const margen = Color(0xFF8F5E0B);

  /// Dividers.
  static const line = Color(0xFFE2D6C2);

  /// Secondary text.
  static const muted = Color(0xFF77695A);

  /// Cards on paper.
  static const surface = Color(0xFFFFFFFF);

  /// Only the "Dejar Ronda y borrar todo" button.
  static const danger = Color(0xFFB42318);

  /// Info banners and selected chips.
  static const biromeTint = Color(0xFFEEF1DF);

  /// Warning banners.
  static const ambarTint = Color(0xFFFAF0DA);

  /// Kept-on-phone banners.
  static const yerbaTint = Color(0xFFE9EDF0);

  /// Offline banners.
  static const neutralTint = Color(0xFFEEF1DF);

  /// The track behind a segmented control ("Vino / No vino").
  static const neutralFill = Color(0xFFEEF1DF);

  /// A switch track or radio ring when off.
  static const controlOff = Color(0xFF77695A);

  // Dark (night).

  /// [paper] at night.
  static const paperDark = Color(0xFF171310);

  /// [ink] at night.
  static const inkDark = Color(0xFFF5EEDF);

  /// [birome] at night.
  static const biromeDark = Color(0xFFC2D191);

  /// [biromePressed] at night. Not in DESIGN.md yet.
  static const biromePressedDark = Color(0xFFA9BC74);

  /// [yerba] at night.
  static const yerbaDark = Color(0xFFBEC9D4);

  /// [ambar] at night.
  static const ambarDark = Color(0xFFEBC078);

  /// [margen] at night.
  static const margenDark = Color(0xFFEBC078);

  /// [line] at night.
  static const lineDark = Color(0xFF42362A);

  /// [muted] at night.
  static const mutedDark = Color(0xFFBCAF9C);

  /// [surface] at night.
  static const surfaceDark = Color(0xFF241D17);

  /// [danger] at night. Not in DESIGN.md yet (the planilla's dark "cut").
  static const dangerDark = Color(0xFFF07C72);

  /// [biromeTint] at night.
  static const biromeTintDark = Color(0xFF2E3419);

  /// [ambarTint] at night. Not in DESIGN.md yet.
  static const ambarTintDark = Color(0xFF3D2E14);

  /// [yerbaTint] at night. Not in DESIGN.md yet.
  static const yerbaTintDark = Color(0xFF2A333C);

  /// [neutralTint] at night. Not in DESIGN.md yet (the planilla's dark
  /// "notif").
  static const neutralTintDark = Color(0xFF2E3419);

  /// [neutralFill] at night. Not in DESIGN.md yet.
  static const neutralFillDark = Color(0xFF2E3419);

  /// [controlOff] at night. Not in DESIGN.md yet.
  static const controlOffDark = Color(0xFFBCAF9C);

  /// Shadow and scrim at night: darker than [paperDark], so the top bar's
  /// edge and a sheet's scrim still read on dark paper. By day both are
  /// [ink].
  static const shadowDark = Color(0xFF05070C);
}
