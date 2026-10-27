import 'package:ronda_ui/ronda_ui.dart';

/// {@template app_theme}
/// Ronda's [ThemeData], day and night, built from [AppColors],
/// [AppTextStyle], [AppSpacing] and [AppRadius].
///
/// Pass [light] as `theme` and [dark] as `darkTheme`; dark mode follows the
/// system. Widgets never branch on brightness: both themes fill the same
/// roles.
/// {@endtemplate}
abstract final class AppTheme {
  /// The day theme.
  static ThemeData get light => _theme(_lightScheme, RondaPalette.light);

  /// The night theme.
  static ThemeData get dark => _theme(_darkScheme, RondaPalette.dark);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.birome,
    onPrimary: AppColors.paper,
    primaryContainer: AppColors.biromeTint,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.ambar,
    onSecondary: AppColors.paper,
    secondaryContainer: AppColors.ambarTint,
    onSecondaryContainer: AppColors.ink,
    tertiary: AppColors.yerba,
    onTertiary: AppColors.paper,
    tertiaryContainer: AppColors.yerbaTint,
    onTertiaryContainer: AppColors.ink,
    error: AppColors.danger,
    onError: AppColors.paper,
    surface: AppColors.paper,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surface,
    surfaceContainerHighest: AppColors.neutralTint,
    outline: AppColors.muted,
    outlineVariant: AppColors.line,
    inverseSurface: AppColors.ink,
    onInverseSurface: AppColors.paper,
    inversePrimary: AppColors.biromeDark,
    surfaceTint: Colors.transparent,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.biromeDark,
    onPrimary: AppColors.paperDark,
    primaryContainer: AppColors.biromeTintDark,
    onPrimaryContainer: AppColors.inkDark,
    secondary: AppColors.ambarDark,
    onSecondary: AppColors.paperDark,
    secondaryContainer: AppColors.ambarTintDark,
    onSecondaryContainer: AppColors.inkDark,
    tertiary: AppColors.yerbaDark,
    onTertiary: AppColors.paperDark,
    tertiaryContainer: AppColors.yerbaTintDark,
    onTertiaryContainer: AppColors.inkDark,
    error: AppColors.dangerDark,
    onError: AppColors.paperDark,
    surface: AppColors.paperDark,
    onSurface: AppColors.inkDark,
    onSurfaceVariant: AppColors.mutedDark,
    surfaceContainerLowest: AppColors.surfaceDark,
    surfaceContainerLow: AppColors.surfaceDark,
    surfaceContainer: AppColors.surfaceDark,
    surfaceContainerHigh: AppColors.surfaceDark,
    surfaceContainerHighest: AppColors.neutralTintDark,
    outline: AppColors.mutedDark,
    outlineVariant: AppColors.lineDark,
    inverseSurface: AppColors.inkDark,
    onInverseSurface: AppColors.paperDark,
    inversePrimary: AppColors.birome,
    surfaceTint: Colors.transparent,
  );

  /// Height of every button: above the 48 dp target, as on the sheet.
  static const double buttonHeight = 52;

  /// The smallest tappable size.
  static const double minTarget = 48;

  /// Stroke of outlined buttons, cards, chips and slot cells.
  static const double borderWidth = 1.5;

  /// The text scale from which layouts take their large-text form (see
  /// `MainGrande` and `HorariosGrande` on the screen canvas).
  static const double largeTextScale = 1.5;

  static ThemeData _theme(ColorScheme scheme, RondaPalette palette) {
    const spacing = AppSpacing();
    final textTheme = AppTextStyle.textTheme;
    final roundedLg = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    );
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.unit + 0.25 * AppSpacing.unit,
    );
    const buttonSize = Size(minTarget, buttonHeight);

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[palette, spacing],
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: buttonSize,
              padding: buttonPadding,
              shape: roundedLg,
              textStyle: textTheme.labelLarge,
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.pressed)
                    ? palette.biromePressed
                    : null,
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          padding: buttonPadding,
          shape: roundedLg,
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: scheme.primary, width: borderWidth),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(minTarget, minTarget),
          padding: EdgeInsets.symmetric(horizontal: spacing.xs),
          shape: roundedLg,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(minTarget, minTarget),
          foregroundColor: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: scheme.outlineVariant, width: borderWidth),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.sm,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        border: _inputBorder(scheme.outline, borderWidth),
        enabledBorder: _inputBorder(scheme.outline, borderWidth),
        focusedBorder: _inputBorder(scheme.primary, 2),
        errorBorder: _inputBorder(scheme.error, borderWidth),
        focusedErrorBorder: _inputBorder(scheme.error, 2),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: palette.biromeTint,
        disabledColor: palette.neutralTint,
        checkmarkColor: scheme.primary,
        showCheckmark: true,
        padding: EdgeInsets.symmetric(
          horizontal: spacing.xs,
          vertical: spacing.xs,
        ),
        shape: const StadiumBorder(),
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.outlineVariant,
            width: borderWidth,
          ),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurfaceVariant;
            }
            if (states.contains(WidgetState.selected)) return scheme.primary;
            return scheme.onSurface;
          }),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: palette.biromeTint,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? textTheme.labelSmall?.copyWith(color: scheme.primary)
              : textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(scheme.surfaceContainer),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.yerba
              : palette.controlOff,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : palette.controlOff,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
