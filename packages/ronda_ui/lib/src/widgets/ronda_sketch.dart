import 'dart:math' as math;

import 'package:ronda_ui/ronda_ui.dart';
import 'package:ronda_ui/src/widgets/ronda_object_paths.dart';

/// The small scenes [RondaSketch] draws, one per quiet screen
/// (`docs/DESIGN.md`, "Sketches"). Each is drawn on a grid
/// [RondaSketch.grid] units tall and [width] units wide.
enum RondaScene {
  /// A row of four chairs, one taken in yerba green: no ronda yet.
  emptyChairs(60),

  /// A termo with its cup off and an ochre question mark: the week didn't
  /// load.
  termoAsks(36),

  /// An almacén's door with a ruled notice taped on it: Cerca, coming.
  almacenNotice(30),

  /// A termo with a yerba-green tick stamped beside it: "voy".
  termoStamp(24),

  /// A ruled sheet with one line written by the ochre margin: the first
  /// ones on a list.
  firstLine(30),

  /// A mate with its bombilla, the ochre inside of the gourd showing:
  /// thanks for coming.
  mateServed(24),

  /// An open cuaderno, its lines still blank, a pencil resting on it.
  openCuaderno(36),

  /// The mate, the termo, the mazo and the bizcochos on one ruled line.
  objectsOnALine(80);

  new(this.width);

  /// The scene's width on its grid.
  final double width;
}

/// {@template ronda_sketch}
/// One of Ronda's small line drawings: everyday objects in the same birome
/// stroke as [RondaObjectIcon], set in a little scene for a screen that is
/// otherwise only words ("Objects, not people").
///
/// It is drawn [height] tall, narrower when the room runs out, in the
/// theme's colours only: outlines in the muted ink, yerba green for what is
/// done or taken, the ochre margen, alpaca silver for metal, the line colour
/// for rules. Never people, pins, maps or gradients.
///
/// It is decoration: screen readers skip it, and large text drops it, as it
/// drops the object icons beside text. It never moves.
/// {@endtemplate}
class const RondaSketch(
  /// What it draws.
  final RondaScene scene, {

  /// How tall it is drawn, at most.
  final double height = RondaSketch.defaultHeight,
  super.key,
}) extends StatelessWidget {
  /// {@macro ronda_sketch}
  this;

  /// The height of the grid every scene is drawn on, the icons' grid.
  static const double grid = RondaObjectIcon.grid;

  /// The height a sketch takes on a full screen.
  static const double defaultHeight = 112;

  /// The height a sketch takes inside a card, the size of a large icon.
  static const double cardHeight = 48;

  /// The widest a stroke gets on screen, in logical pixels: what the
  /// object icons show at [cardHeight], so a large sketch keeps a pen's
  /// line instead of a marker's.
  static const double maxStroke = RondaObjectIcon.stroke * cardHeight / grid;

  @override
  Widget build(BuildContext context) {
    if (context.usesLargeText) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final inks = (
      outline: scheme.onSurfaceVariant,
      done: scheme.primary,
      margen: context.rondaPalette.margen,
      silver: scheme.tertiary,
      rule: scheme.outlineVariant,
      paper: scheme.surface,
    );
    final aspect = scene.width / grid;
    return ExcludeSemantics(
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: height * aspect,
            maxHeight: height,
          ),
          child: AspectRatio(
            aspectRatio: aspect,
            child: CustomPaint(
              painter: _ScenePainter(scene: scene, inks: inks),
            ),
          ),
        ),
      ),
    );
  }
}

/// The theme colours a scene is drawn with.
typedef _Inks = ({
  Color outline,
  Color done,
  Color margen,
  Color silver,
  Color rule,
  Color paper,
});

class _ScenePainter extends CustomPainter {
  new({required this.scene, required this.inks});

  final RondaScene scene;
  final _Inks inks;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / RondaSketch.grid;
    canvas.scale(scale);
    final width = math.min(
      RondaObjectIcon.stroke,
      RondaSketch.maxStroke / scale,
    );
    Paint pen(Color color, {double factor = 1}) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * factor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Paint fill(Color color) => Paint()..color = color;
    final ink = (
      outline: pen(inks.outline),
      done: pen(inks.done),
      margen: pen(inks.margen, factor: 0.75),
      silver: pen(inks.silver),
      rule: pen(inks.rule, factor: 0.75),
      doneFill: fill(inks.done),
      margenFill: fill(inks.margen),
      paperFill: fill(inks.paper),
    );
    switch (scene) {
      case RondaScene.emptyChairs:
        _emptyChairs(canvas, ink);
      case RondaScene.termoAsks:
        _termoAsks(canvas, ink);
      case RondaScene.almacenNotice:
        _almacenNotice(canvas, ink);
      case RondaScene.termoStamp:
        _termoStamp(canvas, ink);
      case RondaScene.firstLine:
        _firstLine(canvas, ink);
      case RondaScene.mateServed:
        _mateServed(canvas, ink);
      case RondaScene.openCuaderno:
        _openCuaderno(canvas, ink);
      case RondaScene.objectsOnALine:
        _objectsOnALine(canvas, ink);
    }
  }

  static void _floor(Canvas canvas, _Pens ink, double from, double to) =>
      canvas.drawLine(Offset(from, 21.5), Offset(to, 21.5), ink.rule);

  static void _emptyChairs(Canvas canvas, _Pens ink) {
    _floor(canvas, ink, 0.5, 59.5);
    for (var i = 0; i < 4; i++) {
      final x = 2.5 + i * 15;
      final back = RRect.fromLTRBR(
        x + 1.5,
        4,
        x + 9.5,
        12,
        const Radius.circular(1.5),
      );
      final seat = RRect.fromLTRBR(
        x,
        12.5,
        x + 11,
        15,
        const Radius.circular(1),
      );
      final taken = i == 0;
      final line = taken ? ink.done : ink.outline;
      if (taken) {
        canvas
          ..drawRRect(back, ink.doneFill)
          ..drawRRect(seat, ink.doneFill);
      }
      canvas
        ..drawRRect(back, line)
        ..drawRRect(seat, line)
        ..drawLine(Offset(x + 1.5, 15), Offset(x + 1, 21.5), line)
        ..drawLine(Offset(x + 9.5, 15), Offset(x + 10, 21.5), line);
    }
  }

  static void _termoAsks(Canvas canvas, _Pens ink) {
    _floor(canvas, ink, 4, 33);
    canvas
      // The termo, open: no cup on its mouth.
      ..drawRRect(
        RRect.fromLTRBR(10, 8, 20, 21.5, const Radius.circular(2.5)),
        ink.outline,
      )
      ..drawRRect(
        RRect.fromLTRBR(12, 5.5, 18, 8, const Radius.circular(1)),
        ink.outline,
      )
      ..drawLine(const Offset(10, 13), const Offset(20, 13), ink.outline)
      // The cup, upside down on the floor beside it.
      ..drawRRect(
        RRect.fromLTRBR(23.5, 17.5, 30, 21.5, const Radius.circular(1.2)),
        ink.silver,
      )
      // And the question, in the margin's ochre.
      ..drawPath(
        Path()
          ..moveTo(22, 4.5)
          ..cubicTo(22, 1.5, 27, 1.5, 27, 4.5)
          ..cubicTo(27, 6.5, 24.5, 6.8, 24.5, 9),
        ink.margen,
      )
      ..drawCircle(const Offset(24.5, 11.6), 0.7, ink.margenFill);
  }

  static void _almacenNotice(Canvas canvas, _Pens ink) {
    _floor(canvas, ink, 1, 29);
    // The awning, scalloped, over the shop's front.
    final awning = Path()..moveTo(2, 4);
    for (var i = 0; i < 6; i++) {
      final start = 2 + i * 26 / 6;
      awning.quadraticBezierTo(start + 26 / 12, 7.5, start + 26 / 6, 4);
    }
    canvas
      ..drawLine(const Offset(2, 4), const Offset(28, 4), ink.outline)
      ..drawPath(awning, ink.margen)
      ..drawLine(const Offset(3.5, 7), const Offset(3.5, 21.5), ink.outline)
      ..drawLine(const Offset(26.5, 7), const Offset(26.5, 21.5), ink.outline)
      // The door and its knob.
      ..drawRRect(
        RRect.fromLTRBR(9, 8.5, 21, 21.5, const Radius.circular(0.8)),
        ink.outline,
      )
      ..drawCircle(const Offset(19.2, 16), 0.5, ink.outline);
    // The notice: a ruled sheet with its margin, taped at the top.
    const notice = Rect.fromLTRB(11.2, 10.5, 17.6, 18.5);
    canvas
      ..drawRect(notice, ink.paperFill)
      ..drawRect(notice, ink.outline)
      ..drawLine(
        const Offset(12.8, 10.9),
        const Offset(12.8, 18.1),
        ink.margen,
      );
    for (final y in [12.9, 14.6, 16.3]) {
      canvas.drawLine(Offset(13.6, y), Offset(16.6, y), ink.rule);
    }
    canvas.drawLine(
      const Offset(13.4, 9.8),
      const Offset(15.6, 11),
      ink.silver,
    );
  }

  static void _termoStamp(Canvas canvas, _Pens ink) {
    canvas
      ..drawRRect(
        RRect.fromLTRBR(4, 7, 12, 21.5, const Radius.circular(2)),
        ink.outline,
      )
      ..drawRRect(
        RRect.fromLTRBR(5.5, 3.5, 10.5, 7, const Radius.circular(1)),
        ink.outline,
      )
      ..drawLine(const Offset(4, 11.5), const Offset(12, 11.5), ink.outline)
      // The stamp, pressed over the termo's side.
      ..drawCircle(const Offset(16.5, 15), 5.5, ink.paperFill)
      ..drawCircle(const Offset(16.5, 15), 5.5, ink.done)
      ..drawPath(
        Path()
          ..moveTo(13.8, 15.2)
          ..lineTo(15.8, 17.3)
          ..lineTo(19.4, 12.7),
        ink.done,
      );
  }

  static void _firstLine(Canvas canvas, _Pens ink) {
    final sheet = RRect.fromLTRBR(4, 1.5, 26, 22.5, const Radius.circular(1));
    canvas
      ..drawRRect(sheet, ink.paperFill)
      ..drawRRect(sheet, ink.outline);
    for (final y in [6.5, 10.0, 13.5, 17.0, 20.5]) {
      canvas.drawLine(Offset(9.5, y), Offset(24.5, y), ink.rule);
    }
    canvas.drawLine(
      const Offset(8.5, 2.2),
      const Offset(8.5, 21.8),
      ink.margen,
    );
    // One line written, by the margin; the rest still blank.
    final words = Path()..moveTo(10, 5.6);
    for (var x = 10.0; x < 20; x += 2) {
      words
        ..quadraticBezierTo(x + 0.5, 4, x + 1, 5.2)
        ..quadraticBezierTo(x + 1.5, 6.4, x + 2, 5.4);
    }
    canvas.drawPath(words, ink.done);
  }

  static void _mateServed(Canvas canvas, _Pens ink) {
    _floor(canvas, ink, 4, 20);
    const mouth = Rect.fromLTRB(7.5, 7.9, 16.5, 10.1);
    canvas
      ..drawPath(
        Path()
          ..moveTo(7.5, 9)
          ..cubicTo(4.5, 12, 5, 20.5, 12, 20.5)
          ..cubicTo(19, 20.5, 19.5, 12, 16.5, 9),
        ink.outline,
      )
      // The ochre inside of the gourd, seen over its rim.
      ..drawOval(mouth, ink.margenFill)
      ..drawOval(mouth, ink.outline)
      // The bombilla, in silver.
      ..drawLine(const Offset(12.5, 9), const Offset(16.5, 2.5), ink.silver)
      ..drawLine(const Offset(15.5, 2.5), const Offset(18, 2.5), ink.silver);
  }

  static void _openCuaderno(Canvas canvas, _Pens ink) {
    final left = Path()
      ..moveTo(18, 5)
      ..quadraticBezierTo(11, 3, 3, 4.5)
      ..lineTo(3, 20.5)
      ..quadraticBezierTo(11, 19, 18, 21)
      ..close();
    final right = Path()
      ..moveTo(18, 5)
      ..quadraticBezierTo(25, 3, 33, 4.5)
      ..lineTo(33, 20.5)
      ..quadraticBezierTo(25, 19, 18, 21)
      ..close();
    canvas
      ..drawPath(left, ink.paperFill)
      ..drawPath(right, ink.paperFill);
    for (final y in [9.0, 12.0, 15.0, 18.0]) {
      canvas
        ..drawLine(Offset(5, y), Offset(16.5, y), ink.rule)
        ..drawLine(Offset(21.5, y), Offset(31, y), ink.rule);
    }
    canvas
      ..drawLine(const Offset(20.5, 6), const Offset(20.5, 19.5), ink.margen)
      ..drawPath(left, ink.outline)
      ..drawPath(right, ink.outline)
      // The pencil, resting across the right page.
      ..save()
      ..translate(21.5, 19)
      ..rotate(-0.6)
      ..drawRRect(
        RRect.fromLTRBR(0, -1, 10, 1, const Radius.circular(0.4)),
        ink.paperFill,
      )
      ..drawRRect(
        RRect.fromLTRBR(0, -1, 10, 1, const Radius.circular(0.4)),
        ink.done,
      )
      ..drawLine(const Offset(1.6, -1), const Offset(1.6, 1), ink.silver)
      ..drawPath(
        Path()
          ..moveTo(10, -1)
          ..lineTo(12.6, 0)
          ..lineTo(10, 1),
        ink.done,
      )
      ..restore();
  }

  static void _objectsOnALine(Canvas canvas, _Pens ink) {
    _floor(canvas, ink, 1, 79);
    const objects = [
      (RondaObject.mate, 0.0),
      (RondaObject.termo, 18.0),
      (RondaObject.mazo, 37.0),
      (RondaObject.bizcochos, 56.0),
    ];
    for (final (object, x) in objects) {
      canvas
        ..save()
        ..translate(x, 0);
      for (final path in rondaObjectPaths(object)) {
        canvas.drawPath(path, ink.done);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) =>
      scene != oldDelegate.scene || inks != oldDelegate.inks;
}

/// The pens and fills a scene is drawn with, made from [_Inks] at the
/// scene's stroke.
typedef _Pens = ({
  Paint outline,
  Paint done,
  Paint margen,
  Paint silver,
  Paint rule,
  Paint doneFill,
  Paint margenFill,
  Paint paperFill,
});
