import 'dart:ui';

import 'package:ronda_ui/ronda_ui.dart';

/// {@template app_spacing}
/// Spacing scale: 4, 8, 12, 16, 24, 32, each a multiple of [unit].
///
/// Read it through `context.appSpacing`.
/// {@endtemplate}
class AppSpacing extends ThemeExtension<AppSpacing> {
  /// {@macro app_spacing}
  const new({
    this.xxs = 0.25 * unit,
    this.xs = 0.5 * unit,
    this.sm = 0.75 * unit,
    this.md = unit,
    this.lg = 1.5 * unit,
    this.xlg = 2 * unit,
  });

  /// The base unit every step is a multiple of: 16.
  static const double unit = 16;

  /// 4.
  final double xxs;

  /// 8.
  final double xs;

  /// 12.
  final double sm;

  /// 16.
  final double md;

  /// 24.
  final double lg;

  /// 32.
  final double xlg;

  @override
  AppSpacing copyWith({
    double? xxs,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xlg,
  }) {
    return AppSpacing(
      xxs: xxs ?? this.xxs,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xlg: xlg ?? this.xlg,
    );
  }

  @override
  AppSpacing lerp(AppSpacing? other, double t) {
    if (other is! AppSpacing) return this;
    return AppSpacing(
      xxs: lerpDouble(xxs, other.xxs, t)!,
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xlg: lerpDouble(xlg, other.xlg, t)!,
    );
  }
}
