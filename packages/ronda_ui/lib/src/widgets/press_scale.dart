import 'package:flutter/gestures.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// {@template press_scale}
/// Instant press feedback for a tappable surface that isn't one of the
/// theme's buttons (those shrink through [PressedShape] already): a card,
/// a chip, a grid cell.
///
/// It shrinks [child] to [AppMotion.pressedScale] over [AppMotion.press] the
/// moment a finger touches down, before any tap is recognised, and grows
/// back when the finger lifts, is cancelled, or drags further than a touch
/// slop (a scroll, or the finger sliding away). It listens to raw pointer
/// events, so it never takes part in the gesture arena and the [child]'s own
/// ink and tap work as before. With reduced motion the change is instant.
/// {@endtemplate}
class PressScale extends StatefulWidget {
  /// {@macro press_scale}
  const new({required this.child, this.enabled = true, super.key});

  /// The tappable surface.
  final Widget child;

  /// Whether it responds; off for a disabled surface.
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  int? _pointer;
  Offset _origin = Offset.zero;

  bool get _pressed => _pointer != null;

  void _down(PointerDownEvent event) {
    if (!widget.enabled || _pressed) return;
    setState(() {
      _pointer = event.pointer;
      _origin = event.position;
    });
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if ((event.position - _origin).distance > kTouchSlop) _release();
  }

  void _end(PointerEvent event) {
    if (event.pointer == _pointer) _release();
  }

  void _release() => setState(() => _pointer = null);

  @override
  void didUpdateWidget(PressScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _pointer = null;
  }

  @override
  Widget build(BuildContext context) {
    final motion = RondaMotion.of(context);
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _end,
      onPointerCancel: _end,
      child: AnimatedScale(
        scale: _pressed ? AppMotion.pressedScale : 1,
        duration: motion.durationOr(AppMotion.press),
        curve: AppMotion.pressCurve,
        child: widget.child,
      ),
    );
  }
}
