import 'dart:async';

import 'package:error_reporter/error_reporter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/view/my_ronda_page.dart';
import 'package:ronda/onboarding/widgets/live_words.dart';
import 'package:ronda/onboarding/widgets/voice_waveform.dart';
import 'package:ronda/small_plan/cubit/small_plan_choose_cubit.dart';
import 'package:ronda/small_plan/models/models.dart';
import 'package:ronda/small_plan/widgets/small_plan_labels.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

/// "Elegí algo chico", in a sheet over Mi ronda: three ideas from near the
/// member, or "Decilo vos" (a voice note, or typing) shaped into a plan they
/// confirm with "¿Es esto?". It closes with the [SmallPlan] chosen and keeps
/// nothing itself.
///
/// Each new failure goes to the error log ([ErrorReporter.reportFailure],
/// `smallPlan/<failure>/<server code>`), except a missing or refused
/// microphone: that is the person's setup, not a bug.
class SmallPlanSheet extends StatelessWidget {
  const new({super.key});

  /// The step every failure is reported under.
  static const reportStep = 'smallPlan';

  /// Failures that are not Ronda's to fix, so never reported.
  static const Set<SmallPlanFailureKind> unreported = {
    SmallPlanFailureKind.noMicrophone,
    SmallPlanFailureKind.microphoneDenied,
    SmallPlanFailureKind.notUnderstood,
  };

  /// The error log's code for [kind]: `smallPlan/<kind>`, then
  /// `/<serverCode>` when the server answered one.
  static String reportCode(SmallPlanFailureKind kind, String? serverCode) =>
      ['smallPlan', kind.name, ?serverCode].join('/');

  /// Maestro's handles.
  static String ideaIdentifier(int index) => 'smallPlan.idea.$index';
  static const sayIdentifier = 'smallPlan.say';
  static const recordIdentifier = 'smallPlan.record';
  static const typedIdentifier = 'smallPlan.typed';
  static const sendIdentifier = 'smallPlan.send';
  static const backIdentifier = 'smallPlan.back';
  static const doneIdentifier = 'smallPlan.done';
  static const cancelIdentifier = 'smallPlan.cancel';
  static const confirmIdentifier = 'smallPlan.confirm';
  static const againIdentifier = 'smallPlan.again';
  static const retryIdentifier = 'smallPlan.retry';

  /// Opens the sheet over [context]; it resolves with the plan chosen, or
  /// `null` when the sheet was closed without one.
  static Future<SmallPlan?> show(BuildContext context, {required String uid}) {
    final repository = context.read<SmallPlanRepository>();
    // Read here: the sheet's route sits above whatever `context` sees.
    final reporter = context.read<ErrorReporter?>();
    return showRondaSheet<SmallPlan>(
      context: context,
      builder: (_) => RepositoryProvider<ErrorReporter?>.value(
        value: reporter,
        child: BlocProvider(
          create: (_) {
            final cubit = SmallPlanChooseCubit(
              uid: uid,
              smallPlanRepository: repository,
            );
            unawaited(cubit.load());
            return cubit;
          },
          child: const SmallPlanSheet(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SmallPlanChooseCubit, SmallPlanChooseState>(
          listenWhen: (previous, current) =>
              current.chosen != null && previous.chosen != current.chosen,
          listener: (context, state) => Navigator.of(context).pop(state.chosen),
        ),
        BlocListener<SmallPlanChooseCubit, SmallPlanChooseState>(
          listenWhen: (previous, current) =>
              current.failure != null && current.failure != previous.failure,
          listener: (context, state) {
            final failure = state.failure!;
            if (unreported.contains(failure)) return;
            unawaited(
              context.read<ErrorReporter?>()?.reportFailure(
                screen: MyRondaPage.path,
                step: reportStep,
                code: reportCode(failure, state.failureCode),
              ),
            );
          },
        ),
      ],
      child: const _Content(),
    );
  }
}

class const _Content() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final step = context.select<SmallPlanChooseCubit, SmallPlanStep>(
      (cubit) => cubit.state.step,
    );
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: spacing.lg,
        right: spacing.lg,
        bottom: spacing.lg,
      ),
      child: RondaSwap(
        layoutBuilder: RondaSwap.topStartLayout,
        child: KeyedSubtree(
          key: ValueKey(step),
          child: switch (step) {
            SmallPlanStep.ideas => const _Ideas(),
            SmallPlanStep.say => const _Say(),
            SmallPlanStep.recording => const _Recording(),
            SmallPlanStep.reading => const _Reading(),
            SmallPlanStep.review => const _Review(),
          },
        ),
      ),
    );
  }
}

/// A sheet step: a title, a body and the step's own widgets.
class const _Step({
  required final String title,
  required final List<Widget> children,
  final String? body,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.md,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: textTheme.headlineSmall),
        ),
        if (body != null) Text(body!, style: textTheme.bodyMedium),
        ...children,
      ],
    );
  }
}

Widget _action(String identifier, Widget button) => MergeSemantics(
  child: Semantics(identifier: identifier, child: button),
);

class const _Ideas() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SmallPlanChooseCubit>();
    final state = context.watch<SmallPlanChooseCubit>().state;
    final spacing = context.appSpacing;

    return _Step(
      title: l10n.smallPlanSheetTitle,
      body: l10n.smallPlanSheetBody,
      children: [
        RondaSwap(
          layoutBuilder: RondaSwap.topStartLayout,
          child: switch (state.ideas) {
            SmallPlanIdeas.loading => LoadingStatus(
              l10n.smallPlanSuggestionsLoading,
              key: const ValueKey('loading'),
            ),
            SmallPlanIdeas.failure => Column(
              key: const ValueKey('failure'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spacing.sm,
              children: [
                Text(
                  l10n.smallPlanSuggestionsError,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                _action(
                  SmallPlanSheet.retryIdentifier,
                  OutlinedButton(
                    onPressed: cubit.load,
                    child: Text(l10n.smallPlanSuggestionsRetry),
                  ),
                ),
              ],
            ),
            SmallPlanIdeas.ready => Column(
              key: const ValueKey('ready'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spacing.sm,
              children: [
                for (final (index, suggestion) in state.suggestions.indexed)
                  _Idea(
                    index: index,
                    suggestion: suggestion,
                    onTap: () => cubit.suggestionTapped(suggestion),
                  ),
              ],
            ),
          },
        ),
        _action(
          SmallPlanSheet.sayIdentifier,
          FilledButton.icon(
            onPressed: cubit.sayTapped,
            icon: const Icon(Icons.mic),
            label: Text(l10n.smallPlanSayYours),
          ),
        ),
      ],
    );
  }
}

class const _Idea({
  required final int index,
  required final SmallPlanSuggestion suggestion,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plan = suggestion.plan;
    final note = l10n.forecastNote(
      outdoor: suggestion.outdoor,
      dry: suggestion.dry,
    );
    return PressScale(
      child: MergeSemantics(
        child: Semantics(
          identifier: SmallPlanSheet.ideaIdentifier(index),
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              onTap: onTap,
              title: Text(l10n.planWhat(plan)),
              subtitle: Text([l10n.planWhen(plan.at), ?note].join('\n')),
              trailing: const ExcludeSemantics(
                child: Icon(Icons.chevron_right),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class const _Say() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SmallPlanChooseCubit>();
    final state = context.watch<SmallPlanChooseCubit>().state;
    final problem = l10n.sayProblem(
      dropped: state.dropped,
      failure: state.failure,
    );
    final error = state.textTried || !state.text.isPure
        ? switch (state.text.error) {
            PlanTextValidationError.empty when state.textTried =>
              l10n.smallPlanTextEmpty,
            PlanTextValidationError.tooLong => l10n.smallPlanTextTooLong,
            _ => null,
          }
        : null;

    return _Step(
      title: l10n.smallPlanSayTitle,
      body: l10n.smallPlanSayBody,
      children: [
        if (problem != null)
          Semantics(
            liveRegion: true,
            child: NoteBanner(
              variant: NoteBannerVariant.warning,
              message: problem,
            ),
          ),
        _action(
          SmallPlanSheet.recordIdentifier,
          FilledButton.icon(
            onPressed: cubit.recordTapped,
            icon: const Icon(Icons.mic),
            label: Text(l10n.smallPlanSayRecord),
          ),
        ),
        Semantics(
          identifier: SmallPlanSheet.typedIdentifier,
          child: TextFormField(
            initialValue: state.text.value,
            onChanged: cubit.textChanged,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.smallPlanSayTypeLabel,
              hintText: l10n.smallPlanSayTypeHint,
              errorText: error,
            ),
          ),
        ),
        _action(
          SmallPlanSheet.sendIdentifier,
          FilledButton(
            onPressed: RondaHaptics.onCommit(cubit.textSubmitted),
            child: Text(l10n.smallPlanSayDone),
          ),
        ),
        _action(
          SmallPlanSheet.backIdentifier,
          TextButton(
            onPressed: cubit.ideasTapped,
            child: Text(l10n.smallPlanSayBack),
          ),
        ),
      ],
    );
  }
}

class const _Recording() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final spacing = context.appSpacing;
    final cubit = context.read<SmallPlanChooseCubit>();
    final state = context.watch<SmallPlanChooseCubit>().state;
    String clock(Duration duration) =>
        '${duration.inMinutes}:'
        '${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

    return _Step(
      title: l10n.smallPlanSayTitle,
      body: l10n.smallPlanRecordingBody,
      children: [
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(Icons.mic, color: theme.colorScheme.error),
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
                  clock(state.elapsed),
                  clock(SmallPlanChooseCubit.limit),
                ),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        VoiceWaveform(
          levels: state.levels,
          heard: state.heard,
          length: SmallPlanChooseCubit.waveformLength,
        ),
        if (state.words.isNotEmpty) LiveWords(words: state.words),
        SpringBuilder(
          value: state.elapsed.inSeconds / SmallPlanChooseCubit.limit.inSeconds,
          builder: (context, value, _) =>
              LinearProgressIndicator(value: value.clamp(0, 1)),
        ),
        if (state.silent)
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
        _action(
          SmallPlanSheet.doneIdentifier,
          FilledButton(
            onPressed: cubit.finishTapped,
            child: Text(l10n.smallPlanRecordingDone),
          ),
        ),
        _action(
          SmallPlanSheet.cancelIdentifier,
          TextButton(
            onPressed: cubit.recordingCancelled,
            child: Text(l10n.smallPlanRecordingCancel),
          ),
        ),
      ],
    );
  }
}

class const _Reading() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LoadingStatus(l10n.smallPlanReadingTitle);
  }
}

class const _Review() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SmallPlanChooseCubit>();
    final read = context.watch<SmallPlanChooseCubit>().state.read;
    // The step swaps out while its plan is already gone.
    if (read == null) return const SizedBox.shrink();
    // The server gives a day's forecast only for a plan outdoors.
    final note = l10n.forecastNote(outdoor: read.dry != null, dry: read.dry);
    return _Step(
      title: l10n.smallPlanReviewTitle,
      children: [
        Text(
          l10n.planLine(read.plan),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (read.moved) Text(l10n.smallPlanMoved),
        if (note != null) Text(note),
        _action(
          SmallPlanSheet.confirmIdentifier,
          FilledButton(
            onPressed: RondaHaptics.onCommit(cubit.confirmTapped),
            child: Text(l10n.smallPlanReviewYes),
          ),
        ),
        _action(
          SmallPlanSheet.againIdentifier,
          TextButton(
            onPressed: cubit.againTapped,
            child: Text(l10n.smallPlanReviewAgain),
          ),
        ),
      ],
    );
  }
}
