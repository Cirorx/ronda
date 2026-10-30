import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

void main() {
  group(PressedShape, () {
    const rect = Rect.fromLTWH(0, 0, 200, 100);
    final base = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: const BorderSide(width: 2),
    );

    group('forStates', () {
      test('shrinks while pressed', () {
        expect(
          PressedShape.forStates(base, const {WidgetState.pressed}).factor,
          AppMotion.pressedScale,
        );
      });

      test('keeps full size otherwise', () {
        expect(
          PressedShape.forStates(base, const {WidgetState.hovered}).factor,
          1,
        );
      });
    });

    test('draws its outline at its factor, around the centre', () {
      final pressed = PressedShape(base: base, factor: 0.5);

      expect(
        pressed.getOuterPath(rect).getBounds(),
        const Rect.fromLTWH(50, 25, 100, 50),
      );
      expect(
        pressed.getInnerPath(rect).getBounds(),
        base.getInnerPath(const Rect.fromLTWH(50, 25, 100, 50)).getBounds(),
      );
    });

    test('draws at full size at rest', () {
      expect(
        PressedShape(base: base).getOuterPath(rect).getBounds(),
        base.getOuterPath(rect).getBounds(),
      );
    });

    test("takes its base's side, dimensions and interior", () {
      final shape = PressedShape(base: base);

      expect(shape.side, base.side);
      expect(shape.dimensions, base.dimensions);
      expect(shape.preferPaintInterior, base.preferPaintInterior);
    });

    test('paints its border and interior', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      PressedShape(base: base, factor: 0.9)
        ..paintInterior(canvas, rect, Paint())
        ..paint(canvas, rect);

      expect(recorder.endRecording(), isNotNull);
    });

    test('keeps its factor through copyWith and scale', () {
      final shape = PressedShape(base: base, factor: 0.9);
      const side = BorderSide(width: 4);

      expect(shape.copyWith(side: side).side, side);
      expect(shape.copyWith(side: side).factor, 0.9);
      expect(shape.scale(2).factor, 0.9);
      expect(shape.scale(2).base, base.scale(2));
    });

    test('keeps its base when the base scales to another kind', () {
      const shape = PressedShape(base: _OddBorder(), factor: 0.9);

      expect(shape.scale(2).base, const _OddBorder());
    });

    group('lerp', () {
      final rest = PressedShape(base: base);
      final pressed = PressedShape(base: base, factor: 0.9);

      test('moves its factor between two pressed shapes', () {
        final half = ShapeBorder.lerp(rest, pressed, 0.5)! as PressedShape;

        expect(half.factor, closeTo(0.95, 1e-9));
        expect(half.base, base);
      });

      test('treats a plain outlined border as full size', () {
        final from = pressed.lerpFrom(base, 0.5)! as PressedShape;
        final to = pressed.lerpTo(base, 0.5)! as PressedShape;

        expect(from.factor, closeTo(0.95, 1e-9));
        expect(to.factor, closeTo(0.95, 1e-9));
      });

      test('defers to the framework for other borders', () {
        expect(pressed.lerpFrom(null, 0.5), isNotNull);
        expect(pressed.lerpTo(null, 0.5), isNotNull);
      });

      test('keeps the nearer base when the bases cannot lerp', () {
        const odd = PressedShape(base: _OddBorder());

        expect(odd.lerpFrom(pressed, 0.2)! as PressedShape, isNotNull);
        expect((odd.lerpFrom(pressed, 0.2)! as PressedShape).base, base);
        expect(
          (odd.lerpFrom(pressed, 0.8)! as PressedShape).base,
          const _OddBorder(),
        );
      });
    });

    test('is equal by base and factor', () {
      expect(
        PressedShape(base: base, factor: 0.9),
        PressedShape(base: base, factor: 0.9),
      );
      expect(
        PressedShape(base: base, factor: 0.9).hashCode,
        PressedShape(base: base, factor: 0.9).hashCode,
      );
      expect(
        PressedShape(base: base),
        isNot(PressedShape(base: base, factor: 0.9)),
      );
    });

    test('describes itself', () {
      expect(PressedShape(base: base).toString(), contains('factor: 1'));
    });
  });
}

/// An outlined border that neither lerps nor scales to its own kind.
class _OddBorder extends OutlinedBorder {
  const new();

  @override
  OutlinedBorder copyWith({BorderSide? side}) => this;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => const Border();
}
