import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/onboarding/cubit/onboarding_cubit.dart';
import 'package:ronda/onboarding/widgets/onboarding_next_button.dart';
import 'package:ronda/onboarding/widgets/onboarding_pages.dart';
import 'package:ronda/onboarding/widgets/onboarding_step_layout.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// {@template onboarding_question}
/// One question of onboarding: its page's number among the pages
/// ([OnboardingPages]), the back button (except on the first page, unless
/// it was opened from the read-back) and "Seguir".
///
/// On a page of several questions ([OnboardingSectionScope]) it is only a
/// section: its title, text and picker, without the bar or the actions,
/// which the page has once ([OnboardingQuestionPage]).
/// {@endtemplate}
class const OnboardingQuestion({
  /// Which question this is.
  required final OnboardingStep step,

  /// The question.
  required final String title,

  /// The picker or field that answers it.
  required final Widget child,

  /// The text under the question.
  final String? body,

  /// A short line above the question ("Opcional").
  final String? overline,

  /// An optional action under "Seguir" ("Saltear"), on a page of its own.
  final Widget? secondaryAction,
  super.key,
}) extends StatelessWidget {
  /// {@macro onboarding_question}
  this;

  @override
  Widget build(BuildContext context) {
    if (OnboardingSectionScope.isSection(context)) {
      return _Section(
        title: title,
        body: body,
        overline: overline,
        child: child,
      );
    }
    final pages = OnboardingPages.of(context);
    final page = OnboardingPages.pageOf(pages, step)!;
    return OnboardingQuestionPage(
      page: page,
      pages: pages,
      title: title,
      body: body,
      overline: overline,
      secondaryAction: page.length == 1 ? secondaryAction : null,
      child: child,
    );
  }
}

/// {@template onboarding_question_page}
/// A page of onboarding questions: the [page]'s number among the [pages],
/// back to the page before, and "Seguir" past the whole page. A page of
/// one question has its [title]; a page of several lays out each one's
/// widget as a section ([OnboardingSectionScope]).
/// {@endtemplate}
class const OnboardingQuestionPage({
  /// The questions on this page.
  required final List<OnboardingStep> page,

  /// Every page, in order.
  required final List<List<OnboardingStep>> pages,

  /// What the page shows: its question's picker, or its questions'
  /// sections.
  required final Widget child,

  /// The question, on a page of one.
  final String? title,

  /// The text under the question, on a page of one.
  final String? body,

  /// A short line above the question, on a page of one.
  final String? overline,

  /// An optional action under "Seguir".
  final Widget? secondaryAction,
  super.key,
}) extends StatelessWidget {
  /// {@macro onboarding_question_page}
  this;

  @override
  Widget build(BuildContext context) {
    final editingFromReview = context.select<OnboardingCubit, bool>(
      (cubit) => cubit.state.editingFromReview,
    );
    final number = pages.indexOf(page);
    final canGoBack = editingFromReview || number > 0;
    return OnboardingStepLayout(
      title: title,
      body: body,
      overline: overline,
      questionNumber: number + 1,
      questionCount: pages.length,
      onBack: canGoBack ? () => _back(context, number) : null,
      primaryAction: OnboardingNextButton(page: page),
      secondaryAction: secondaryAction,
      child: child,
    );
  }

  /// Back from page [number]: a page of one question steps back one
  /// question, as ever (into the page before, whose first question then
  /// leads it); a page of several goes to the first question of the page
  /// before. After a "Cambiar" both return to the read-back.
  void _back(BuildContext context, int number) {
    final cubit = context.read<OnboardingCubit>();
    if (page.length == 1) {
      cubit.back();
    } else {
      cubit.backTo(pages[number > 0 ? number - 1 : 0].first);
    }
  }
}

/// One question among others on a page: its own heading, text and picker.
class const _Section({
  required final String title,
  required final Widget child,
  final String? body,
  final String? overline,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
          child: Text(title, style: textTheme.headlineSmall),
        ),
        if (body case final body?) ...[
          SizedBox(height: spacing.xs),
          Text(body, style: textTheme.bodyLarge),
        ],
        SizedBox(height: spacing.md),
        child,
      ],
    );
  }
}
