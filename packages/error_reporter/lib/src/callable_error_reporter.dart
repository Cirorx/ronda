import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:error_reporter/src/error_reporter.dart';
import 'package:error_reporter/src/models/models.dart';

/// Reports to Ronda's own error log through the `report_client_error`
/// callable, where Crashlytics doesn't run (web). It works signed out.
///
/// Reports wait [flushDelay] and go together, at most [batchSize] a call;
/// a fatal one goes at once, before the page can die. A session sends at
/// most [maxPerSession] reports, and each code and screen once. A call that
/// fails drops what it carried.
class CallableErrorReporter extends ErrorReporter {
  /// Built in bootstrap with the same `FirebaseFunctions` as every callable,
  /// so the development flavor reports to the emulator.
  new({
    required this._functions,
    required super.app,
    this.maxPerSession = 20,
    this.flushDelay = const Duration(seconds: 2),
  });

  /// The callable's name in `functions/main.py`.
  static const callableName = 'report_client_error';

  /// The most reports one call carries (the server takes 10).
  static const batchSize = 10;

  /// The most reports one session sends.
  final int maxPerSession;

  /// How long a report waits for others to go with it.
  final Duration flushDelay;

  final FirebaseFunctions _functions;
  final _seen = <String>{};
  final _queue = <ErrorReport>[];
  Timer? _timer;

  @override
  Future<void> send(ErrorReport report) async {
    if (_seen.length >= maxPerSession) return;
    if (!_seen.add('${report.code}|${report.screen}')) return;
    _queue.add(report);
    if (report.fatal) {
      await flush();
      return;
    }
    _timer ??= Timer(flushDelay, () => unawaited(flush()));
  }

  /// Sends whatever waits now.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    while (_queue.isNotEmpty) {
      final batch = _queue.take(batchSize).toList();
      _queue.removeRange(0, batch.length);
      try {
        await _functions.httpsCallable(callableName).call<Object?>({
          'reports': [for (final report in batch) report.toJson()],
        });
      } on Object {
        _queue.clear();
        return;
      }
    }
  }
}
