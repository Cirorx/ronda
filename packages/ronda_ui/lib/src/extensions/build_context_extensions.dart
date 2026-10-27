import 'package:ronda_ui/ronda_ui.dart';

/// Shortcuts to Ronda's theme extensions.
extension AppThemeBuildContext on BuildContext {
  /// The [RondaPalette] of the current theme.
  RondaPalette get rondaPalette => Theme.of(this).extension<RondaPalette>()!;

  /// The [AppSpacing] of the current theme.
  AppSpacing get appSpacing => Theme.of(this).extension<AppSpacing>()!;

  /// Whether the system text scale is at least [AppTheme.largeTextScale],
  /// where layouts switch to their large-text form (stacked buttons, chips
  /// instead of a grid, no decorations beside text).
  bool get usesLargeText =>
      MediaQuery.textScalerOf(this).scale(1) >= AppTheme.largeTextScale;
}
