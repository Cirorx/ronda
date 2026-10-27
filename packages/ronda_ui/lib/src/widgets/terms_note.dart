import 'package:ronda_ui/ronda_ui.dart';

/// {@template terms_note}
/// The footnote under the welcome doors: "Al seguir, aceptás las
/// [condiciones de Ronda]." Continuing past the welcome screen is the
/// acceptance; the link opens "Las condiciones, en corto".
///
/// The link is a full 48 dp button whose semantics identifier is
/// [identifier].
/// {@endtemplate}
class const TermsNote({
  /// Semantics identifier of the link ("bienvenida.condiciones").
  required final String identifier,

  /// The text before the link ("Al seguir, aceptás las").
  required final String lead,

  /// The link's text ("condiciones de Ronda").
  required final String linkLabel,

  /// Called when the person taps the link.
  required final VoidCallback onLinkTap,

  /// The text after the link, usually the full stop.
  final String trailing = '',
  super.key,
}) extends StatelessWidget {
  /// {@macro terms_note}
  this;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final spacing = context.appSpacing;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: spacing.xxs,
      children: [
        Text(lead, style: noteStyle, textAlign: TextAlign.center),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: MergeSemantics(
                child: Semantics(
                  identifier: identifier,
                  link: true,
                  child: TextButton(
                    onPressed: onLinkTap,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: theme.textTheme.bodySmall?.copyWith(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    child: Text(linkLabel, textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
            if (trailing.isNotEmpty) Text(trailing, style: noteStyle),
          ],
        ),
      ],
    );
  }
}
