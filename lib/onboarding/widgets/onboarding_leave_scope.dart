import 'package:ronda_ui/ronda_ui.dart';

/// {@template onboarding_leave_scope}
/// Says what back does on the first question: [onLeave] returns to the
/// welcome doors signed out, or opens the recorder signed in. Without a
/// scope, or with no [onLeave], the first question has no back button.
///
/// Signed out it also gives the first question "Ya tengo cuenta"
/// ([onSignIn]), for someone who realises they signed up before.
/// {@endtemplate}
class const OnboardingLeaveScope({
  /// Back from the first question, or `null` when there is nowhere to go.
  required final VoidCallback? onLeave,
  required super.child,

  /// "Ya tengo cuenta" on the first question, or `null` signed in.
  final VoidCallback? onSignIn,
  super.key,
}) extends InheritedWidget {
  /// {@macro onboarding_leave_scope}
  this;

  /// Back from the first question under [context], if there is one.
  static VoidCallback? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<OnboardingLeaveScope>()
      ?.onLeave;

  /// "Ya tengo cuenta" under [context], if there is one.
  static VoidCallback? signInOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<OnboardingLeaveScope>()
      ?.onSignIn;

  @override
  bool updateShouldNotify(OnboardingLeaveScope oldWidget) =>
      onLeave != oldWidget.onLeave || onSignIn != oldWidget.onSignIn;
}
