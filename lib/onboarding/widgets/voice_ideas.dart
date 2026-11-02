import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/widgets/onboarding_labels.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Qué contar": a sentence the person can almost read aloud, then what it
/// must not leave out, one line for each answer the sign-up needs. A note
/// that says all of them goes straight to the read-back.
class const VoiceIdeas({super.key}) extends StatelessWidget {
  /// One line for each answer, in the order the example says them. The
  /// options are the pickers' own labels, mid-sentence; "Tengo ganas" is
  /// left out, since it is what bringing nothing already means.
  static List<String> checklist(AppLocalizations l10n) {
    String options(Iterable<String> labels) =>
        labels.map((label) => label.toLowerCase()).join(', ');
    return [
      l10n.voiceIdeaName,
      l10n.voiceIdeaAge,
      l10n.voiceIdeaBarrio,
      l10n.voiceIdeaPretexts(options(Pretext.values.map(l10n.pretext))),
      l10n.voiceIdeaSlots,
      l10n.voiceIdeaBrings(
        options([
          for (final bring in Bring.values)
            if (bring != Bring.tengoGanas) l10n.bring(bring),
        ]),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.xs,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.voiceIdeasHeading,
            style: theme.textTheme.titleMedium,
          ),
        ),
        Text(l10n.voiceIdeasExample, style: theme.textTheme.bodyLarge),
        SizedBox(height: spacing.xs),
        Text(
          l10n.voiceIdeasChecklistHeading,
          style: theme.textTheme.titleSmall,
        ),
        for (final idea in checklist(l10n))
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing.sm,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.check,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(child: Text(idea, style: theme.textTheme.bodyMedium)),
            ],
          ),
      ],
    );
  }
}
