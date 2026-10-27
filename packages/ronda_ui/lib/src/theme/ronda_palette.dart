import 'package:ronda_ui/ronda_ui.dart';

/// {@template ronda_palette}
/// Ronda's colour roles that Material's [ColorScheme] has no slot for.
///
/// Yerba, ámbar and danger also sit in the scheme (tertiary, secondary,
/// error); they are repeated here under their own names so widgets can say
/// what they mean. Read it through `context.rondaPalette`.
/// {@endtemplate}
class RondaPalette extends ThemeExtension<RondaPalette> {
  /// {@macro ronda_palette}
  const new({
    required this.yerba,
    required this.ambar,
    required this.margen,
    required this.danger,
    required this.biromeTint,
    required this.ambarTint,
    required this.yerbaTint,
    required this.neutralTint,
    required this.biromePressed,
    required this.neutralFill,
    required this.controlOff,
  });

  /// The day palette.
  static const light = RondaPalette(
    yerba: AppColors.yerba,
    ambar: AppColors.ambar,
    margen: AppColors.margen,
    danger: AppColors.danger,
    biromeTint: AppColors.biromeTint,
    ambarTint: AppColors.ambarTint,
    yerbaTint: AppColors.yerbaTint,
    neutralTint: AppColors.neutralTint,
    biromePressed: AppColors.biromePressed,
    neutralFill: AppColors.neutralFill,
    controlOff: AppColors.controlOff,
  );

  /// The night palette.
  static const dark = RondaPalette(
    yerba: AppColors.yerbaDark,
    ambar: AppColors.ambarDark,
    margen: AppColors.margenDark,
    danger: AppColors.dangerDark,
    biromeTint: AppColors.biromeTintDark,
    ambarTint: AppColors.ambarTintDark,
    yerbaTint: AppColors.yerbaTintDark,
    neutralTint: AppColors.neutralTintDark,
    biromePressed: AppColors.biromePressedDark,
    neutralFill: AppColors.neutralFillDark,
    controlOff: AppColors.controlOffDark,
  );

  /// Confirmed, "vino", "seguimos"; kept-on-phone text.
  final Color yerba;

  /// Warnings and rain moves.
  final Color ambar;

  /// The ruled sheet's margin line.
  final Color margen;

  /// The one destructive action.
  final Color danger;

  /// Info banners and selected chips.
  final Color biromeTint;

  /// Warning banners.
  final Color ambarTint;

  /// Kept-on-phone banners.
  final Color yerbaTint;

  /// Offline banners.
  final Color neutralTint;

  /// The primary action while pressed.
  final Color biromePressed;

  /// The track behind a segmented control.
  final Color neutralFill;

  /// A switch track or radio ring when off.
  final Color controlOff;

  @override
  RondaPalette copyWith({
    Color? yerba,
    Color? ambar,
    Color? margen,
    Color? danger,
    Color? biromeTint,
    Color? ambarTint,
    Color? yerbaTint,
    Color? neutralTint,
    Color? biromePressed,
    Color? neutralFill,
    Color? controlOff,
  }) {
    return RondaPalette(
      yerba: yerba ?? this.yerba,
      ambar: ambar ?? this.ambar,
      margen: margen ?? this.margen,
      danger: danger ?? this.danger,
      biromeTint: biromeTint ?? this.biromeTint,
      ambarTint: ambarTint ?? this.ambarTint,
      yerbaTint: yerbaTint ?? this.yerbaTint,
      neutralTint: neutralTint ?? this.neutralTint,
      biromePressed: biromePressed ?? this.biromePressed,
      neutralFill: neutralFill ?? this.neutralFill,
      controlOff: controlOff ?? this.controlOff,
    );
  }

  @override
  RondaPalette lerp(RondaPalette? other, double t) {
    if (other is! RondaPalette) return this;
    return RondaPalette(
      yerba: Color.lerp(yerba, other.yerba, t)!,
      ambar: Color.lerp(ambar, other.ambar, t)!,
      margen: Color.lerp(margen, other.margen, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      biromeTint: Color.lerp(biromeTint, other.biromeTint, t)!,
      ambarTint: Color.lerp(ambarTint, other.ambarTint, t)!,
      yerbaTint: Color.lerp(yerbaTint, other.yerbaTint, t)!,
      neutralTint: Color.lerp(neutralTint, other.neutralTint, t)!,
      biromePressed: Color.lerp(biromePressed, other.biromePressed, t)!,
      neutralFill: Color.lerp(neutralFill, other.neutralFill, t)!,
      controlOff: Color.lerp(controlOff, other.controlOff, t)!,
    );
  }
}
