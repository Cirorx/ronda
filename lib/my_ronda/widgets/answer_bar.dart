import 'package:ronda/app/widgets/feedback.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// One of an [AnswerBar]'s two answers.
enum AnswerSide {
  /// "Voy", "Lo tomo", "Sí".
  yes,

  /// "Esta no", "Esta vez no", "No".
  no,
}

/// {@template answer_bar}
/// A card's two-answer question ("¿Venís?" with "Voy" and "Esta no"): the
/// shared [RsvpBar] while nothing is on its way, and once one answer is
/// ([pending]), the same bar with a progress ring on the button that was
/// pressed, the other one off, and [savingLabel] read out under it.
///
/// The buttons keep [RsvpBar]'s semantics identifiers
/// (`<identifier>.yes`, `<identifier>.no`), and the commit is felt once, by
/// [RsvpBar], on the tap.
/// {@endtemplate}
class const AnswerBar({
  /// Prefix of the buttons' semantics identifiers ("rsvp").
  required final String identifier,

  /// The question ("¿Venís?").
  required final String question,

  /// What the "yes" button says ("Voy").
  required final String yesLabel,

  /// What the "no" button says ("Esta no").
  required final String noLabel,

  /// Called when the person says yes.
  required final VoidCallback onYes,

  /// Called when the person says no.
  required final VoidCallback onNo,

  /// The line read out while an answer is on its way ("Guardando tu
  /// respuesta…").
  required final String savingLabel,

  /// An optional line under the question.
  final String? message,

  /// The answer on its way, if one is.
  final AnswerSide? pending,
  super.key,
}) extends StatelessWidget {
  /// {@macro answer_bar}
  this;

  @override
  Widget build(BuildContext context) {
    final pending = this.pending;
    if (pending == null) {
      return RsvpBar(
        identifier: identifier,
        question: question,
        message: message,
        yesLabel: yesLabel,
        noLabel: noLabel,
        onYes: onYes,
        onNo: onNo,
      );
    }
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;

    Widget button(AnswerSide side, String label, {required bool filled}) {
      final pressed = pending == side;
      final child = BusyLabel(label, busy: pressed);
      // The pressed button keeps its look but can't be pressed again; the
      // other one is off until the answer is in.
      final onPressed = pressed ? () {} : null;
      return MergeSemantics(
        child: Semantics(
          identifier: '$identifier.${side.name}',
          child: IgnorePointer(
            ignoring: pressed,
            child: filled
                ? FilledButton(onPressed: onPressed, child: child)
                : OutlinedButton(onPressed: onPressed, child: child),
          ),
        ),
      );
    }

    final yes = button(AnswerSide.yes, yesLabel, filled: true);
    final no = button(AnswerSide.no, noLabel, filled: false);
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
        StatusLine(savingLabel),
      ],
    );
  }
}
