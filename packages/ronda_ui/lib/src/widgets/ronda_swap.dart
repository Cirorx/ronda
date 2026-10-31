import 'package:ronda_ui/ronda_ui.dart';
import 'package:ronda_ui/src/widgets/steady_switcher.dart';

/// {@template ronda_swap}
/// Swaps one state for the next when [child]'s key changes: "Esta no"
/// becoming "Vas", an empty seat becoming a filled one, a confirmation
/// arriving.
///
/// The new child fades in and settles from [AppMotion.swapScale] on the
/// [AppMotion.standard] curve while the old one fades out; with reduced
/// motion they only cross-fade, over [AppMotion.crossFade] even when the
/// phone's own "remove animations" setting shortens the framework's
/// animations. The state on its way out takes no touches and isn't read by
/// screen readers, so there is only ever one copy to tap and nothing is
/// announced twice. Give each state its own key (`ValueKey(state)`), or the
/// swap won't happen.
/// {@endtemplate}
class const RondaSwap({
  /// The current state's widget, keyed by state.
  required final Widget child,

  /// How the two children are laid out while they swap; by default
  /// stacked and centred, as [AnimatedSwitcher] does. [topStartLayout]
  /// suits states stacked in a column.
  final AnimatedSwitcherLayoutBuilder layoutBuilder =
      AnimatedSwitcher.defaultLayoutBuilder,
  super.key,
}) extends StatelessWidget {
  /// {@macro ronda_swap}
  this;

  /// A layout for states stacked in a column: both take the column's width
  /// and hang from its top start while they swap, so the shorter one never
  /// floats in the middle of the taller one.
  static Widget topStartLayout(Widget? current, List<Widget> previous) =>
      Stack(fit: StackFit.passthrough, children: [...previous, ?current]);

  @override
  Widget build(BuildContext context) {
    final motion = RondaMotion.of(context);
    return SteadySwitcher(
      duration: motion.reduced
          ? AppMotion.crossFade
          : AppMotion.standardDuration,
      layoutBuilder: layoutBuilder,
      transitionBuilder: (child, animation, {required leaving}) =>
          motion.transition(
            animation: animation,
            child: child,
            moving: (animation, child) {
              final settled = CurvedAnimation(
                parent: animation,
                curve: AppMotion.standardCurve,
              );
              return FadeTransition(
                opacity: settled,
                child: ScaleTransition(
                  scale: Tween<double>(
                    begin: AppMotion.swapScale,
                    end: 1,
                  ).animate(settled),
                  child: child,
                ),
              );
            },
          ),
      child: child,
    );
  }
}
