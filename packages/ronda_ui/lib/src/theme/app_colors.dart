import 'package:ronda_ui/ronda_ui.dart';

/// {@template app_colors}
/// Ronda's colour tokens, light and dark, from `docs/DESIGN.md` and the
/// component sheet.
///
/// Only [AppTheme] and [RondaPalette] read these. Widgets read colours from
/// `Theme.of(context).colorScheme` or `context.rondaPalette`, never from here.
/// {@endtemplate}
abstract final class AppColors {
  // Light (day).

  /// Background: the barrio's paper.
  static const paper = Color(0xFFFFFEFA);

  /// Text.
  static const ink = Color(0xFF18202F);

  /// Primary action, links, what neighbours read.
  static const birome = Color(0xFF2341C0);

  /// [birome] while pressed.
  static const biromePressed = Color(0xFF1A3196);

  /// Confirmed, "vino", "seguimos".
  static const yerba = Color(0xFF1D7448);

  /// Warnings, rain moves.
  static const ambar = Color(0xFF985E00);

  /// The ruled sheet's margin line. Rare accents only, never for errors alone.
  static const margen = Color(0xFFC8433C);

  /// Dividers.
  static const line = Color(0xFFD6DDE8);

  /// Secondary text.
  static const muted = Color(0xFF5A6477);

  /// Cards on paper.
  static const surface = Color(0xFFFFFFFF);

  /// Only the "Dejar Ronda y borrar todo" button.
  static const danger = Color(0xFFB42318);

  /// Info banners and selected chips.
  static const biromeTint = Color(0xFFEEF1FC);

  /// Warning banners.
  static const ambarTint = Color(0xFFFBF3E6);

  /// Kept-on-phone banners.
  static const yerbaTint = Color(0xFFE8F3EC);

  /// Offline banners.
  static const neutralTint = Color(0xFFF3F5FA);

  /// The track behind a segmented control ("Vino / No vino").
  static const neutralFill = Color(0xFFEEF0F4);

  /// A switch track or radio ring when off.
  static const controlOff = Color(0xFF8792A6);

  // Dark (night).

  /// [paper] at night.
  static const paperDark = Color(0xFF0E1320);

  /// [ink] at night.
  static const inkDark = Color(0xFFE5E9F1);

  /// [birome] at night.
  static const biromeDark = Color(0xFF93A6FF);

  /// [biromePressed] at night. Not in DESIGN.md yet.
  static const biromePressedDark = Color(0xFF7189F0);

  /// [yerba] at night.
  static const yerbaDark = Color(0xFF5CC48E);

  /// [ambar] at night.
  static const ambarDark = Color(0xFFE2A53D);

  /// [margen] at night.
  static const margenDark = Color(0xFFE07A72);

  /// [line] at night.
  static const lineDark = Color(0xFF2E384D);

  /// [muted] at night.
  static const mutedDark = Color(0xFFA3ADBF);

  /// [surface] at night.
  static const surfaceDark = Color(0xFF151B2B);

  /// [danger] at night. Not in DESIGN.md yet (the planilla's dark "cut").
  static const dangerDark = Color(0xFFF07C72);

  /// [biromeTint] at night.
  static const biromeTintDark = Color(0xFF1C2440);

  /// [ambarTint] at night. Not in DESIGN.md yet.
  static const ambarTintDark = Color(0xFF2A2416);

  /// [yerbaTint] at night. Not in DESIGN.md yet.
  static const yerbaTintDark = Color(0xFF15291F);

  /// [neutralTint] at night. Not in DESIGN.md yet (the planilla's dark
  /// "notif").
  static const neutralTintDark = Color(0xFF1A2234);

  /// [neutralFill] at night. Not in DESIGN.md yet.
  static const neutralFillDark = Color(0xFF1F2638);

  /// [controlOff] at night. Not in DESIGN.md yet.
  static const controlOffDark = Color(0xFF6B7489);

  /// Shadow and scrim at night: darker than [paperDark], so the top bar's
  /// edge and a sheet's scrim still read on dark paper. By day both are
  /// [ink].
  static const shadowDark = Color(0xFF05070C);
}
