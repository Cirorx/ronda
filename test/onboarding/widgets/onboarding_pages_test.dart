import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda_ui/ronda_ui.dart';

void main() {
  group(OnboardingPages, () {
    test('puts every question on exactly one wide page, in order', () {
      expect([
        for (final page in OnboardingPages.wide) ...page,
      ], OnboardingStep.questions);
    });

    test('numbers a page from 1, and the read-back not at all', () {
      const pages = OnboardingPages.wide;
      expect(OnboardingPages.numberOf(pages, OnboardingStep.brings), 1);
      expect(OnboardingPages.numberOf(pages, OnboardingStep.firstName), 4);
      expect(OnboardingPages.numberOf(pages, OnboardingStep.review), isNull);
      expect(OnboardingPages.numberOf(pages, null), isNull);
    });
  });

  group(OnboardingSectionScope, () {
    test('never asks its sections to rebuild', () {
      const scope = OnboardingSectionScope(child: SizedBox());
      expect(
        scope.updateShouldNotify(
          const OnboardingSectionScope(child: SizedBox()),
        ),
        isFalse,
      );
    });
  });
}
