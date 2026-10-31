import 'dart:async';

import 'package:error_reporter/src/error_reporter.dart';
import 'package:flutter/foundation.dart';

/// Sends every error nothing caught to [reporter], as fatal:
/// `FlutterError.onError` (build, layout, paint; step `framework`) and
/// [PlatformDispatcher.onError] (uncaught async errors; step `uncaught`).
///
/// Whatever handled those before still runs first (bootstrap's debug log).
/// The framework's [FlutterErrorDetails] are not sent: their context can
/// describe widgets with what people typed, so only the exception and its
/// stack go, scrubbed. [dispatcher] is the running app's unless a test
/// passes one.
void installErrorHooks(
  ErrorReporter reporter, {
  PlatformDispatcher? dispatcher,
}) {
  final previousFlutter = FlutterError.onError;
  FlutterError.onError = (details) {
    previousFlutter?.call(details);
    unawaited(
      reporter.recordError(
        details.exception,
        details.stack,
        fatal: true,
        step: 'framework',
      ),
    );
  };
  final platform = dispatcher ?? PlatformDispatcher.instance;
  final previousPlatform = platform.onError;
  platform.onError = (error, stack) {
    previousPlatform?.call(error, stack);
    unawaited(
      reporter.recordError(error, stack, fatal: true, step: 'uncaught'),
    );
    return true;
  };
}
