import 'dart:ui' show lerpDouble;

import 'package:ronda_ui/ronda_ui.dart';

/// {@template pressed_shape}
/// An [OutlinedBorder] drawn at [factor] of its size, around its centre:
/// how the theme's buttons shrink while pressed.
///
/// Buttons resolve their shape for every state, and their [Material]
/// animates between the two shapes, so the fill, the border and the ink all
/// shrink together on touch-down and come back on release or when the
/// finger drags away. The hit area stays the full size.
/// {@endtemplate}
class PressedShape extends OutlinedBorder {
  /// {@macro pressed_shape}
  const new({required this.base, this.factor = 1})
    : super(side: BorderSide.none);

  /// The shape for a button in [states]: [base], shrunk while pressed.
  factory forStates(OutlinedBorder base, Set<WidgetState> states) =>
      PressedShape(
        base: base,
        factor: states.contains(WidgetState.pressed)
            ? AppMotion.pressedScale
            : 1,
      );

  /// The shape at full size.
  final OutlinedBorder base;

  /// How large it is drawn: 1 at rest, [AppMotion.pressedScale] pressed.
  final double factor;

  @override
  BorderSide get side => base.side;

  Rect _scaled(Rect rect) {
    if (factor == 1) return rect;
    return Rect.fromCenter(
      center: rect.center,
      width: rect.width * factor,
      height: rect.height * factor,
    );
  }

  @override
  EdgeInsetsGeometry get dimensions => base.dimensions;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      base.getInnerPath(_scaled(rect), textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      base.getOuterPath(_scaled(rect), textDirection: textDirection);

  @override
  bool get preferPaintInterior => base.preferPaintInterior;

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    base.paintInterior(
      canvas,
      _scaled(rect),
      paint,
      textDirection: textDirection,
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    base.paint(canvas, _scaled(rect), textDirection: textDirection);
  }

  @override
  PressedShape scale(double t) {
    final scaled = base.scale(t);
    return PressedShape(
      base: scaled is OutlinedBorder ? scaled : base,
      factor: factor,
    );
  }

  @override
  PressedShape copyWith({BorderSide? side}) => PressedShape(
    base: base.copyWith(side: side),
    factor: factor,
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is PressedShape) return _lerp(a.base, a.factor, t);
    if (a is OutlinedBorder) return _lerp(a, 1, t);
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is PressedShape) return b._lerp(base, factor, t);
    if (b is OutlinedBorder) {
      return PressedShape(base: b)._lerp(base, factor, t);
    }
    return super.lerpTo(b, t);
  }

  /// From ([fromBase], [fromFactor]) at 0 to this at 1.
  PressedShape _lerp(OutlinedBorder fromBase, double fromFactor, double t) {
    final lerped = OutlinedBorder.lerp(fromBase, base, t);
    return PressedShape(
      base: lerped is OutlinedBorder ? lerped : (t < 0.5 ? fromBase : base),
      factor: lerpDouble(fromFactor, factor, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PressedShape && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);

  @override
  String toString() => 'PressedShape($base, factor: $factor)';
}
