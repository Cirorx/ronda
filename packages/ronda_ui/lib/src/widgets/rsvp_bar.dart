import 'package:ronda_ui/ronda_ui.dart';

/// One of an [RsvpBar]'s two answers.
enum RsvpBarAnswer {
  /// "Voy", "Lo tomo", "Sí, puede ser".
  yes,

  /// "Esta no", "Paso", "Mejor no".
  no,
}

/// {@template rsvp_bar}
/// The weekly question on the Mi ronda card: "¿Venís?", what the person
/// brings this week, and "Voy" / "Esta no". "Esta no" never asks why. Any
/// card's two-answer question uses it too ("Lo tomo" / "Paso").
///
/// It draws no card of its own, so it sits inside the ronda card. The
/// buttons sit side by side and stack with large text. Their semantics
/// identifiers are `<identifier>.yes` and `<identifier>.no`. Either answer
/// is a commit, felt as [RondaHaptics.commit] on the tap.
///
/// While an answer is on its way ([pending]), the button that was pressed
/// keeps its look with a progress ring ([BusyLabel]) and can't be pressed
/// again, the other one is off, and [savingLabel] is read out under them
/// ([StatusLine]).
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

  /// The answer on its way, if one is.
  final RsvpBarAnswer? pending,

  /// The line read out while [pending] ("Guardando tu respuesta…").
  final String? savingLabel,
  super.key,
}) extends StatelessWidget {
  /// {@macro rsvp_bar}
  this;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final pending = this.pending;

    Widget button(
      RsvpBarAnswer answer,
      String label,
      VoidCallback onAnswer, {
      required bool filled,
    }) {
      final pressed = pending == answer;
      // While an answer is on its way, the pressed button keeps its look
      // but can't be pressed again, and the other one is off.
      final onPressed = pending == null
          ? RondaHaptics.onCommit(onAnswer)
          : (pressed ? () {} : null);
      final child = BusyLabel(label, busy: pressed);
      return MergeSemantics(
        child: Semantics(
          identifier: '$identifier.${answer.name}',
          child: IgnorePointer(
            ignoring: pressed,
            child: filled
                ? FilledButton(onPressed: onPressed, child: child)
                : OutlinedButton(onPressed: onPressed, child: child),
          ),
        ),
      );
    }

    final yes = button(RsvpBarAnswer.yes, yesLabel, onYes, filled: true);
    final no = button(RsvpBarAnswer.no, noLabel, onNo, filled: false);

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
        if ((pending, savingLabel) case (_?, final label?)) StatusLine(label),
      ],
    );
  }
}
