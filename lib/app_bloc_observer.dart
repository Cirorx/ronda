import 'dart:async';
import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';
import 'package:error_reporter/error_reporter.dart';

/// Writes one log line, with an optional stack trace.
typedef BlocLogger = void Function(String message, {StackTrace? stackTrace});

/// Logs bloc activity by type name only, and sends every error a bloc adds
/// to the error log.
///
/// Ronda's states and events carry phone numbers, needs and transcripts, so
/// this observer never prints a state, an event or an error message: only
/// their runtime types. The development flavor logs ([logger] defaults to
/// `dart:developer`'s `log`); production passes `logger: null`.
///
/// A bloc's changes are logged at most once per [changeLogInterval]: the
/// voice note's level stream alone changes its state about 25 times a
/// second.
///
/// Bootstrap installs it in both flavors with the [errorReporter]: a
/// cubit's `addError(failure, stackTrace)` reaches it with the cubit's type
/// as the step, and the reporter scrubs the error before anything leaves.
class AppBlocObserver extends BlocObserver {
  new({
    this.logger = developer.log,
    this.errorReporter,
    this._now = DateTime.now,
  });

  /// Where lines go; `null` logs nothing.
  final BlocLogger? logger;

  /// Where bloc errors go.
  final ErrorReporter? errorReporter;

  final DateTime Function() _now;
  final _lastChangeLogged = Expando<DateTime>();

  /// The least time between two logged changes of one bloc.
  static const changeLogInterval = Duration(seconds: 1);

  /// This observer, also sending errors to [reporter].
  AppBlocObserver reportingTo(ErrorReporter reporter) =>
      AppBlocObserver(logger: logger, errorReporter: reporter, now: _now);

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    final logger = this.logger;
    if (logger == null) return;
    final now = _now();
    final last = _lastChangeLogged[bloc];
    if (last != null && now.difference(last) < changeLogInterval) return;
    _lastChangeLogged[bloc] = now;
    logger(
      'onChange(${bloc.runtimeType}, '
      '${change.currentState.runtimeType} -> '
      '${change.nextState.runtimeType})',
    );
  }

  @override
  void onTransition(
    Bloc<dynamic, dynamic> bloc,
    Transition<dynamic, dynamic> transition,
  ) {
    super.onTransition(bloc, transition);
    logger?.call(
      'onTransition(${bloc.runtimeType}, ${transition.event.runtimeType})',
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    logger?.call(
      'onError(${bloc.runtimeType}, ${error.runtimeType})',
      stackTrace: stackTrace,
    );
    unawaited(
      errorReporter?.recordError(
        error,
        stackTrace,
        step: '${bloc.runtimeType}',
      ),
    );
    super.onError(bloc, error, stackTrace);
  }
}
