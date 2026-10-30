import 'package:flutter/physics.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// {@template spring_builder}
/// Follows [value] on a spring and builds with where the spring is now: a
/// seat filling, a check settling in, anything that moves because the state
/// changed.
///
/// A new [value] mid-flight retargets from where the spring is, at the speed
/// it is going, so changes never jump or stop dead. With reduced motion the
/// value is set at once and nothing moves.
/// {@endtemplate}
class SpringBuilder extends StatefulWidget {
  /// {@macro spring_builder}
  const new({
    required this.value,
    required this.builder,
    this.spring,
    this.child,
    super.key,
  });

  /// Where the spring goes.
  final double value;

  /// Builds with the spring's current value; [child] is passed through.
  final ValueWidgetBuilder<double> builder;

  /// The spring; [AppMotion.standard] by default.
  final SpringDescription? spring;

  /// A part of the subtree that doesn't depend on the value.
  final Widget? child;

  @override
  State<SpringBuilder> createState() => _SpringBuilderState();
}

class _SpringBuilderState extends State<SpringBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: widget.value,
  );

  @override
  void didUpdateWidget(SpringBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    final spring = RondaMotion.of(context)
        .springOr(widget.spring ?? AppMotion.standard);
    if (spring == null) {
      _controller.value = widget.value;
      return;
    }
    _controller.animateWith(
      SpringSimulation(
        spring,
        _controller.value,
        widget.value,
        _controller.velocity,
        snapToEnd: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          widget.builder(context, _controller.value, child),
      child: widget.child,
    );
  }
}
