import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/cubit/voice_note_cubit.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Estamos leyendo tu audio", as it really goes: the three steps with the
/// one under way breathing, the words as soon as Voice Transcribe hands
/// them back, and a barrio line that changes every few seconds while it
/// waits.
class const VoiceReading({
  /// The step under way.
  required final VoiceNoteStage stage,

  /// How long it has waited, which picks the line.
  required final Duration waited,

  /// The words heard, once they are back.
  final String? transcript,

  /// Whether every step is done (the answers are in).
  final bool done = false,
  super.key,
}) extends StatelessWidget {
  /// How long each line stays before the next one.
  static const lineSeconds = 3;

  /// The lines, in the order they come round.
  static List<String> lines(AppLocalizations l10n) => [
    l10n.voiceReadingLineMate,
    l10n.voiceReadingLineBizcochos,
    l10n.voiceReadingLineSillas,
    l10n.voiceReadingLineAgua,
    l10n.voiceReadingLineMazo,
    l10n.voiceReadingLinePelota,
    l10n.voiceReadingLineLluvia,
    l10n.voiceReadingLineBanco,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.appSpacing;
    final all = lines(l10n);
    final line = (waited.inSeconds ~/ lineSeconds) % all.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.lg,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.sm,
          children: [
            for (final step in VoiceNoteStage.values)
              _Stage(
                label: switch (step) {
                  VoiceNoteStage.uploading => l10n.voiceReadingUpload,
                  VoiceNoteStage.listening => l10n.voiceReadingListen,
                  VoiceNoteStage.understanding => l10n.voiceReadingUnderstand,
                },
                progress: switch (step.index.compareTo(stage.index)) {
                  _ when done => _Progress.done,
                  < 0 => _Progress.done,
                  0 => _Progress.now,
                  _ => _Progress.next,
                },
              ),
          ],
        ),
        RondaSwap(
          layoutBuilder: RondaSwap.topStartLayout,
          child: switch (transcript) {
            final words? => _Heard(key: const ValueKey('heard'), words: words),
            null => const SizedBox.shrink(key: ValueKey('waiting')),
          },
        ),
        // Not read out as it changes: it is company, not news.
        RondaSwap(
          layoutBuilder: RondaSwap.topStartLayout,
          child: Text(
            all[line],
            key: ValueKey(line),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (transcript != null)
          NoteBanner(
            variant: NoteBannerVariant.keptOnPhone,
            icon: Icons.delete_outline,
            message: l10n.reviewVoiceAudioDeleted,
          ),
      ],
    );
  }
}

enum _Progress { done, now, next }

/// One step: ticked once done, breathing while under way, an empty ring
/// still to come; each also said in words.
class const _Stage({
  required final String label,
  required final _Progress progress,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final icon = switch (progress) {
      _Progress.done => Icon(Icons.check_circle, color: colors.tertiary),
      _Progress.now => _Breathing(
        child: Icon(Icons.radio_button_checked, color: colors.primary),
      ),
      _Progress.next => Icon(
        Icons.radio_button_unchecked,
        color: colors.onSurfaceVariant,
      ),
    };
    return MergeSemantics(
      child: Semantics(
        // The step under way is read out as it starts.
        liveRegion: progress == _Progress.now,
        value: switch (progress) {
          _Progress.done => l10n.voiceReadingDone,
          _Progress.now => l10n.voiceReadingNow,
          _Progress.next => l10n.voiceReadingNext,
        },
        child: Row(
          spacing: context.appSpacing.sm,
          children: [
            ExcludeSemantics(child: icon),
            Expanded(
              child: Text(
                label,
                style: progress == _Progress.next
                    ? theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      )
                    : theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What Voice Transcribe heard, in the person's own words.
class const _Heard({required final String words, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(context.appSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: context.appSpacing.xs,
          children: [
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                context.l10n.voiceReadingHeard,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Text(
              context.l10n.voiceReadingQuote(words),
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// A slow breath in and out while a step is under way; still under reduced
/// motion.
class _Breathing extends StatefulWidget {
  const new({required this.child});

  final Widget child;

  /// One breath, in or out.
  static const Duration breath = Durations.extralong4;

  /// How small it gets at the bottom of a breath.
  static const smallest = 0.8;

  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _Breathing.breath,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: _Breathing.smallest,
  ).animate(CurvedAnimation(parent: _controller, curve: Easing.standard));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (RondaMotion.of(context).reduced) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
