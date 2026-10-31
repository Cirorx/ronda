import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Te escuchamos": records the voice note as soon as it opens, has it read,
/// and hands what was understood to the read-back.
class const VoiceNoteStep({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = VoiceNoteCubit(
          uid: context.read<AppBloc>().state.user.id,
          onboardingRepository: context.read<OnboardingRepository>(),
        );
        unawaited(cubit.start());
        return cubit;
      },
      child: const VoiceNoteView(),
    );
  }
}

/// The recorder, the reading screen, and the screens for a note that
/// couldn't be read or a microphone that can't be used: one screen under
/// "Tu audio", whose content swaps as the note moves on, each state read
/// out as it arrives. "Cancelar" leaves for the questions from any of them.
class const VoiceNoteView({super.key}) extends StatelessWidget {
  /// Maestro's handle on "Terminé".
  static const doneIdentifier = 'voice.done';

  /// Maestro's handle on "Borrar y empezar de nuevo".
  static const restartIdentifier = 'voice.restart';

  /// Maestro's handle on "Grabar de nuevo" and "Ya le di permiso".
  static const retryIdentifier = 'voice.retry';

  /// Maestro's handle on "Prefiero tocar botones".
  static const buttonsIdentifier = 'voice.buttons';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = context.select<VoiceNoteCubit, VoiceNoteStatus>(
      (cubit) => cubit.state.status,
    );
    final cubit = context.read<VoiceNoteCubit>();
    final onboarding = context.read<OnboardingCubit>();

    Widget action(String identifier, Widget button) => MergeSemantics(
      child: Semantics(identifier: identifier, child: button),
    );
    final preferButtons = action(
      buttonsIdentifier,
      TextButton(
        onPressed: onboarding.voiceCancelled,
        child: Text(l10n.voicePreferButtons),
      ),
    );
    Widget retry(String label) => action(
      retryIdentifier,
      FilledButton(onPressed: cubit.start, child: Text(label)),
    );

    // Starting, recording and read share the recorder's screen.
    final shows = switch (status) {
      VoiceNoteStatus.starting ||
      VoiceNoteStatus.recording ||
      VoiceNoteStatus.read => VoiceNoteStatus.recording,
      _ => status,
    };
    OnboardingStepLayout layout({
      required String title,
      required String body,
      required Widget primaryAction,
      required Widget child,
      Widget? secondaryAction,
    }) => OnboardingStepLayout(
      barTitle: l10n.voiceBarTitle,
      title: title,
      body: body,
      liveTitle: shows != VoiceNoteStatus.recording,
      stateKey: shows,
      onBack: onboarding.voiceCancelled,
      backLabel: l10n.voiceCancel,
      primaryAction: primaryAction,
      secondaryAction: secondaryAction,
      child: child,
    );

    return BlocListener<VoiceNoteCubit, VoiceNoteState>(
      listenWhen: (previous, current) =>
          current.status == VoiceNoteStatus.read &&
          previous.status != VoiceNoteStatus.read,
      listener: (context, state) {
        // Not once the person cancelled: this screen may still be leaving.
        if (!onboarding.state.recording) return;
        if (state.signup case final signup?) onboarding.voiceRead(signup);
      },
      child: switch (shows) {
        VoiceNoteStatus.starting ||
        VoiceNoteStatus.recording ||
        VoiceNoteStatus.read => layout(
          title: l10n.voiceTitle,
          body: l10n.voiceBody,
          primaryAction: action(
            doneIdentifier,
            FilledButton(
              onPressed: status == VoiceNoteStatus.recording
                  ? cubit.finish
                  : null,
              child: Text(l10n.voiceDone),
            ),
          ),
          secondaryAction: action(
            restartIdentifier,
            TextButton(
              onPressed: status == VoiceNoteStatus.recording
                  ? cubit.restart
                  : null,
              child: Text(l10n.voiceRestart),
            ),
          ),
          child: const _Recording(),
        ),
        VoiceNoteStatus.reading => layout(
          title: l10n.voiceReadingTitle,
          body: l10n.voiceReadingBody,
          primaryAction: LinearProgressIndicator(
            semanticsLabel: l10n.voiceReadingTitle,
          ),
          child: _Lines([
            l10n.voiceReadingTranscribe,
            l10n.voiceReadingFields,
            l10n.voiceReadingDelete,
          ]),
        ),
        VoiceNoteStatus.notUnderstood => layout(
          title: l10n.voiceNotUnderstoodTitle,
          body: l10n.voiceNotUnderstoodBody,
          primaryAction: retry(l10n.voiceRecordAgain),
          secondaryAction: preferButtons,
          child: _Lines(heading: l10n.voiceTipsHeading, [
            l10n.voiceTipQuiet,
            l10n.voiceTipClose,
            l10n.voiceTipLength,
          ]),
        ),
        VoiceNoteStatus.failure => layout(
          title: l10n.voiceFailureTitle,
          body: l10n.voiceFailureBody,
          primaryAction: retry(l10n.voiceRecordAgain),
          secondaryAction: preferButtons,
          child: const SizedBox.shrink(),
        ),
        VoiceNoteStatus.microphoneDenied => layout(
          title: l10n.microphoneDeniedTitle,
          body: l10n.microphoneDeniedBody,
          primaryAction: retry(l10n.microphoneDeniedRetry),
          secondaryAction: preferButtons,
          child: _Lines(heading: l10n.microphoneDeniedStepsHeading, [
            l10n.microphoneDeniedStepSettings,
            l10n.microphoneDeniedStepPermission,
            l10n.microphoneDeniedStepReturn,
          ], numbered: true),
        ),
      },
    );
  }
}

/// The timer, the ideas and the line that the audio is deleted once read.
class const _Recording() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.appSpacing;
    final elapsed = context.select<VoiceNoteCubit, Duration>(
      (cubit) => cubit.state.elapsed,
    );
    String clock(Duration duration) =>
        '${duration.inMinutes}:'
        '${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.lg,
      children: [
        Row(
          spacing: spacing.sm,
          children: [
            Icon(Icons.mic, color: theme.colorScheme.error),
            Text(
              l10n.voiceElapsed(clock(elapsed), clock(VoiceNoteCubit.limit)),
              style: theme.textTheme.headlineSmall,
            ),
          ],
        ),
        // Each second's tick fills on, rather than stepping.
        SpringBuilder(
          value: elapsed.inSeconds / VoiceNoteCubit.limit.inSeconds,
          builder: (context, value, _) =>
              LinearProgressIndicator(value: value.clamp(0, 1)),
        ),
        const VoiceIdeas(),
        NoteBanner(
          variant: NoteBannerVariant.keptOnPhone,
          icon: Icons.delete_outline,
          message: l10n.voiceDeletedOnRead,
        ),
      ],
    );
  }
}

/// A short list of lines, numbered or not, under an optional heading.
class const _Lines(
  final List<String> lines, {
  final String? heading,
  final bool numbered = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: context.appSpacing.xs,
      children: [
        if (heading case final heading?)
          Semantics(
            header: true,
            child: Text(heading, style: textTheme.titleMedium),
          ),
        for (final (index, line) in lines.indexed)
          Text(
            numbered ? '${index + 1}. $line' : '· $line',
            style: textTheme.bodyLarge,
          ),
      ],
    );
  }
}
