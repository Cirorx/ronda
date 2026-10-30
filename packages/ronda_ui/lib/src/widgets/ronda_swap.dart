import 'package:ronda_ui/ronda_ui.dart';

/// {@template ronda_swap}
/// Swaps one state for the next when [child]'s key changes: "Esta no"
/// becoming "Vas", an empty seat becoming a filled one, a confirmation
/// arriving.
///
/// The new child fades in and settles from [AppMotion.swapScale] on the
/// [AppMotion.standard] curve while the old one fades out; with reduced
/// motion they only cross-fade. Only the current child is read by screen
/// readers, so nothing is announced twice. Give each state its own key
/// (`ValueKey(state)`), or the swap won't happen.
/// {@endtemplate}
class const RondaSwap({
  /// The current state's widget, keyed by state.
  required final Widget child,

  /// How the two children are laid out while they swap; by default
  /// stacked and centred, as [AnimatedSwitcher] does.
  final AnimatedSwitcherLayoutBuilder layoutBuilder =
      AnimatedSwitcher.defaultLayoutBuilder,
  super.key,
}) extends StatelessWidget {
  /// {@macro ronda_swap}
  this;

  @override
  Widget build(BuildContext context) {
    final motion = RondaMotion.of(context);
    return AnimatedSwitcher(
      duration: motion.reduced
          ? AppMotion.crossFade
          : AppMotion.standardDuration,
      layoutBuilder: layoutBuilder,
      transitionBuilder: (child, animation) => ExcludeSemantics(
        excluding: child.key != this.child.key,
        child: motion.transition(
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
      ),
      child: child,
    );
  }
}
