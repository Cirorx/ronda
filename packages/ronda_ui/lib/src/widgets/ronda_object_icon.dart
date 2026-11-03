import 'package:ronda_ui/ronda_ui.dart';
import 'package:ronda_ui/src/widgets/ronda_object_paths.dart';

/// The things a ronda is made of, drawn by [RondaObjectIcon]: what people
/// bring, and what the pretext needs (`docs/DESIGN.md`, "Objects, not
/// people").
enum RondaObject {
  /// The mate, with its bombilla.
  mate,

  /// The termo.
  termo,

  /// A football, for fútbol 5.
  pelota,

  /// A deck of cards, for truco.
  mazo,

  /// Bizcochos on a plate.
  bizcochos,

  /// A folding chair.
  sillas,
}

/// {@template ronda_object_icon}
/// One of Ronda's object line icons, drawn in code on a 24-unit grid with
/// round strokes, in the surrounding [IconTheme]'s colour unless [color]
/// is given: the same set says "lo que traés" on a card and illustrates the
/// pretext on a wide onboarding screen, and is the flyers' art.
///
/// It is decoration unless it has a [semanticLabel]: the words beside it
/// usually say the same thing.
/// {@endtemplate}
class const RondaObjectIcon(
  /// What it draws.
  final RondaObject object, {

  /// Its width and height; the [IconTheme]'s size, or 24, when `null`.
  final double? size,

  /// Its colour; the [IconTheme]'s when `null`.
  final Color? color,

  /// What a screen reader says for it; decoration when `null`.
  final String? semanticLabel,
  super.key,
}) extends StatelessWidget {
  /// {@macro ronda_object_icon}
  this;

  /// The grid the icons are drawn on.
  static const double grid = 24;

  /// The stroke's width on [grid]; it scales with the icon.
  static const double stroke = 1.6;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final side = size ?? iconTheme.size ?? grid;
    final paint = CustomPaint(
      size: Size.square(side),
      painter: _ObjectPainter(object: object, color: color ?? iconTheme.color!),
    );
    return switch (semanticLabel) {
      final label? => Semantics(label: label, image: true, child: paint),
      null => ExcludeSemantics(child: paint),
    };
  }
}

class _ObjectPainter extends CustomPainter {
  new({required this.object, required this.color});

  final RondaObject object;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / RondaObjectIcon.grid);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = RondaObjectIcon.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final path in rondaObjectPaths(object)) {
      canvas.drawPath(path, pen);
    }
  }

  @override
  bool shouldRepaint(_ObjectPainter oldDelegate) =>
      object != oldDelegate.object || color != oldDelegate.color;
}
