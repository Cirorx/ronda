import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Opens [builder]'s content as Ronda's modal sheet ([RondaSheetRoute]) over
/// [context]'s navigator and resolves with what it was popped with.
///
/// [isDismissible] lets a tap on the scrim close it; [enableDrag] lets the
/// person drag or throw it down. Both close it only when the route may pop.
Future<T?> showRondaSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final localizations = MaterialLocalizations.of(context);
  return navigator.push(
    RondaSheetRoute<T>(
      builder: builder,
      barrierLabel: localizations.scrimLabel,
      sheetLabel: localizations.bottomSheetLabel,
      dismissLabel: localizations.modalBarrierDismissLabel,
      barrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor!,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      reduceMotion: RondaMotion.of(context).reduced,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
    ),
  );
}

/// {@template ronda_sheet_route}
/// A modal sheet on paper, over a dimming scrim, that behaves like a thing
/// in the hand:
/// - it rises from the bottom on [AppMotion.standard] and leaves the same
///   way;
/// - it follows a drag 1:1 from wherever it was grabbed, including the
///   content when that content is at its top, and can be grabbed again
///   while it is still moving, without a jump;
/// - on release it carries the finger's speed: [AppMotion.project] says
///   where the throw would land, and it closes when that is past half its
///   height and the finger wasn't moving up; otherwise it springs back. A
///   flick earns the [AppMotion.sheet] spring, a slow release the standard
///   one;
/// - dragged up past its top it rubber-bands ([AppMotion.rubberBand]);
/// - the scrim lightens as it goes down.
///
/// With reduced motion it cross-fades in and out, and a drag still moves
/// it, since the finger leads, but it doesn't spring.
/// {@endtemplate}
class RondaSheetRoute<T> extends PopupRoute<T> {
  /// {@macro ronda_sheet_route}
  new({
    required this.builder,
    required this.barrierLabel,
    required this.sheetLabel,
    required this.dismissLabel,
    required this.barrierColor,
    this.capturedThemes,
    this.reduceMotion = false,
    this.isDismissible = true,
    this.enableDrag = true,
    super.settings,
  });

  /// Builds the sheet's content.
  final WidgetBuilder builder;

  @override
  final String barrierLabel;

  /// What a screen reader calls the sheet.
  final String sheetLabel;

  /// What a screen reader says for the handle, which closes the sheet.
  final String dismissLabel;

  @override
  final Color barrierColor;

  /// Themes from where the sheet was opened.
  final CapturedThemes? capturedThemes;

  /// Whether the person asked for reduced motion when it opened.
  final bool reduceMotion;

  /// Whether a tap on the scrim closes the sheet.
  final bool isDismissible;

  /// Whether the sheet can be dragged and thrown down.
  final bool enableDrag;

  final _sheetKey = GlobalKey<_RondaSheetState>();

  /// How far the sheet has been dragged down, from 0 (open) to 1 (gone).
  final _dragFraction = ValueNotifier<double>(0);

  @override
  bool get barrierDismissible => isDismissible;

  @override
  Duration get transitionDuration =>
      reduceMotion ? AppMotion.crossFade : AppMotion.standardDuration;

  @override
  Simulation? createSimulation({required bool forward}) {
    final controller = this.controller!;
    if (reduceMotion || (!forward && controller.isDismissed)) return null;
    return SpringSimulation(
      AppMotion.standard,
      controller.value,
      forward ? 1 : 0,
      0,
      tolerance: const Tolerance(velocity: 0.01),
      snapToEnd: true,
    );
  }

  /// Whether a drag may close the sheet now.
  bool get _canDragClose =>
      enableDrag && popDisposition != RoutePopDisposition.doNotPop;

  /// Ends the entrance where it is, so a drag can take over from there.
  void _settle() => controller!.value = 1;

  /// The sheet is off screen after a drag: removes it without moving it.
  void _closeAfterDrag() {
    controller!.value = 0;
    if (isCurrent) {
      navigator!.pop();
    } else if (isActive) {
      navigator!.removeRoute(this);
    }
  }

  void _dismissFromBarrier() {
    final sheet = _sheetKey.currentState;
    if (sheet != null && !reduceMotion) {
      sheet.close();
    } else {
      navigator?.maybePop();
    }
  }

  @override
  Widget buildModalBarrier() {
    return AnimatedBuilder(
      animation: Listenable.merge([animation, _dragFraction]),
      builder: (context, _) {
        final shown = animation!.value * (1 - _dragFraction.value);
        return ModalBarrier(
          color: barrierColor.withValues(
            alpha: barrierColor.a * shown.clamp(0.0, 1.0),
          ),
          dismissible: barrierDismissible,
          semanticsLabel: barrierLabel,
          onDismiss: _dismissFromBarrier,
        );
      },
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final sheet = _RondaSheet(
      key: _sheetKey,
      route: this,
      child: Builder(builder: builder),
    );
    return capturedThemes?.wrap(sheet) ?? sheet;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (!reduceMotion) return child;
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: AppMotion.crossFadeCurve,
      ),
      child: child,
    );
  }

  @override
  void dispose() {
    _dragFraction.dispose();
    super.dispose();
  }
}

class _RondaSheet extends StatefulWidget {
  const new({required this.route, required this.child, super.key});

  final RondaSheetRoute<dynamic> route;
  final Widget child;

  @override
  State<_RondaSheet> createState() => _RondaSheetState();
}

class _RondaSheetState extends State<_RondaSheet>
    with SingleTickerProviderStateMixin {
  /// Widest the sheet gets, as Material's sheets on wide screens.
  static const double maxWidth = 640;

  /// A release slower than this (logical pixels per second) upward still
  /// counts as letting go, not as pushing the sheet back up.
  static const double stillVelocity = 50;

  /// Height of the handle's row: a 48 dp target.
  static const double handleRowHeight = AppTheme.minTarget;

  /// Size of the handle itself.
  static const Size handleSize = Size(32, 4);

  final GlobalKey _paperKey = GlobalKey();

  /// From one sheet-height below the bottom edge to resting on it.
  static final _riseOffset = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  );

  /// How far the sheet sits below where it rests, in logical pixels;
  /// negative while rubber-banding above it.
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  )..addListener(_followOffset);

  /// Where the finger is relative to the rest position, before the rubber
  /// band.
  double _finger = 0;
  bool _scrollDriven = false;
  bool _closing = false;

  RondaSheetRoute<dynamic> get _route => widget.route;

  double get _height {
    final box = _paperKey.currentContext?.findRenderObject() as RenderBox?;
    return box != null && box.hasSize ? box.size.height : 0;
  }

  void _followOffset() {
    final height = _height;
    final value = _offset.value;
    _route._dragFraction.value = height <= 0
        ? 0
        : (value / height).clamp(0.0, 1.0);
    if (_closing && value >= height) {
      _closing = false;
      _offset.stop();
      _route._closeAfterDrag();
    }
  }

  double _shown(double finger) =>
      finger >= 0 ? finger : AppMotion.rubberBand(finger, _height);

  /// The finger position that shows [offset], undoing the rubber band.
  double _fingerFor(double offset) {
    if (offset >= 0) return offset;
    final height = _height;
    final pulled = math.min(-offset, height * 0.999);
    return -pulled *
        height /
        (AppMotion.rubberBandConstant * (height - pulled));
  }

  void _start() {
    _closing = false;
    _offset.stop();
    final animation = _route.animation!;
    if (!_route.reduceMotion && animation.status == AnimationStatus.forward) {
      // Grabbed while still rising: carry on from where it is on screen.
      final onScreen = (1 - animation.value) * _height + _offset.value;
      _route._settle();
      _offset.value = onScreen;
    }
    _finger = _fingerFor(_offset.value);
  }

  void _update(double delta) {
    _finger += delta;
    _offset.value = _shown(_finger);
  }

  void _end(double velocity) {
    final projected = _offset.value + AppMotion.project(velocity);
    final closes =
        _route._canDragClose &&
        projected > _height / 2 &&
        velocity > -stillVelocity;
    final flicked = velocity.abs() >= AppMotion.flickVelocity;
    _settle(
      closes: closes,
      velocity: velocity,
      spring: flicked ? AppMotion.sheet : AppMotion.standard,
    );
  }

  /// Closes the sheet the way a drag would, still grabbable on its way.
  /// A sheet that may not pop asks the navigator instead, so its
  /// [PopScope] hears about it and it stays.
  void close() {
    if (_route.popDisposition == RoutePopDisposition.doNotPop) {
      _route.navigator?.maybePop();
      return;
    }
    _settle(closes: true, velocity: 0, spring: AppMotion.standard);
  }

  void _settle({
    required bool closes,
    required double velocity,
    required SpringDescription spring,
  }) {
    if (_route.reduceMotion) {
      if (closes) {
        _route.navigator?.pop();
      } else {
        _offset.value = 0;
      }
      return;
    }
    final height = _height;
    _closing = closes;
    _offset.animateWith(
      SpringSimulation(
        spring,
        _offset.value,
        // Aim just past the bottom edge, so a spring that never quite
        // arrives still leaves the screen.
        closes ? height + 1 : 0,
        velocity,
        snapToEnd: true,
      ),
    );
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    switch (notification) {
      case OverscrollNotification(:final overscroll, dragDetails: _?)
          when overscroll < 0 || _scrollDriven:
        if (!_scrollDriven) {
          _scrollDriven = true;
          _start();
        }
        _update(-overscroll);
      case ScrollEndNotification(:final dragDetails) when _scrollDriven:
        _scrollDriven = false;
        _end(dragDetails?.primaryVelocity ?? 0);
      default:
        break;
    }
    return false;
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sheetTheme = theme.bottomSheetTheme;
    final paperColor = sheetTheme.modalBackgroundColor!;
    final enableDrag = _route.enableDrag;

    final handle = Semantics(
      container: true,
      button: true,
      label: _route.dismissLabel,
      onTap: _route.isDismissible ? close : null,
      child: SizedBox(
        height: handleRowHeight,
        child: Center(
          child: Container(
            width: handleSize.width,
            height: handleSize.height,
            decoration: BoxDecoration(
              color: sheetTheme.dragHandleColor,
              borderRadius: BorderRadius.circular(handleSize.height / 2),
            ),
          ),
        ),
      ),
    );

    final paper = Material(
      key: _paperKey,
      color: paperColor,
      shape: sheetTheme.shape,
      clipBehavior: sheetTheme.clipBehavior ?? Clip.none,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(excluding: !_route.isDismissible, child: handle),
          Flexible(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  physics: const ClampingScrollPhysics(),
                  overscroll: false,
                ),
                child: NotificationListener<ScrollNotification>(
                  onNotification: enableDrag ? _onScroll : null,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Paper continues below the sheet, so rubber-banding up shows more
    // paper rather than what is behind it.
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheet = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: -screenHeight,
          height: screenHeight + AppRadius.xl,
          child: ColoredBox(color: paperColor),
        ),
        paper,
      ],
    );

    final animation = _route.animation!;
    // The drag offset sits outside the layout, so a sheet pulled above its
    // resting place still receives touches where it is drawn.
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: _offset,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, _offset.value), child: child),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: SlideTransition(
              position: _route.reduceMotion
                  ? const AlwaysStoppedAnimation(Offset.zero)
                  : animation.drive(_riseOffset),
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: _route.sheetLabel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Tracks from the touch-down point, so the sheet stays where
                  // the finger grabbed it rather than lagging by the slop.
                  dragStartBehavior: DragStartBehavior.down,
                  excludeFromSemantics: true,
                  onVerticalDragStart: enableDrag ? (_) => _start() : null,
                  onVerticalDragUpdate: enableDrag
                      ? (details) => _update(details.primaryDelta ?? 0)
                      : null,
                  onVerticalDragEnd: enableDrag
                      ? (details) => _end(details.primaryVelocity ?? 0)
                      : null,
                  child: sheet,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
