import 'package:ronda/onboarding/cubit/onboarding_cubit.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// {@template onboarding_pages}
/// How the questions sit on pages. A phone shows one question a page; a
/// desktop window ([WindowSize.expanded]) has room for related ones
/// together: what you'd like to do and what you bring, when and where,
/// your age and what makes it hard to go, then your name. With large text
/// even a desktop goes back to one a page, so each still fits.
///
/// The cubit keeps one open step; on a page of several it is the first of
/// them (its leader), and "Seguir" moves past the whole page
/// ([OnboardingCubit.nextAfter]).
/// {@endtemplate}
abstract final class OnboardingPages {
  /// The pages on a desktop window, in order.
  static const List<List<OnboardingStep>> wide = [
    [OnboardingStep.pretexts, OnboardingStep.brings],
    [OnboardingStep.slots, OnboardingStep.barrio],
    [OnboardingStep.ageBand, OnboardingStep.needs],
    [OnboardingStep.firstName],
  ];

  /// Whether the window in [context] shows several questions a page.
  static bool grouped(BuildContext context) =>
      context.windowSize == WindowSize.expanded && !context.usesLargeText;

  /// The pages in [context]: [wide] when [grouped], one question each
  /// otherwise.
  static List<List<OnboardingStep>> of(BuildContext context) => grouped(context)
      ? wide
      : [
          for (final step in OnboardingStep.questions) [step],
        ];

  /// The page of [pages] that holds [step], or `null` for the read-back.
  static List<OnboardingStep>? pageOf(
    List<List<OnboardingStep>> pages,
    OnboardingStep? step,
  ) {
    for (final page in pages) {
      if (page.contains(step)) return page;
    }
    return null;
  }

  /// The number of [step]'s page among [pages], from 1, or `null` for the
  /// read-back and the recorder.
  static int? numberOf(List<List<OnboardingStep>> pages, OnboardingStep? step) {
    final page = pageOf(pages, step);
    return page == null ? null : pages.indexOf(page) + 1;
  }
}

/// {@template onboarding_section_scope}
/// Marks the questions under it as sections of one page: each shows its
/// title, text and picker, and the page around them has the one top bar
/// and "Seguir".
/// {@endtemplate}
class const OnboardingSectionScope({required super.child, super.key})
    extends InheritedWidget {
  /// {@macro onboarding_section_scope}
  this;

  /// Whether [context] is inside a page of several questions.
  static bool isSection(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnboardingSectionScope>() !=
      null;

  @override
  bool updateShouldNotify(OnboardingSectionScope oldWidget) => false;
}
