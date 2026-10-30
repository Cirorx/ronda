import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Listo, esta no. Nadie pregunta por qué." — and the next weeks: "Sigo en
/// la ronda" or "Pausar 2 semanas", or "Me equivoqué, voy". Each choice
/// closes the sheet; the callbacks decide what it records.
class const EstaNoSheet({
  required final VoidCallback onStay,
  required final VoidCallback onPause,
  required final VoidCallback onMistake,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handles on its three choices.
  static const stayIdentifier = 'estaNo.stay';
  static const pauseIdentifier = 'estaNo.pause';
  static const mistakeIdentifier = 'estaNo.mistake';

  /// Shows the sheet; it resolves when the sheet closes.
  Future<void> show(BuildContext context) =>
      showRondaSheet<void>(context: context, builder: (_) => this);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;

    Widget choice(String identifier, Widget button) => MergeSemantics(
      child: Semantics(identifier: identifier, child: button),
    );

    void close(VoidCallback then) {
      Navigator.of(context).pop();
      then();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: spacing.lg,
        right: spacing.lg,
        bottom: spacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.md,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.estaNoTitle, style: textTheme.headlineSmall),
          ),
          Text(l10n.estaNoBody, style: textTheme.bodyMedium),
          Text(l10n.estaNoNextWeeks, style: textTheme.titleMedium),
          choice(
            stayIdentifier,
            FilledButton(
              onPressed: () => close(onStay),
              child: Text(l10n.estaNoStay, textAlign: TextAlign.center),
            ),
          ),
          choice(
            pauseIdentifier,
            OutlinedButton(
              onPressed: () => close(onPause),
              child: Text(l10n.estaNoPause, textAlign: TextAlign.center),
            ),
          ),
          choice(
            mistakeIdentifier,
            TextButton(
              onPressed: () => close(onMistake),
              child: Text(l10n.estaNoMistake, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}
