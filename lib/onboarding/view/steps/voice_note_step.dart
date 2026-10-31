import 'dart:async';

import 'package:error_reporter/error_reporter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Te escuchamos": waits for "Grabar", records the voice note while the
/// waveform follows the voice, has it read, and hands what was understood
/// to the read-back. Nothing records before the tap.
///
/// Each new failure goes to the error log ([ErrorReporter.reportFailure],
/// `voice/<failure>/<server code>`), except a missing or refused
/// microphone: that is the person's choice or setup, not a bug.
class const VoiceNoteStep({super.key}) extends StatelessWidget {
  /// The step every voice failure is reported under.
  static const reportStep = 'voice';

  /// The error log's code for [failure]: `voice/<failure>`, then
  /// `/<serverCode>` when the server answered one
  /// (`voice/uploadFailed/unauthorized`).
  static String reportCode(VoiceNoteFailure failure, String? serverCode) =>
      ['voice', failure.name, ?serverCode].join('/');

  /// Failures that are not Ronda's to fix, so never reported.
  static const Set<VoiceNoteFailure> unreported = {
    VoiceNoteFailure.noMicrophone,
    VoiceNoteFailure.microphoneDenied,
  };

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => VoiceNoteCubit(
        uid: context.read<AppBloc>().state.user.id,
        onboardingRepository: context.read<OnboardingRepository>(),
      ),
      child: BlocListener<VoiceNoteCubit, VoiceNoteState>(
        listenWhen: (previous, current) =>
            current.failure != null && current.failure != previous.failure,
        listener: (context, state) {
          final failure = state.failure!;
          if (unreported.contains(failure)) return;
          unawaited(
            context.read<ErrorReporter?>()?.reportFailure(
              screen: OnboardingPage.path,
              step: reportStep,
              code: reportCode(failure, state.failureCode),
            ),
          );
        },
        child: const VoiceNoteView(),
      ),
    );
  }
}

/// The recorder, the reading screen, and a screen for each way it can fail:
/// one screen under "Tu audio", whose content swaps as the note moves on,
/// each state read out as it arrives. "Cancelar" leaves for the questions
/// from any of them.
class const VoiceNoteView({
  /// Whether this runs in a browser, where the microphone is allowed from
  /// the address bar rather than the phone's settings.
  final bool web = kIsWeb,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handle on "Grabar".
  static const recordIdentifier = 'voice.record';

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
    final failure = context.select<VoiceNoteCubit, VoiceNoteFailure?>(
      (cubit) => cubit.state.failure,
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
    // The only way on, when trying again won't help.
    final onlyButtons = action(
      buttonsIdentifier,
      FilledButton(
        onPressed: onboarding.voiceCancelled,
        child: Text(l10n.voicePreferButtons),
      ),
    );
    Widget retry(String label) => action(
      retryIdentifier,
      FilledButton(onPressed: cubit.start, child: Text(label)),
    );

    // Starting shares the ready screen, read the recorder's, until the
    // read-back takes over.
    final Object shows = switch (status) {
      VoiceNoteStatus.ready ||
      VoiceNoteStatus.starting => VoiceNoteStatus.ready,
      VoiceNoteStatus.recording ||
      VoiceNoteStatus.read => VoiceNoteStatus.recording,
      VoiceNoteStatus.failed => failure ?? VoiceNoteFailure.readFailed,
      _ => status,
    };
    OnboardingStepLayout layout({
      required String title,
      required String body,
      required Widget primaryAction,
      Widget child = const SizedBox.shrink(),
      Widget? secondaryAction,
    }) => OnboardingStepLayout(
      barTitle: l10n.voiceBarTitle,
      title: title,
      body: body,
      liveTitle:
          shows != VoiceNoteStatus.ready && shows != VoiceNoteStatus.recording,
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
        VoiceNoteStatus.ready => layout(
          title: l10n.voiceTitle,
          body: l10n.voiceReadyBody,
          primaryAction: action(
            recordIdentifier,
            FilledButton.icon(
              onPressed: status == VoiceNoteStatus.ready ? cubit.start : null,
              icon: const Icon(Icons.mic),
              label: Text(l10n.voiceRecord),
            ),
          ),
          child: const _Ideas(),
        ),
        VoiceNoteStatus.recording => layout(
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
        VoiceNoteFailure.noMicrophone => layout(
          title: l10n.voiceNoMicrophoneTitle,
          body: l10n.voiceNoMicrophoneBody,
          primaryAction: retry(l10n.voiceRecordAgain),
          secondaryAction: preferButtons,
        ),
        VoiceNoteFailure.microphoneDenied => layout(
          title: l10n.microphoneDeniedTitle,
          body: web
              ? l10n.microphoneDeniedBrowserBody
              : l10n.microphoneDeniedBody,
          primaryAction: retry(l10n.microphoneDeniedRetry),
          secondaryAction: preferButtons,
          child: _Lines(
            heading: l10n.microphoneDeniedStepsHeading,
            web
                ? [
                    l10n.microphoneDeniedBrowserStepLock,
                    l10n.microphoneDeniedBrowserStepAllow,
                    l10n.microphoneDeniedBrowserStepReturn,
                  ]
                : [
                    l10n.microphoneDeniedStepSettings,
                    l10n.microphoneDeniedStepPermission,
                    l10n.microphoneDeniedStepReturn,
                  ],
            numbered: true,
          ),
        ),
        VoiceNoteFailure.recorderFailed => layout(
          title: l10n.voiceRecorderFailedTitle,
          body: l10n.voiceRecorderFailedBody,
          primaryAction: retry(l10n.voiceRecordAgain),
          secondaryAction: preferButtons,
        ),
        VoiceNoteFailure.termsMissing => layout(
          title: l10n.voiceTermsMissingTitle,
          body: l10n.voiceTermsMissingBody,
          primaryAction: onlyButtons,
        ),
        VoiceNoteFailure.uploadRefused => layout(
          title: l10n.voiceUploadFailedTitle,
          body: l10n.voiceUploadRefusedBody,
          primaryAction: onlyButtons,
        ),
        VoiceNoteFailure.uploadFailed => layout(
          title: l10n.voiceUploadFailedTitle,
          body: l10n.voiceUploadFailedBody,
          primaryAction: retry(l10n.voiceRecordAgain),
          secondaryAction: preferButtons,
        ),
        _ => layout(
          title: l10n.voiceFailureTitle,
          body: l10n.voiceFailureBody,
          primaryAction: retry(l10n.voiceRecordAgain),
          secondaryAction: preferButtons,
        ),
      },
    );
  }
}

/// The ideas to talk about and the line that the audio is deleted once
/// read, before and while recording.
class const _Ideas() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: context.appSpacing.lg,
      children: [
        const VoiceIdeas(),
        NoteBanner(
          variant: NoteBannerVariant.keptOnPhone,
          icon: Icons.delete_outline,
          message: context.l10n.voiceDeletedOnRead,
        ),
      ],
    );
  }
}

/// "Grabando" and the timer, the waveform, the warning when nothing is
/// heard, then the ideas.
class const _Recording() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.appSpacing;
    final elapsed = context.select<VoiceNoteCubit, Duration>(
      (cubit) => cubit.state.elapsed,
    );
    final levels = context.select<VoiceNoteCubit, List<double>>(
      (cubit) => cubit.state.levels,
    );
    final heard = context.select<VoiceNoteCubit, int>(
      (cubit) => cubit.state.heard,
    );
    final silent = context.select<VoiceNoteCubit, bool>(
      (cubit) => cubit.state.silent,
    );
    String clock(Duration duration) =>
        '${duration.inMinutes}:'
        '${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.lg,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.sm,
          children: [
            // Wraps under the timer at large text rather than overflowing.
            Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.mic, color: theme.colorScheme.error),
                // Read out once, as recording starts; the time is read when
                // the person moves to it, not every second.
                Semantics(
                  container: true,
                  liveRegion: true,
                  child: Text(
                    l10n.voiceRecording,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Semantics(
                  container: true,
                  child: Text(
                    l10n.voiceElapsed(
                      clock(elapsed),
                      clock(VoiceNoteCubit.limit),
                    ),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            VoiceWaveform(
              levels: levels,
              heard: heard,
              length: VoiceNoteCubit.waveformLength,
            ),
            // Each second's tick fills on, rather than stepping.
            SpringBuilder(
              value: elapsed.inSeconds / VoiceNoteCubit.limit.inSeconds,
              builder: (context, value, _) =>
                  LinearProgressIndicator(value: value.clamp(0, 1)),
            ),
            if (silent)
              Semantics(
                container: true,
                liveRegion: true,
                child: Row(
                  spacing: spacing.sm,
                  children: [
                    Icon(
                      Icons.mic_off_outlined,
                      color: context.rondaPalette.danger,
                    ),
                    Expanded(
                      child: Text(
                        l10n.voiceSilent,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: context.rondaPalette.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const _Ideas(),
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
