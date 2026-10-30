import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:ronda_ui/ronda_ui.dart';

/// {@template ronda_page_transitions_builder}
/// Ronda's one rule for moving between screens, on every platform: a pushed
/// screen comes in from the end side (the right) and goes back out the same
/// way, over the screen it covers, which drifts a little the other way.
/// Where the platform has an edge swipe back, it follows the finger.
///
/// With reduced motion the screens cross-fade instead, and nothing slides.
/// Tab switches don't go through here: the tabs keep their own screens and
/// swap without a transition.
/// {@endtemplate}
class RondaPageTransitionsBuilder extends PageTransitionsBuilder {
  /// {@macro ronda_page_transitions_builder}
  const new();

  static const _slide = CupertinoPageTransitionsBuilder();

  @override
  Duration get transitionDuration => _slide.transitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return RondaMotion.of(context).transition(
      animation: animation,
      child: child,
      moving: (animation, child) => _slide.buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      ),
    );
  }
}
