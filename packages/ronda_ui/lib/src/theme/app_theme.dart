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
    shadow: AppColors.ink,
    scrim: AppColors.ink,
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
    shadow: AppColors.shadowDark,
    scrim: AppColors.shadowDark,
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

  /// How strongly the scrim behind a modal sheet dims what is under it.
  static const double scrimOpacity = 0.4;

  /// The top bar's lift once content scrolls under it: a soft paper shadow,
  /// never a divider. At rest it is flat.
  static const double scrolledUnderElevation = 3;

  /// How strong that shadow's colour is.
  static const double scrolledUnderShadowOpacity = 0.35;

  /// Every theme button's style with press feedback: its shape (fill,
  /// border and ink) and its label shrink to [AppMotion.pressedScale] while
  /// pressed, from touch-down, and come back on release or drag-away.
  static ButtonStyle _pressable(ButtonStyle style, OutlinedBorder shape) {
    return style.copyWith(
      shape: WidgetStateProperty.resolveWith(
        (states) => PressedShape.forStates(shape, states),
      ),
      animationDuration: AppMotion.press,
      foregroundBuilder: (context, states, child) => _PressedLabel(
        pressed: states.contains(WidgetState.pressed),
        child: child,
      ),
    );
  }

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
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const RondaPageTransitionsBuilder(),
        },
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _pressable(
          FilledButton.styleFrom(
            minimumSize: buttonSize,
            padding: buttonPadding,
            textStyle: textTheme.labelLarge,
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.pressed)
                  ? palette.biromePressed
                  : null,
            ),
          ),
          roundedLg,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: _pressable(
          OutlinedButton.styleFrom(
            minimumSize: buttonSize,
            padding: buttonPadding,
            textStyle: textTheme.labelLarge,
            side: BorderSide(color: scheme.primary, width: borderWidth),
          ),
          roundedLg,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: _pressable(
          TextButton.styleFrom(
            minimumSize: const Size(minTarget, minTarget),
            padding: EdgeInsets.symmetric(horizontal: spacing.xs),
            textStyle: textTheme.labelLarge,
          ),
          roundedLg,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: _pressable(
          IconButton.styleFrom(
            minimumSize: const Size(minTarget, minTarget),
            foregroundColor: scheme.onSurface,
          ),
          const StadiumBorder(),
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
        modalBarrierColor: scheme.scrim.withValues(alpha: scrimOpacity),
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
        scrolledUnderElevation: scrolledUnderElevation,
        shadowColor: scheme.shadow.withValues(
          alpha: scrolledUnderShadowOpacity,
        ),
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

/// A button's label, shrunk with its shape while pressed.
class const _PressedLabel({required final bool pressed, final Widget? child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: pressed ? AppMotion.pressedScale : 1,
      duration: RondaMotion.of(context).durationOr(AppMotion.press),
      curve: AppMotion.pressCurve,
      child: child,
    );
  }
}
