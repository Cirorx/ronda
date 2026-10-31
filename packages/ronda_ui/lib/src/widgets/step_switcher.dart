import 'package:ronda_ui/ronda_ui.dart';
import 'package:ronda_ui/src/widgets/steady_switcher.dart';

/// {@template step_switcher}
/// Moves between the steps of one page (the questions of a form, a
/// recorder and what comes after it) the way a pushed screen moves
/// (`docs/DESIGN.md` § Motion and feel), without pushing a route. Forward,
/// the new step comes in from the end side over the open one, which
/// drifts a little the other way; back, the open step leaves the way it
/// came and uncovers the one before. Both follow [AppMotion.standardCurve];
/// with reduced motion the steps only cross-fade, over
/// [AppMotion.crossFade].
///
/// A new [step] moves to [child]; [forward] says which way, forward when
/// it isn't given. Only the new step takes touches and is read by screen
/// readers. The step on screen before it can be read with [previousOf],
/// for something that moves on from where it stood (a progress bar). A
/// change that lands while the page itself is still coming in shows at
/// once: the page moves only once.
/// {@endtemplate}
class StepSwitcher<T extends Object> extends StatefulWidget {
  /// {@macro step_switcher}
  const new({required this.step, required this.child, this.forward, super.key});

  /// The open step; a change moves to [child].
  final T step;

  /// The open step's widget.
  final Widget child;

  /// Whether going from the first step to the second moves forward;
  /// always forward when `null`.
  final bool Function(T from, T to)? forward;

  /// How far the covered step drifts, as a share of the width.
  static const double drift = 1 / 3;

  /// The step on screen before the open one, under the nearest
  /// [StepSwitcher] of [T], or `null` when there was none.
  static T? previousOf<T extends Object>(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PreviousStep<T>>()?.step;

  @override
  State<StepSwitcher<T>> createState() => _StepSwitcherState<T>();
}

class _StepSwitcherState<T extends Object> extends State<StepSwitcher<T>> {
  T? _previous;
  bool _forward = true;
  // Bumped to start afresh, with no step leaving, on a change that
  // shouldn't move.
  int _generation = 0;

  @override
  void didUpdateWidget(StepSwitcher<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.step == oldWidget.step) return;
    _previous = oldWidget.step;
    _forward = widget.forward?.call(oldWidget.step, widget.step) ?? true;
    final pageArriving =
        !(ModalRoute.of(context)?.animation?.isCompleted ?? true);
    if (pageArriving) _generation++;
  }

  @override
  Widget build(BuildContext context) {
    final motion = RondaMotion.of(context);
    final forward = _forward;
    // The end side, where a new step comes in from.
    final end = switch (Directionality.of(context)) {
      TextDirection.ltr => 1.0,
      TextDirection.rtl => -1.0,
    };

    return _PreviousStep<T>(
      step: _previous,
      child: SteadySwitcher(
        key: ValueKey(_generation),
        duration: motion.reduced
            ? AppMotion.crossFade
            : AppMotion.standardDuration,
        // The step that slides the whole width is on top: the new one going
        // forward, the leaving one going back.
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [
            if (forward) ...previous,
            ?current,
            if (!forward) ...previous,
          ],
        ),
        transitionBuilder: (child, animation, {required leaving}) {
          // Leaving steps run their animation backwards; the flipped curve
          // keeps both steps moving together.
          final curve = leaving
              ? AppMotion.standardCurve.flipped
              : AppMotion.standardCurve;
          final covered = leaving == forward;
          return motion.transition(
            animation: animation,
            child: child,
            moving: (animation, child) => SlideTransition(
              position: animation.drive(
                Tween<Offset>(
                  begin: Offset(end * (covered ? -StepSwitcher.drift : 1), 0),
                  end: Offset.zero,
                ).chain(CurveTween(curve: curve)),
              ),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(key: ValueKey(widget.step), child: widget.child),
      ),
    );
  }
}

class const _PreviousStep<T extends Object>({
  required final T? step,
  required super.child,
}) extends InheritedWidget {
  @override
  bool updateShouldNotify(_PreviousStep<T> oldWidget) => step != oldWidget.step;
}
