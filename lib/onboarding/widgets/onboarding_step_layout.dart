import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/widgets/onboarding_step_switcher.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// {@template onboarding_step_layout}
/// One onboarding screen: a back button and the progress through the
/// questions (or the screen's [barTitle]), a title and a short body, the
/// step's own [child], and the actions pinned under it.
///
/// The content scrolls, so the screen holds at 200% text. A screen that
/// moves through several states (the recorder, then reading) gives each its
/// [stateKey]: a change swaps the content and the actions in place, under
/// the same top bar.
/// {@endtemplate}
class const OnboardingStepLayout({
  /// The screen's title, read as a heading.
  required final String title,

  /// The step's picker or field.
  required final Widget child,

  /// The primary action ("Seguir", "Está bien, guardalo").
  required final Widget primaryAction,

  /// The text under the title.
  final String? body,

  /// A short line above the title ("Opcional").
  final String? overline,

  /// The question's number, from 1, or `null` on the read-back.
  final int? questionNumber,

  /// How many questions there are.
  final int questionCount = 0,

  /// Called by the back button; no back button when `null`.
  final VoidCallback? onBack,

  /// Shows the back button as this word ("Cancelar") instead of an arrow.
  final String? backLabel,

  /// An optional action under the primary one ("Saltear").
  final Widget? secondaryAction,

  /// The screen's name in the top bar where there is no progress to show
  /// ("Tus respuestas" on the read-back).
  final String? barTitle,

  /// Whether the title is read out when it appears or changes: a status
  /// that arrives on its own, such as "Estamos leyendo tu audio".
  final bool liveTitle = false,

  /// The state this screen shows, when it moves through several; a new
  /// value swaps the content and the actions ([RondaSwap]).
  final Object? stateKey,
  super.key,
}) extends StatelessWidget {
  /// {@macro onboarding_step_layout}
  this;

  /// Maestro's handle on the back button.
  static const backIdentifier = 'onboarding.back';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: backLabel == null ? null : spacing.lg * 6,
        leading: switch (onBack) {
          final onBack? => MergeSemantics(
            child: Semantics(
              identifier: backIdentifier,
              child: switch (backLabel) {
                final label? => TextButton(
                  onPressed: onBack,
                  child: Text(label),
                ),
                null => IconButton(
                  tooltip: l10n.onboardingBack,
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
              },
            ),
          ),
          null => null,
        },
        title: switch ((questionNumber, barTitle)) {
          (final number?, _) => _Progress(number: number, count: questionCount),
          (null, final barTitle?) => Text(barTitle),
          (null, null) => null,
        },
      ),
      body: SafeArea(
        child: switch (stateKey) {
          final stateKey? => RondaSwap(
            layoutBuilder: _fill,
            child: KeyedSubtree(
              key: ValueKey(stateKey),
              child: _content(context),
            ),
          ),
          null => _content(context),
        },
      ),
    );
  }

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.sm,
            ),
            children: [
              if (overline case final overline?)
                Text(
                  overline,
                  style: textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              Semantics(
                header: true,
                liveRegion: liveTitle,
                child: Text(title, style: textTheme.headlineMedium),
              ),
              if (body case final body?) ...[
                SizedBox(height: spacing.xs),
                Text(body, style: textTheme.bodyLarge),
              ],
              SizedBox(height: spacing.lg),
              child,
            ],
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            spacing.lg,
            spacing.sm,
            spacing.lg,
            spacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing.xs,
            children: [primaryAction, ?secondaryAction],
          ),
        ),
      ],
    );
  }

  /// Both states fill the body while they swap.
  static Widget _fill(Widget? current, List<Widget> previous) =>
      Stack(fit: StackFit.expand, children: [...previous, ?current]);
}

/// The bar and "3 de 7". Arriving from another question, the bar moves on
/// from where that one stood instead of jumping.
class const _Progress({required final int number, required final int count})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final from = OnboardingStepSwitcher.previousQuestionOf(context) ?? number;
    return Semantics(
      label: l10n.onboardingProgressSemantics(number, count),
      excludeSemantics: true,
      child: Row(
        spacing: context.appSpacing.sm,
        children: [
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: from / count, end: number / count),
              duration: RondaMotion.of(context)
                  .durationOr(AppMotion.standardDuration),
              curve: AppMotion.standardCurve,
              builder: (context, value, _) =>
                  LinearProgressIndicator(value: value),
            ),
          ),
          Text(
            l10n.onboardingProgress(number, count),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
