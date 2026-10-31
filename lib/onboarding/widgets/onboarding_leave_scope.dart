import 'package:ronda_ui/ronda_ui.dart';

/// {@template onboarding_leave_scope}
/// Says what back does on the first question: [onLeave] returns to the
/// welcome doors, signed out. Without a scope, or with no [onLeave], the
/// first question has no back button.
/// {@endtemplate}
class const OnboardingLeaveScope({
  /// Back from the first question, or `null` when there is nowhere to go.
  required final VoidCallback? onLeave,
  required super.child,
  super.key,
}) extends InheritedWidget {
  /// {@macro onboarding_leave_scope}
  this;

  /// Back from the first question under [context], if there is one.
  static VoidCallback? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<OnboardingLeaveScope>()
      ?.onLeave;

  @override
  bool updateShouldNotify(OnboardingLeaveScope oldWidget) =>
      onLeave != oldWidget.onLeave;
}
