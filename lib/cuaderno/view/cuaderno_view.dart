import 'dart:async';

import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:error_reporter/error_reporter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/cuaderno/cubit/cuaderno_cubit.dart';
import 'package:ronda/cuaderno/cubit/cuaderno_hook.dart';
import 'package:ronda/cuaderno/cubit/line_voice_cubit.dart';
import 'package:ronda/cuaderno/view/cuaderno_page.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/widgets/bench_labels.dart';
import 'package:ronda/onboarding/widgets/live_words.dart';
import 'package:ronda/onboarding/widgets/voice_waveform.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// El cuaderno's screen: today's line (typed, or said and then read back
/// to change), the week's postcard when it is time, and the lines written,
/// each with "Llevar esta línea" and "Borrar".
///
/// It shows no count, no streak and no score; a day with no line is a day
/// with no line. Every voice failure but a missing or refused microphone
/// goes to the error log under `cuaderno-voice/<problem>/<server code>`.
class const CuadernoView({
  /// Where this runs, which says where the microphone is allowed; this app
  /// instance's place ([PermissionPlace.current]) when not given.
  final PermissionPlace? place,
  super.key,
}) extends StatelessWidget {
  /// The step every voice failure is reported under.
  static const reportStep = 'cuaderno-voice';

  /// Maestro's handles.
  static const textIdentifier = 'cuaderno.text';
  static const writeIdentifier = 'cuaderno.write';
  static const voiceIdentifier = 'cuaderno.voice';
  static const voiceDoneIdentifier = 'cuaderno.voice.done';
  static const postcardIdentifier = 'cuaderno.postcard';
  static const shareIdentifier = 'cuaderno.postcard.share';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final state = context.watch<CuadernoCubit>().state;

    final body = switch (state.status) {
      CuadernoStatus.loading => LoadingStatus(l10n.cuadernoLoading),
      CuadernoStatus.failure => Column(
        spacing: spacing.sm,
        children: [
          Text(l10n.cuadernoLoadError),
          OutlinedButton(
            onPressed: context.read<CuadernoCubit>().retry,
            child: Text(l10n.cuadernoRetry),
          ),
        ],
      ),
      CuadernoStatus.ready => _Ready(
        state: state,
        place: place ?? PermissionPlace.current,
      ),
    };

    return MultiBlocListener(
      listeners: [
        BlocListener<LineVoiceCubit, LineVoiceState>(
          listenWhen: (previous, current) =>
              current.problem != null && current.problem != previous.problem,
          listener: (context, state) {
            final problem = state.problem!;
            if (problem == VoiceLineProblem.noMicrophone ||
                problem == VoiceLineProblem.microphoneDenied) {
              return;
            }
            unawaited(
              context.read<ErrorReporter?>()?.reportFailure(
                screen: CuadernoPage.path,
                step: reportStep,
                code: ['voice', problem.name, ?state.problemCode].join('/'),
              ),
            );
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.cuadernoTitle)),
        body: SafeArea(
          top: false,
          child: ReadableColumn(
            child: ListView(
              padding: EdgeInsets.all(spacing.md),
              children: [body],
            ),
          ),
        ),
      ),
    );
  }
}

class const _Ready({
  required final CuadernoState state,
  required final PermissionPlace place,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final failure = state.failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.lg,
      children: [
        _Today(state: state, place: place),
        if (failure != null)
          NoteBanner(
            variant: NoteBannerVariant.warning,
            message: switch (failure) {
              CuadernoFailure.write => l10n.cuadernoWriteFailed,
              CuadernoFailure.postcard => l10n.cuadernoPostcardFailed,
              CuadernoFailure.nothingToDraw => l10n.cuadernoPostcardNothing,
              CuadernoFailure.share => l10n.cuadernoPostcardShareFailed,
            },
          ),
        if (state.postcardOffered || state.postcard != null)
          _PostcardSection(state: state),
        _Lines(state: state),
        NoteBanner(
          variant: NoteBannerVariant.keptOnPhone,
          message: l10n.cuadernoKeptOnPhone,
        ),
      ],
    );
  }
}

/// The day's [EntryHook] with its field, "Anotar" and the voice.
class const _Today({
  required final CuadernoState state,
  required final PermissionPlace place,
}) extends StatefulWidget {
  @override
  State<_Today> createState() => _TodayState();
}

class _TodayState extends State<_Today> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.state.todaysLine?.text,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final voice = context.watch<LineVoiceCubit>().state;
    final writing = widget.state.writing;
    final wrote = widget.state.todaysLine != null;
    final voiceCubit = context.read<LineVoiceCubit>();

    String clock(Duration duration) =>
        '${duration.inMinutes}:'
        '${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

    final Widget voiceArea = switch (voice.status) {
      LineVoiceStatus.recording => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.sm,
        children: [
          Wrap(
            spacing: spacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.mic, color: Theme.of(context).colorScheme.error),
              Semantics(
                container: true,
                liveRegion: true,
                child: Text(l10n.voiceRecording, style: textTheme.titleMedium),
              ),
              Text(
                l10n.voiceElapsed(
                  clock(voice.elapsed),
                  clock(LineVoiceCubit.limit),
                ),
                style: textTheme.titleMedium,
              ),
            ],
          ),
          VoiceWaveform(
            levels: voice.levels,
            heard: voice.heard,
            length: LineVoiceCubit.waveformLength,
          ),
          if (voice.words.isNotEmpty) LiveWords(words: voice.words),
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MergeSemantics(
                child: Semantics(
                  identifier: CuadernoView.voiceDoneIdentifier,
                  child: FilledButton(
                    onPressed: voiceCubit.finish,
                    child: Text(l10n.voiceDone),
                  ),
                ),
              ),
              TextButton(
                onPressed: voiceCubit.cancel,
                child: Text(l10n.voiceCancel),
              ),
            ],
          ),
          Text(l10n.voiceDeletedOnRead, style: textTheme.bodySmall),
        ],
      ),
      LineVoiceStatus.reading => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.xs,
        children: [
          StatusLine(l10n.cuadernoVoiceReading),
          const LinearProgressIndicator(),
        ],
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.sm,
        children: [
          if (voice.problem case final problem?)
            NoteBanner(
              variant: NoteBannerVariant.warning,
              message: switch (problem) {
                VoiceLineProblem.noMicrophone => l10n.cuadernoVoiceNoMicrophone,
                VoiceLineProblem.microphoneDenied => switch (widget.place) {
                  PermissionPlace.app => l10n.cuadernoVoiceDenied,
                  PermissionPlace.browser => l10n.cuadernoVoiceDeniedBrowser,
                  PermissionPlace.iPhoneBrowser =>
                    l10n.cuadernoVoiceDeniedIphone,
                },
                VoiceLineProblem.notUnderstood =>
                  l10n.cuadernoVoiceNotUnderstood,
                VoiceLineProblem.termsMissing => l10n.cuadernoVoiceTermsMissing,
                _ => l10n.cuadernoVoiceFailed,
              },
            ),
          MergeSemantics(
            child: Semantics(
              identifier: CuadernoView.voiceIdentifier,
              child: OutlinedButton.icon(
                onPressed: voice.status == LineVoiceStatus.starting
                    ? null
                    : voiceCubit.start,
                icon: const Icon(Icons.mic),
                label: Text(l10n.cuadernoSayIt),
              ),
            ),
          ),
        ],
      ),
    };

    final recording =
        voice.status == LineVoiceStatus.recording ||
        voice.status == LineVoiceStatus.reading;

    return BlocListener<LineVoiceCubit, LineVoiceState>(
      listenWhen: (previous, current) =>
          current.status == LineVoiceStatus.read &&
          previous.status != LineVoiceStatus.read,
      listener: (context, voice) {
        if (voice.text case final text?) {
          _controller
            ..text = text
            ..selection = TextSelection.collapsed(offset: text.length);
        }
        context.read<LineVoiceCubit>().textTaken();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.sm,
        children: [
          Semantics(
            header: true,
            child: Text(switch (widget.state.hook) {
              EntryHook.afterMeeting => l10n.cuadernoEntryHookAfterMeeting,
              EntryHook.postcard => l10n.cuadernoEntryHookPostcard,
              EntryHook.rambla => l10n.cuadernoEntryHookRambla,
              EntryHook.corner => l10n.cuadernoEntryHookCorner,
              EntryHook.learned => l10n.cuadernoEntryHookLearned,
              EntryHook.bizcochos => l10n.cuadernoEntryHookBizcochos,
              EntryHook.bring => l10n.cuadernoEntryHookBring,
              EntryHook.helped => l10n.cuadernoEntryHookHelped,
              EntryHook.laugh => l10n.cuadernoEntryHookLaugh,
              EntryHook.smell => l10n.cuadernoEntryHookSmell,
              EntryHook.sound => l10n.cuadernoEntryHookSound,
              EntryHook.kindWord => l10n.cuadernoEntryHookKindWord,
              EntryHook.rondaLearned => l10n.cuadernoEntryHookRondaLearned,
              EntryHook.lookedNice => l10n.cuadernoEntryHookLookedNice,
              EntryHook.smallWin => l10n.cuadernoEntryHookSmallWin,
              EntryHook.thank => l10n.cuadernoEntryHookThank,
              EntryHook.goodNews => l10n.cuadernoEntryHookGoodNews,
            }, style: textTheme.titleLarge),
          ),
          if (!recording) ...[
            Semantics(
              identifier: CuadernoView.textIdentifier,
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 3,
                maxLength: CuadernoEntry.maxLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
                ],
                buildCounter: (
                  context, {
                  required currentLength,
                  required isFocused,
                  required maxLength,
                }) => null,
                decoration: InputDecoration(
                  labelText: l10n.cuadernoLineLabel,
                  hintText: l10n.cuadernoLineHint,
                ),
                onSubmitted: (_) => unawaited(
                  context.read<CuadernoCubit>().writeToday(_controller.text),
                ),
              ),
            ),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => MergeSemantics(
                child: Semantics(
                  identifier: CuadernoView.writeIdentifier,
                  child: FilledButton(
                    onPressed: writing || _controller.text.trim().isEmpty
                        ? null
                        : () => context.read<CuadernoCubit>().writeToday(
                            _controller.text,
                          ),
                    child: Text(
                      wrote ? l10n.cuadernoChangeToday : l10n.cuadernoWrite,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.state.wrote && !writing)
              StatusLine(l10n.cuadernoWritten),
          ],
          voiceArea,
        ],
      ),
    );
  }
}

/// The week's postcard: the offer, then the picture with "Guardar en el
/// teléfono".
class const _PostcardSection({required final CuadernoState state})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<CuadernoCubit>();
    final postcard = state.postcard;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing.sm,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.cuadernoPostcardTitle,
                style: textTheme.titleMedium,
              ),
            ),
            if (postcard != null) ...[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Image.memory(
                      postcard.image,
                      semanticLabel: l10n.cuadernoPostcardAlt,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              MergeSemantics(
                child: Semantics(
                  identifier: CuadernoView.shareIdentifier,
                  child: FilledButton(
                    onPressed: () => cubit.shareRequested(
                      title: l10n.cuadernoPostcardShareTitle,
                    ),
                    child: Text(l10n.cuadernoPostcardSave),
                  ),
                ),
              ),
              Text(l10n.cuadernoPostcardMemory, style: textTheme.bodySmall),
            ] else
              Text(l10n.cuadernoPostcardBody, style: textTheme.bodyMedium),
            if (state.makingPostcard)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.xs,
                children: [
                  StatusLine(l10n.cuadernoPostcardMaking),
                  const LinearProgressIndicator(),
                ],
              )
            else if (state.postcardOffered)
              MergeSemantics(
                child: Semantics(
                  identifier: CuadernoView.postcardIdentifier,
                  child: postcard == null
                      ? FilledButton(
                          onPressed: cubit.postcardRequested,
                          child: Text(l10n.cuadernoPostcardMake),
                        )
                      : OutlinedButton(
                          onPressed: cubit.postcardRequested,
                          child: Text(l10n.cuadernoPostcardAgain),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The lines written, newest first; each can be brought to the meeting or
/// deleted (with "Deshacer").
class const _Lines({required final CuadernoState state})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    final entries = state.cuaderno.entries;
    final bringDay = state.cuaderno.brought?.key;
    final cubit = context.read<CuadernoCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.sm,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.cuadernoLinesTitle, style: textTheme.titleMedium),
        ),
        if (entries.isEmpty) ...[
          const RondaSketch(RondaScene.openCuaderno, height: 96),
          Text(l10n.cuadernoEmpty, style: textTheme.bodyLarge),
        ] else ...[
          Text(l10n.cuadernoBringExplain, style: textTheme.bodySmall),
          for (final entry in entries)
            Card(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: spacing.md,
                  top: spacing.xs,
                  bottom: spacing.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: spacing.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: spacing.xxs,
                          children: [
                            Text(
                              l10n.dayDate(entry.day),
                              style: textTheme.labelLarge,
                            ),
                            Text(entry.text, style: textTheme.bodyLarge),
                            if (entry.key == bringDay)
                              Text(
                                l10n.cuadernoBringing,
                                style: textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ),
                    PopupMenuButton<_LineAction>(
                      tooltip: l10n.cuadernoLineMenu(l10n.dayDate(entry.day)),
                      onSelected: (action) {
                        switch (action) {
                          case _LineAction.bring:
                            unawaited(cubit.bringToggled(entry, bring: true));
                          case _LineAction.stopBringing:
                            unawaited(cubit.bringToggled(entry, bring: false));
                          case _LineAction.delete:
                            unawaited(cubit.deleteEntry(entry));
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(l10n.cuadernoLineDeleted),
                                  action: SnackBarAction(
                                    label: l10n.cuadernoUndo,
                                    onPressed: () =>
                                        unawaited(cubit.restoreEntry(entry)),
                                  ),
                                ),
                              );
                        }
                      },
                      itemBuilder: (context) => [
                        if (entry.key == bringDay)
                          PopupMenuItem(
                            value: _LineAction.stopBringing,
                            child: Text(l10n.cuadernoBringStop),
                          )
                        else
                          PopupMenuItem(
                            value: _LineAction.bring,
                            child: Text(l10n.cuadernoBring),
                          ),
                        PopupMenuItem(
                          value: _LineAction.delete,
                          child: Text(l10n.cuadernoDelete),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

enum _LineAction { bring, stopBringing, delete }
