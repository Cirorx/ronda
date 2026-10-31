import 'package:flutter/physics.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// {@template spring_builder}
/// Follows [value] on a spring and builds with where the spring is now: a
/// seat filling, a check settling in, anything that moves because the state
/// changed.
///
/// A new [value] mid-flight retargets from where the spring is, at the speed
/// it is going, so changes never jump or stop dead. Given [from], a freshly
/// built one springs from there to [value] (a bar on a new screen moving on
/// from where the last screen's bar stood). With reduced motion the value
/// is set at once and nothing moves.
/// {@endtemplate}
class SpringBuilder extends StatefulWidget {
  /// {@macro spring_builder}
  const new({
    required this.value,
    required this.builder,
    this.from,
    this.spring,
    this.child,
    super.key,
  });

  /// Where the spring goes.
  final double value;

  /// Builds with the spring's current value; [child] is passed through.
  final ValueWidgetBuilder<double> builder;

  /// Where a freshly built one starts, springing to [value]; [value] when
  /// `null`. Read once, when it is first built.
  final double? from;

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
    value: widget.from ?? widget.value,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion lives in the MediaQuery, which initState can't read.
    if (_started) return;
    _started = true;
    if (_controller.value != widget.value) _follow();
  }

  @override
  void didUpdateWidget(SpringBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) _follow();
  }

  /// Springs from where it is, at the speed it is going, to [widget]'s
  /// value; jumps there with reduced motion.
  void _follow() {
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
