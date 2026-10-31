import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// {@template focus_ring}
/// A ring just outside [child] while keyboard focus is on it, or on anything
/// inside it: [AppTheme.focusRingWidth] of [ColorScheme.primary],
/// [AppTheme.focusRingOffset] away from the edge, following [borderRadius].
///
/// It shows only while the last thing the person did was press a key, as a
/// browser's `:focus-visible` does: a tap or a mouse click anywhere hides it
/// (focus stays where it was), and the next key brings it back. Flutter's
/// own [FocusHighlightMode] counts a mouse as a keyboard, which would leave
/// a ring on the last chip tabbed to while the mouse picks others. It
/// appears and goes at once: a keyboard action never animates.
/// [PressScale] puts one round every tappable it wraps; the theme's buttons
/// draw theirs as their border instead.
///
/// It paints outside [child]'s bounds, so it belongs outside anything that
/// clips (a [Card]). A row that runs the full width of a list, where the
/// list would clip a ring outside it, takes it [inset]: the same gap inside
/// its edge instead.
///
/// Which input came last is shared by every ring in the app, so in tests a
/// ring focused by a key in one test still shows in the next until a pointer
/// goes down.
/// {@endtemplate}
class FocusRing extends StatefulWidget {
  /// {@macro focus_ring}
  const new({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.lg)),
    this.inset = false,
    super.key,
  });

  /// The focusable surface, or something that holds one.
  final Widget child;

  /// The corners of [child]'s surface, which the ring follows.
  final BorderRadius borderRadius;

  /// Whether the ring sits inside [child]'s edge rather than outside it.
  final bool inset;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  /// Whether the last thing the person did was press a key (`true`) rather
  /// than touch or click. Shared by every ring, so one built after the last
  /// key knows it; each ring listens for itself, so no listener outlives the
  /// rings.
  static final ValueNotifier<bool> _keyboardDriven = ValueNotifier(false);

  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _keyboardDriven.addListener(_changed);
    HardwareKeyboard.instance.addHandler(_key);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_pointer);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_pointer);
    HardwareKeyboard.instance.removeHandler(_key);
    _keyboardDriven.removeListener(_changed);
    super.dispose();
  }

  bool _key(KeyEvent event) {
    if (event is KeyDownEvent) _keyboardDriven.value = true;
    return false;
  }

  void _pointer(PointerEvent event) {
    if (event is PointerDownEvent) _keyboardDriven.value = false;
  }

  void _changed() => setState(() {});

  void _focusChanged(bool focused) => setState(() => _focused = focused);

  @override
  Widget build(BuildContext context) {
    final visible = _focused && _keyboardDriven.value;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: _focusChanged,
      child: CustomPaint(
        foregroundPainter: visible
            ? _RingPainter(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: widget.borderRadius,
                inset: widget.inset,
              )
            : null,
        child: widget.child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const new({
    required this.color,
    required this.borderRadius,
    required this.inset,
  });

  final Color color;
  final BorderRadius borderRadius;
  final bool inset;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = AppTheme.focusRingOffset + AppTheme.focusRingWidth / 2;
    final ring = borderRadius
        .toRRect(Offset.zero & size)
        .inflate(inset ? -gap : gap);
    canvas.drawRRect(
      ring,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppTheme.focusRingWidth,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      color != oldDelegate.color ||
      borderRadius != oldDelegate.borderRadius ||
      inset != oldDelegate.inset;
}
