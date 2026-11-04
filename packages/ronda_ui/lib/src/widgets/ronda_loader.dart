import 'dart:math' as math;

import 'package:ronda_ui/ronda_ui.dart';

/// {@template ronda_loader}
/// What the app shows while it waits: Ronda's mark, five dots in a ring,
/// gathering into the middle and opening out again as the ring turns a fifth
/// of the way round, so every loop ends where it began. It takes the place
/// of a progress ring everywhere ([LoadingStatus], [BusyLabel],
/// [TapToBlurPhoto]).
///
/// With reduced motion it holds still as the mark: the [StatusLine] beside
/// it already says what is happening.
/// {@endtemplate}
class RondaLoader extends StatefulWidget {
  /// {@macro ronda_loader}
  const new({this.size = defaultSize, this.color, super.key});

  /// The side of the square it draws in.
  final double size;

  /// The dots' colour; the theme's primary when `null`.
  final Color? color;

  /// The side a [CircularProgressIndicator] takes by default.
  static const double defaultSize = 36;

  /// One gather and open.
  static const Duration loop = Duration(milliseconds: 1400);

  @override
  State<RondaLoader> createState() => _RondaLoaderState();
}

class _RondaLoaderState extends State<RondaLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RondaLoader.loop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (RondaMotion.of(context).reduced) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        painter: _MarkPainter(animation: _controller, color: color),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  new({required this.animation, required this.color})
    : super(repaint: animation);

  final Animation<double> animation;
  final Color color;

  /// On the icon's 24-unit grid (tool/icons/render_icons.swift): the ring's
  /// radius and each dot's.
  static const double ring = 7.4;
  static const double dot = 2.7;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 24;
    final t = animation.value;
    // 0 at the ends of the loop, 1 in the middle: the dots gather, then open.
    final gather = (1 - math.cos(2 * math.pi * t)) / 2;
    final turn = Curves.easeInOut.transform(t) * 2 * math.pi / 5;
    final radius = ring * unit * (1 - 0.72 * gather);
    final paint = Paint()..color = color;
    final centre = size.center(Offset.zero);
    for (var i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + turn + i * 2 * math.pi / 5;
      canvas.drawCircle(
        centre + Offset(math.cos(angle), math.sin(angle)) * radius,
        dot * unit * (1 + 0.12 * gather),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.animation != animation;
}
