import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:ronda/acta/view/acta_page.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Mi ronda's way into ronda [rondaId]'s "Lo que hizo el programa": a card
/// with the agent's signature thread and a chevron, so it reads as the
/// organiser's log and as something to open.
class const ActaLink({
  /// The ronda whose acta it opens.
  required final String rondaId,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handle on the link.
  static const identifier = 'myRonda.acta';

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(ActaPage.location(rondaId)),
            child: Padding(
              padding: EdgeInsetsDirectional.all(context.appSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: context.appSpacing.sm,
                children: [
                  const AiSignature(),
                  Row(
                    spacing: context.appSpacing.sm,
                    children: [
                      const ExcludeSemantics(child: OrganiserMark()),
                      Expanded(
                        child: Text(
                          context.l10n.actaLink,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const ExcludeSemantics(child: Icon(Icons.chevron_right)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The organiser, drawn: a small soft figure in a hood, holding the
/// notebook where it writes down what it did. Ronda's own character for the
/// program, in the app's paper colours.
class const OrganiserMark({super.key}) extends StatelessWidget {
  /// The size it is drawn at.
  static const Size size = Size(56, 64);

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: size,
    // Its own ink and colours in both themes: on a dark card the theme's
    // text colour would vanish into its face.
    painter: _OrganiserPainter(
      line: const Color(0xFF241B12),
      notebook: const Color(0xFF4E6428),
    ),
  );
}

class _OrganiserPainter extends CustomPainter {
  new({required this.line, required this.notebook});

  final Color line;
  final Color notebook;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fill = Paint()..color = const Color(0xFFE9DCC6);

    // The hooded body: a dome on a soft round base.
    final body = RRect.fromLTRBAndCorners(
      w * 0.12,
      h * 0.04,
      w * 0.88,
      h * 0.98,
      topLeft: Radius.circular(w * 0.38),
      topRight: Radius.circular(w * 0.38),
      bottomLeft: Radius.circular(w * 0.22),
      bottomRight: Radius.circular(w * 0.22),
    );
    canvas
      ..drawRRect(body, fill)
      ..drawRRect(body, stroke);

    // The face in the hood.
    final face = Rect.fromLTRB(w * 0.27, h * 0.17, w * 0.73, h * 0.47);
    canvas
      ..drawOval(face, Paint()..color = const Color(0xFFF8EFE2))
      ..drawOval(face, stroke..strokeWidth = 1.2);
    final eye = Paint()..color = line;
    canvas
      ..drawCircle(Offset(w * 0.4, h * 0.3), 2.4, eye)
      ..drawCircle(Offset(w * 0.6, h * 0.3), 2.4, eye)
      ..drawArc(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.34),
          width: w * 0.14,
          height: h * 0.07,
        ),
        0.15,
        math.pi - 0.3,
        false,
        stroke..strokeWidth = 1.2,
      )
      ..drawCircle(
        Offset(w * 0.33, h * 0.37),
        2,
        Paint()..color = const Color(0x55E07A6B),
      )
      ..drawCircle(
        Offset(w * 0.67, h * 0.37),
        2,
        Paint()..color = const Color(0x55E07A6B),
      );

    // The notebook it holds, with two written lines.
    final book = RRect.fromLTRBR(
      w * 0.3,
      h * 0.56,
      w * 0.7,
      h * 0.84,
      const Radius.circular(3),
    );
    canvas.drawRRect(book, Paint()..color = notebook);
    final ink = Paint()
      ..color = const Color(0xFFF8F3EA)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(w * 0.37, h * 0.65), Offset(w * 0.63, h * 0.65), ink)
      ..drawLine(Offset(w * 0.37, h * 0.73), Offset(w * 0.56, h * 0.73), ink)
      // The two hands over the notebook's edges.
      ..drawCircle(Offset(w * 0.3, h * 0.7), 4.5, fill)
      ..drawCircle(Offset(w * 0.3, h * 0.7), 4.5, stroke..strokeWidth = 1.6)
      ..drawCircle(Offset(w * 0.7, h * 0.7), 4.5, fill)
      ..drawCircle(Offset(w * 0.7, h * 0.7), 4.5, stroke);
  }

  @override
  bool shouldRepaint(_OrganiserPainter oldDelegate) =>
      oldDelegate.line != line || oldDelegate.notebook != notebook;
}
