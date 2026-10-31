import 'package:ronda_ui/ronda_ui.dart';

/// {@template scroll_edge_fade}
/// The scroll edge above a bar pinned under a scrolling [child] ("Seguir"
/// under the questions): while there is more content below, a short fade of
/// the paper ([ColorScheme.surface]) over the last [height] of [child], so
/// what scrolls under the bar thins out instead of being cut by a hard edge.
/// At the end of the content, or when it all fits, there is nothing: never a
/// standing divider.
///
/// The fade comes and goes over [AppMotion.crossFade]. It only paints:
/// taps and screen readers go through it to [child], and [child]'s layout is
/// unchanged. Off ([enabled] `false`), it is [child] alone.
/// {@endtemplate}
class ScrollEdgeFade extends StatefulWidget {
  /// {@macro scroll_edge_fade}
  const new({
    required this.child,
    this.enabled = true,
    this.height = AppSpacing.unit * 2,
    super.key,
  });

  /// The scrolling content; its own scroll view is the one watched.
  final Widget child;

  /// Whether the fade is drawn at all.
  final bool enabled;

  /// How tall the fade is.
  final double height;

  @override
  State<ScrollEdgeFade> createState() => _ScrollEdgeFadeState();
}

class _ScrollEdgeFadeState extends State<ScrollEdgeFade> {
  /// Less content below than this, in logical pixels, is rounding, not
  /// content.
  static const double _slack = 0.5;

  bool _contentBelow = false;

  bool _update(ScrollMetrics metrics) {
    final below = metrics.extentAfter > _slack;
    if (below != _contentBelow) setState(() => _contentBelow = below);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final paper = Theme.of(context).colorScheme.surface;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) =>
          notification.depth == 0 && _update(notification.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) =>
            notification.depth == 0 && _update(notification.metrics),
        child: Stack(
          children: [
            widget.child,
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              height: widget.height,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: AnimatedOpacity(
                    opacity: _contentBelow ? 1 : 0,
                    duration: AppMotion.crossFade,
                    curve: AppMotion.crossFadeCurve,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [paper.withValues(alpha: 0), paper],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
