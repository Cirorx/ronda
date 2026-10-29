import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Ideas de qué contar": a plain list while recording, and on the voice
/// read-back each idea ticked when the recording covered it.
class const VoiceIdeas({
  /// Per idea, in order, whether the recording covered it; `null` while
  /// recording, when nothing is ticked.
  final List<bool>? covered,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ideas = [
      l10n.voiceIdeaNameAndBarrio,
      l10n.voiceIdeaPretexts,
      l10n.voiceIdeaSlots,
      l10n.voiceIdeaBrings,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: context.appSpacing.xs,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.voiceIdeasHeading,
            style: theme.textTheme.titleMedium,
          ),
        ),
        for (final (index, idea) in ideas.indexed)
          _Idea(idea: idea, covered: covered?.elementAtOrNull(index)),
      ],
    );
  }
}

class const _Idea({required final String idea, final bool? covered})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (icon, color, state) = switch (covered) {
      true => (
        Icons.check_circle,
        theme.colorScheme.tertiary,
        l10n.voiceIdeaCovered,
      ),
      false => (
        Icons.radio_button_unchecked,
        theme.colorScheme.onSurfaceVariant,
        l10n.voiceIdeaNotCovered,
      ),
      null => (Icons.circle_outlined, theme.colorScheme.onSurfaceVariant, null),
    };
    return MergeSemantics(
      child: Semantics(
        value: state,
        child: Row(
          spacing: context.appSpacing.sm,
          children: [
            ExcludeSemantics(child: Icon(icon, color: color)),
            Expanded(child: Text(idea, style: theme.textTheme.bodyLarge)),
          ],
        ),
      ),
    );
  }
}
