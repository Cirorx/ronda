import 'package:ronda_ui/ronda_ui.dart';

/// Builds an entry's transition; [leaving] is true for a child on its way
/// out, whose [animation] runs from where it was back to 0.
typedef SteadyTransitionBuilder = Widget Function(
  Widget child,
  Animation<double> animation, {
  required bool leaving,
});

/// {@template steady_switcher}
/// [AnimatedSwitcher]'s job, with two differences [RondaSwap] and
/// [StepSwitcher] need:
/// - its controllers keep [duration] when the phone asks for less motion
///   ([AnimationBehavior.preserve]). [AnimatedSwitcher]'s controllers run
///   at 5% of their duration under that platform flag, which turns a
///   150 ms cross-fade into a cut;
/// - a child on its way out ignores touches and screen readers, so there
///   are never two tappable or readable copies mid-swap.
///
/// Like [AnimatedSwitcher], the first child shows without a transition, and
/// a child with a new key or type swaps in.
/// {@endtemplate}
class SteadySwitcher extends StatefulWidget {
  /// {@macro steady_switcher}
  const new({
    required this.child,
    required this.duration,
    required this.transitionBuilder,
    this.layoutBuilder = AnimatedSwitcher.defaultLayoutBuilder,
    super.key,
  });

  /// The current child, keyed by state.
  final Widget child;

  /// How long a child takes to come in, and to leave.
  final Duration duration;

  /// Wraps each child in its transition.
  final SteadyTransitionBuilder transitionBuilder;

  /// Lays the current child out with the ones leaving.
  final AnimatedSwitcherLayoutBuilder layoutBuilder;

  @override
  State<SteadySwitcher> createState() => _SteadySwitcherState();
}

class _Entry {
  new(this.serial, this.child, this.controller);

  final int serial;
  Widget child;
  final AnimationController controller;
}

class _SteadySwitcherState extends State<SteadySwitcher>
    with TickerProviderStateMixin {
  late _Entry _current = _entry(widget.child, value: 1);
  final List<_Entry> _leaving = [];
  int _serial = 0;

  _Entry _entry(Widget child, {double value = 0}) => _Entry(
    _serial++,
    child,
    AnimationController(
      vsync: this,
      duration: widget.duration,
      value: value,
      animationBehavior: AnimationBehavior.preserve,
    ),
  );

  @override
  void didUpdateWidget(SteadySwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      for (final entry in [_current, ..._leaving]) {
        entry.controller.duration = widget.duration;
      }
    }
    if (Widget.canUpdate(_current.child, widget.child)) {
      _current.child = widget.child;
      return;
    }
    final leaving = _current;
    _leaving.add(leaving);
    leaving.controller.reverse().whenCompleteOrCancel(() {
      if (!mounted || !_leaving.remove(leaving)) return;
      leaving.controller.dispose();
      setState(() {});
    });
    _current = _entry(widget.child)..controller.forward();
  }

  @override
  void dispose() {
    for (final entry in [_current, ..._leaving]) {
      entry.controller.dispose();
    }
    super.dispose();
  }

  Widget _build(_Entry entry, {required bool leaving}) => KeyedSubtree(
    key: ValueKey(entry.serial),
    child: IgnorePointer(
      ignoring: leaving,
      child: ExcludeSemantics(
        excluding: leaving,
        child: widget.transitionBuilder(
          entry.child,
          entry.controller,
          leaving: leaving,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return widget.layoutBuilder(_build(_current, leaving: false), [
      for (final entry in _leaving) _build(entry, leaving: true),
    ]);
  }
}
