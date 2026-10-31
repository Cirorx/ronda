import 'package:ronda_ui/ronda_ui.dart';

/// {@template walkthrough_physics}
/// Paging that settles on the app's spring ([AppMotion.standard]) once the
/// finger lets go, carrying its speed. With reduced motion ([reduced]) it
/// settles in the cross-fade's time instead, so the cards barely travel
/// on their own.
/// {@endtemplate}
class WalkthroughPhysics extends PageScrollPhysics {
  /// {@macro walkthrough_physics}
  const new({this.reduced = false, super.parent});

  /// Whether the person asked for reduced motion.
  final bool reduced;

  /// The spring a card settles on under reduced motion: no bounce, as quick
  /// as the cross-fade.
  static final SpringDescription reducedSpring = AppMotion.spring(
    dampingRatio: AppMotion.standardDampingRatio,
    response:
        AppMotion.crossFade.inMicroseconds / Duration.microsecondsPerSecond,
  );

  @override
  WalkthroughPhysics applyTo(ScrollPhysics? ancestor) =>
      WalkthroughPhysics(reduced: reduced, parent: buildParent(ancestor));

  @override
  SpringDescription get spring => reduced ? reducedSpring : AppMotion.standard;
}
