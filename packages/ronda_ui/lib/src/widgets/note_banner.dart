import 'package:ronda_ui/ronda_ui.dart';

/// What a [NoteBanner] is telling the person.
enum NoteBannerVariant {
  /// A tip ("Si te querés ir antes, decí «me tengo que ir»."). Birome tint.
  info,

  /// Something changed, such as rain moving the ronda. Ámbar tint.
  warning,

  /// Data that stays on this phone ("Queda guardado solo en este teléfono").
  /// Yerba tint.
  keptOnPhone,

  /// No connection ("Sin señal. Te mostramos lo último que vimos.").
  /// Neutral tint.
  offline,
}

/// {@template note_banner}
/// A tinted note inside a screen, never a toast: [NoteBannerVariant] picks
/// the tint, an optional [title] leads in the variant's accent colour.
///
/// It is a live region, so a banner that appears or changes later (offline,
/// rain) is read out by screen readers.
/// {@endtemplate}
class const NoteBanner({
  /// The note's text.
  required final String message,

  /// Which kind of note this is.
  final NoteBannerVariant variant = NoteBannerVariant.info,

  /// An optional bold first line ("Jueves 16:00 · lluvia 80%").
  final String? title,

  /// An optional leading icon, drawn in the variant's accent colour.
  final IconData? icon,
  super.key,
}) extends StatelessWidget {
  /// {@macro note_banner}
  this;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    final palette = context.rondaPalette;
    final spacing = context.appSpacing;

    final (background, accent) = switch (variant) {
      NoteBannerVariant.info => (palette.biromeTint, scheme.primary),
      NoteBannerVariant.warning => (palette.ambarTint, palette.ambar),
      NoteBannerVariant.keptOnPhone => (palette.yerbaTint, palette.yerba),
      NoteBannerVariant.offline => (palette.neutralTint, scheme.onSurface),
    };
    final messageStyle = variant == NoteBannerVariant.keptOnPhone
        ? textTheme.titleSmall?.copyWith(color: accent)
        : textTheme.bodyMedium?.copyWith(color: scheme.onSurface);

    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing.sm,
            children: [
              if (icon case final icon?)
                ExcludeSemantics(child: Icon(icon, color: accent)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title case final title?)
                      Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(color: accent),
                      ),
                    Text(message, style: messageStyle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
