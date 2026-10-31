import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The one haptic a commit asks for.
const commitHaptic = 'HapticFeedbackType.lightImpact';

/// The widget carrying the semantics [identifier] (a Maestro handle).
Finder byIdentifier(String identifier) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.identifier == identifier,
);

/// A progress ring inside the button with the semantics [identifier].
Finder progressIn(String identifier) => find.descendant(
  of: byIdentifier(identifier),
  matching: find.byType(CircularProgressIndicator),
);

/// Whether a [RondaSwap] is swapping two states right now, and how: with
/// the settle (a [ScaleTransition]) or, under reduced motion, a plain
/// cross-fade.
enum SwapMotion {
  /// Not swapping.
  none,

  /// The new state fades in and settles from a little smaller.
  settle,

  /// The two states only cross-fade.
  crossFade,
}

/// How the [RondaSwap]s under [of] (all of them by default) are moving now.
SwapMotion swapMotion({Finder? of}) {
  final swaps = of == null
      ? find.byType(RondaSwap)
      : find.descendant(of: of, matching: find.byType(RondaSwap));
  bool moving<T extends Widget>(bool Function(T widget) test) => find
      .descendant(
        of: swaps,
        matching: find.byWidgetPredicate(
          (widget) => widget is T && test(widget),
        ),
      )
      .evaluate()
      .isNotEmpty;
  if (moving<ScaleTransition>((widget) => widget.scale.value < 1)) {
    return SwapMotion.settle;
  }
  if (moving<FadeTransition>((widget) => widget.opacity.value < 1)) {
    return SwapMotion.crossFade;
  }
  return SwapMotion.none;
}
