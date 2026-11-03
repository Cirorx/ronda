import 'package:ronda_ui/ronda_ui.dart';

/// The strokes of [object] on [RondaObjectIcon]'s 24-unit grid, shared by
/// the icon and the sketches that put the same objects in a scene
/// ([RondaSketch]). Not exported: the package's own drawing.
List<Path> rondaObjectPaths(RondaObject object) => switch (object) {
  RondaObject.mate => [
    // The gourd, wider at the belly than at the mouth.
    Path()
      ..moveTo(7.5, 9)
      ..cubicTo(4.5, 12, 5, 20.5, 12, 20.5)
      ..cubicTo(19, 20.5, 19.5, 12, 16.5, 9)
      ..close(),
    // The bombilla, leaning out of it.
    Path()
      ..moveTo(12.5, 11)
      ..lineTo(16.5, 3)
      ..moveTo(15.5, 3)
      ..lineTo(18, 3),
  ],
  RondaObject.termo => [
    Path()..addRRect(RRect.fromLTRBR(8, 6.5, 16, 21, const Radius.circular(2))),
    // The cup on top, and the band where the hand goes.
    Path()
      ..addRRect(RRect.fromLTRBR(9.5, 3, 14.5, 6.5, const Radius.circular(1)))
      ..moveTo(8, 11)
      ..lineTo(16, 11),
  ],
  RondaObject.pelota => [
    Path()..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 8.5)),
    // The patch in the middle, and its seams out to the edge.
    Path()
      ..moveTo(12, 9)
      ..lineTo(14.9, 11.1)
      ..lineTo(13.8, 14.4)
      ..lineTo(10.2, 14.4)
      ..lineTo(9.1, 11.1)
      ..close()
      ..moveTo(12, 9)
      ..lineTo(12, 3.5)
      ..moveTo(14.9, 11.1)
      ..lineTo(20.1, 9.4)
      ..moveTo(13.8, 14.4)
      ..lineTo(17, 18.9)
      ..moveTo(10.2, 14.4)
      ..lineTo(7, 18.9)
      ..moveTo(9.1, 11.1)
      ..lineTo(3.9, 9.4),
  ],
  RondaObject.mazo => [
    // The card behind, showing at the top and the start.
    Path()
      ..moveTo(9, 17)
      ..lineTo(5, 17)
      ..lineTo(5, 4)
      ..lineTo(14, 4)
      ..lineTo(14, 7),
    Path()
      ..addRRect(RRect.fromLTRBR(9, 7, 19, 20.5, const Radius.circular(1.5))),
    // An oro on the front card.
    Path()
      ..addOval(Rect.fromCircle(center: const Offset(14, 13.75), radius: 2.25)),
  ],
  RondaObject.bizcochos => [
    // The plate.
    Path()
      ..moveTo(3, 16)
      ..lineTo(21, 16)
      ..moveTo(4.5, 16)
      ..quadraticBezierTo(12, 21.5, 19.5, 16),
    // Three bizcochos on it, the middle one behind.
    Path()
      ..moveTo(4, 16)
      ..arcToPoint(const Offset(11, 16), radius: const Radius.circular(3.5))
      ..moveTo(13, 16)
      ..arcToPoint(const Offset(20, 16), radius: const Radius.circular(3.5))
      ..moveTo(9.4, 12.9)
      ..arcToPoint(const Offset(14.6, 12.9), radius: const Radius.circular(3)),
  ],
  RondaObject.sillas => [
    // A folding chair from the side: the back, the seat, the legs.
    Path()
      ..moveTo(7, 3)
      ..lineTo(7, 21)
      ..moveTo(7, 12.5)
      ..lineTo(17, 12.5)
      ..moveTo(15.5, 12.5)
      ..lineTo(18, 21)
      ..moveTo(7, 5.5)
      ..lineTo(10, 5.5),
  ],
};
