import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';

/// Writes one log line, with an optional stack trace.
typedef BlocLogger = void Function(String message, {StackTrace? stackTrace});

/// Logs bloc activity by type name only.
///
/// Ronda's states and events carry phone numbers, needs and transcripts, so
/// this observer never prints a state, an event or an error message: only
/// their runtime types. Install it in the development flavor only.
class const AppBlocObserver({final BlocLogger logger = developer.log})
    extends BlocObserver {
  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
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
    logger(
      'onTransition(${bloc.runtimeType}, ${transition.event.runtimeType})',
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    logger(
      'onError(${bloc.runtimeType}, ${error.runtimeType})',
      stackTrace: stackTrace,
    );
    super.onError(bloc, error, stackTrace);
  }
}
