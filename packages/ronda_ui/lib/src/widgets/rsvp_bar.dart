import 'package:ronda_ui/ronda_ui.dart';

/// {@template rsvp_bar}
/// The weekly question on the Mi ronda card: "¿Venís?", what the person
/// brings this week, and "Voy" / "Esta no". "Esta no" never asks why.
///
/// It draws no card of its own, so it sits inside the ronda card. The
/// buttons sit side by side and stack with large text. Their semantics
/// identifiers are `<identifier>.yes` and `<identifier>.no`.
/// {@endtemplate}
class const RsvpBar({
  /// Prefix of the buttons' semantics identifiers ("rsvp").
  required final String identifier,

  /// The question ("¿Venís?").
  required final String question,

  /// What the "yes" button says ("Voy").
  required final String yesLabel,

  /// What the "no" button says ("Esta no").
  required final String noLabel,

  /// Called when the person says they're going.
  required final VoidCallback onYes,

  /// Called when the person skips this week.
  required final VoidCallback onNo,

  /// An optional line under the question ("Te toca llevar el pan.").
  final String? message,
  super.key,
}) extends StatelessWidget {
  /// {@macro rsvp_bar}
  this;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final yes = MergeSemantics(
      child: Semantics(
        identifier: '$identifier.yes',
        child: FilledButton(
          onPressed: onYes,
          child: Text(yesLabel, textAlign: TextAlign.center),
        ),
      ),
    );
    final no = MergeSemantics(
      child: Semantics(
        identifier: '$identifier.no',
        child: OutlinedButton(
          onPressed: onNo,
          child: Text(noLabel, textAlign: TextAlign.center),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.sm,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(question, style: textTheme.headlineMedium),
            ),
            if (message case final message?)
              Text(message, style: textTheme.bodyMedium),
          ],
        ),
        if (context.usesLargeText) ...[
          yes,
          no,
        ] else
          Row(
            spacing: spacing.sm,
            children: [
              Expanded(child: yes),
              Expanded(child: no),
            ],
          ),
      ],
    );
  }
}
