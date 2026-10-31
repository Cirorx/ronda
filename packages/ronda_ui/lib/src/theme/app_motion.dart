import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// {@template app_motion}
/// Ronda's motion tokens (`docs/DESIGN.md` § Motion and feel).
///
/// Springs are written the way Apple's *Designing Fluid Interfaces* writes
/// them, as a damping ratio (1 is no bounce) and a response in seconds (how
/// quickly the value gets there; not a duration), and converted here to
/// Flutter's [SpringDescription]. Only state changes animate. Read
/// [RondaMotion.of] to honour reduced motion.
/// {@endtemplate}
abstract final class AppMotion {
  /// A spring from Apple's two parameters: [dampingRatio] (1 is critically
  /// damped, below 1 bounces) and [response] in seconds.
  ///
  /// With a mass of 1, stiffness is (2π / response)² and damping is
  /// 4π · dampingRatio / response.
  static SpringDescription spring({
    required double dampingRatio,
    required double response,
  }) {
    final angular = 2 * math.pi / response;
    return SpringDescription(
      mass: 1,
      stiffness: angular * angular,
      damping: 2 * dampingRatio * angular,
    );
  }

  /// Damping ratio of [standard]: critically damped, no overshoot.
  static const double standardDampingRatio = 1;

  /// Response of [standard], in seconds.
  static const double standardResponse = 0.35;

  /// Damping ratio of [sheet]: a little bounce.
  static const double sheetDampingRatio = 0.8;

  /// Response of [sheet], in seconds.
  static const double sheetResponse = 0.3;

  /// The default spring for every state change: damping 1, response 0.35 s.
  static final SpringDescription standard = spring(
    dampingRatio: standardDampingRatio,
    response: standardResponse,
  );

  /// The spring a sheet settles with after a flick: damping 0.8, response
  /// 0.3 s. Only momentum earns the bounce; a slow release uses [standard].
  static final SpringDescription sheet = spring(
    dampingRatio: sheetDampingRatio,
    response: sheetResponse,
  );

  /// How long [standard] takes to look settled; the length of a
  /// time-based animation that follows it, such as [RondaSwap].
  static const Duration standardDuration = Duration(milliseconds: 350);

  /// [standard] as a curve over [standardDuration], for widgets that take a
  /// [Curve] rather than a spring.
  static const Curve standardCurve = _SpringCurve();

  /// The scale a surface shrinks to while it is pressed.
  static const double pressedScale = 0.97;

  /// The scale a new state settles from in [RondaSwap].
  static const double swapScale = 0.96;

  /// How long a press takes to shrink and to come back: 100 ms.
  static const Duration press = Durations.short2;

  /// The curve of a press.
  static const Curve pressCurve = Easing.standard;

  /// How long a mouse's hover tint takes to fade in and out on the
  /// tappables whose [InkWell] Ronda builds (a slot cell, a door, a seat
  /// card). Hover is never a keyboard action, so it may ease; focus never
  /// does ([FocusRing] appears at once).
  static const Duration hover = Durations.short3;

  /// How long the reduced-motion cross-fade takes: 150 ms.
  static const Duration crossFade = Durations.short3;

  /// The curve of the reduced-motion cross-fade.
  static const Curve crossFadeCurve = Easing.standard;

  /// A release faster than this, in logical pixels per second, decides
  /// direction by its sign alone.
  static const double flickVelocity = 300;

  /// Scroll-like deceleration for [project]: 0.998.
  static const double decelerationRate = 0.998;

  /// How much a rubber band gives: Apple's 0.55.
  static const double rubberBandConstant = 0.55;

  /// Where a gesture released at [velocity] (logical pixels per second)
  /// would come to rest, relative to where it was let go: Apple's
  /// `project()`, the same exponential decay as scrolling.
  static double project(
    double velocity, {
    double decelerationRate = AppMotion.decelerationRate,
  }) {
    return (velocity / 1000) * decelerationRate / (1 - decelerationRate);
  }

  /// How far something follows a finger that has gone [overshoot] past a
  /// boundary, in an area [dimension] long: it gives less the further it
  /// goes, and never reaches [dimension].
  static double rubberBand(
    double overshoot,
    double dimension, {
    double constant = rubberBandConstant,
  }) {
    if (dimension <= 0) return 0;
    return (overshoot * dimension * constant) /
        (dimension + constant * overshoot.abs());
  }
}

/// {@template ronda_motion}
/// The one place a widget asks how to move: it reads
/// [MediaQuery.disableAnimationsOf] and swaps springs and slides for a
/// cross-fade, or for no motion at all, when the person asked for less
/// motion.
/// {@endtemplate}
class RondaMotion {
  const new _({required this.reduced});

  /// {@macro ronda_motion}
  factory of(BuildContext context) => RondaMotion._(
    reduced: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
  );

  /// Whether the person asked for reduced motion.
  final bool reduced;

  /// [spring], or `null` when motion is reduced: the value then jumps.
  SpringDescription? springOr(SpringDescription spring) =>
      reduced ? null : spring;

  /// [duration], or [Duration.zero] when motion is reduced.
  Duration durationOr(Duration duration) => reduced ? Duration.zero : duration;

  /// Wraps [child] in [moving] (a slide, a scale) driven by [animation], or
  /// in a cross-fade when motion is reduced. Without [moving], a fade.
  Widget transition({
    required Animation<double> animation,
    required Widget child,
    Widget Function(Animation<double> animation, Widget child)? moving,
  }) {
    if (reduced || moving == null) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: AppMotion.crossFadeCurve,
        ),
        child: child,
      );
    }
    return moving(animation, child);
  }
}

/// [AppMotion.standard] from 0 to 1, sampled over its response.
class _SpringCurve extends Curve {
  const new();

  static final _simulation = SpringSimulation(AppMotion.standard, 0, 1, 0);

  @override
  double transformInternal(double t) {
    return _simulation.x(t * AppMotion.standardResponse).clamp(0.0, 1.0);
  }
}
