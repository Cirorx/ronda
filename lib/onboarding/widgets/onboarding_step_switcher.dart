import 'package:equatable/equatable.dart';
import 'package:ronda/onboarding/cubit/onboarding_cubit.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// {@template onboarding_screen}
/// Which onboarding screen is open: the recorder, or a step opened with
/// "Cambiar" on the read-back or on the way through.
/// {@endtemplate}
final class const OnboardingScreen({
  /// The open step, or `null` for the recorder.
  final OnboardingStep? step,

  /// Whether [step] was opened with "Cambiar" on the read-back.
  final bool editing = false,
}) extends Equatable {
  /// {@macro onboarding_screen}
  this;

  /// The screen [state] shows.
  factory of(OnboardingState state) => state.recording
      ? const OnboardingScreen()
      : OnboardingScreen(step: state.step, editing: state.editingFromReview);

  /// The question's number among the questions, from 1, or `null` on the
  /// read-back and the recorder.
  int? get questionNumber => switch (step) {
    null || OnboardingStep.review => null,
    final step => OnboardingStep.questions.indexOf(step) + 1,
  };

  /// Whether coming here from [previous] moves forward: on to a later step,
  /// into a "Cambiar", into the recorder or out of it. Back is the other
  /// way, and so is leaving a "Cambiar" for the read-back, as a pushed
  /// screen closes.
  bool isForwardFrom(OnboardingScreen previous) {
    final (from, to) = (previous.step, step);
    if (from == null || to == null) return true;
    if (editing != previous.editing) return editing;
    return to.index > from.index;
  }

  @override
  List<Object?> get props => [step, editing];
}

/// {@template onboarding_step_switcher}
/// Moves from one onboarding screen to the next the way a pushed screen
/// moves (`docs/DESIGN.md` § Motion and feel). Forward, the new screen comes
/// in from the end side over the open one, which drifts a little the other
/// way; back, the open screen leaves the way it came and uncovers the one
/// before. Both follow [AppMotion.standardCurve]; with reduced motion the
/// screens only cross-fade.
///
/// Only the new screen takes touches and is read by screen readers. The
/// question on screen before it is there for the progress bar
/// ([previousQuestionOf]). A change that lands while the page itself is
/// still coming in (answers held on the phone opening on the read-back)
/// shows at once: the page moves only once.
/// {@endtemplate}
class OnboardingStepSwitcher extends StatefulWidget {
  /// {@macro onboarding_step_switcher}
  const new({required this.screen, required this.child, super.key});

  /// The open screen; a change moves to [child].
  final OnboardingScreen screen;

  /// The open screen's widget.
  final Widget child;

  /// How far the covered screen drifts, as a share of the width.
  static const double drift = 1 / 3;

  /// The number of the question on screen before the open one, or `null`
  /// when there was none (the first screen, the read-back, the recorder).
  static int? previousQuestionOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_PreviousScreen>()
      ?.screen
      ?.questionNumber;

  @override
  State<OnboardingStepSwitcher> createState() => _OnboardingStepSwitcherState();
}

class _OnboardingStepSwitcherState extends State<OnboardingStepSwitcher> {
  OnboardingScreen? _previous;
  bool _forward = true;
  // Bumped to start afresh, with no screen leaving, on a change that
  // shouldn't move.
  int _generation = 0;

  @override
  void didUpdateWidget(OnboardingStepSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.screen == oldWidget.screen) return;
    _previous = oldWidget.screen;
    _forward = widget.screen.isForwardFrom(oldWidget.screen);
    final pageArriving =
        !(ModalRoute.of(context)?.animation?.isCompleted ?? true);
    if (pageArriving) _generation++;
  }

  @override
  Widget build(BuildContext context) {
    final motion = RondaMotion.of(context);
    final forward = _forward;
    final open = ValueKey(widget.screen);
    // The end side, where a new screen comes in from.
    final end = switch (Directionality.of(context)) {
      TextDirection.ltr => 1.0,
      TextDirection.rtl => -1.0,
    };

    return _PreviousScreen(
      screen: _previous,
      child: AnimatedSwitcher(
        key: ValueKey(_generation),
        duration: motion.reduced
            ? AppMotion.crossFade
            : AppMotion.standardDuration,
        // The screen that slides the whole width is on top: the new one
        // going forward, the leaving one going back.
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [
            if (forward) ...previous,
            ?current,
            if (!forward) ...previous,
          ],
        ),
        transitionBuilder: (child, animation) {
          final leaving = child.key != open;
          // Leaving screens run their animation backwards; the flipped
          // curve keeps both screens moving together.
          final curve = leaving
              ? AppMotion.standardCurve.flipped
              : AppMotion.standardCurve;
          final covered = leaving == forward;
          return IgnorePointer(
            ignoring: leaving,
            child: ExcludeSemantics(
              excluding: leaving,
              child: motion.transition(
                animation: animation,
                child: child,
                moving: (animation, child) => SlideTransition(
                  position: animation.drive(
                    Tween<Offset>(
                      begin: Offset(
                        end * (covered ? -OnboardingStepSwitcher.drift : 1),
                        0,
                      ),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: curve)),
                  ),
                  child: child,
                ),
              ),
            ),
          );
        },
        child: KeyedSubtree(key: open, child: widget.child),
      ),
    );
  }
}

class const _PreviousScreen({
  required final OnboardingScreen? screen,
  required super.child,
}) extends InheritedWidget {
  @override
  bool updateShouldNotify(_PreviousScreen oldWidget) =>
      screen != oldWidget.screen;
}
