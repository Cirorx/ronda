import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Lo que vamos escuchando": the words Voice Transcribe has heard so far,
/// shown under the waveform while a note records and revised as the person
/// talks (`live_transcript`). Shown only when there are words: without live
/// transcription the note is read at the end, as before.
///
/// Not a live region: the text changes several times a second, so a screen
/// reader reads it when the person moves to it, not on every revision.
class const LiveWords({required final String words, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: context.appSpacing.xs,
        children: [
          Text(
            context.l10n.voiceLiveHeard,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(words, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
