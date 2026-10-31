import 'dart:async';

import 'package:error_reporter/src/models/models.dart';
import 'package:error_reporter/src/scrub.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// The longest screen or step kept, in characters.
const maxLabelLength = 80;

/// Sends scrubbed error reports somewhere the owner can read them:
/// Crashlytics on Android and iOS (`CrashlyticsErrorReporter`), the
/// `report_client_error` callable on web (`CallableErrorReporter`), or the
/// debug log on a phone that must not send (`LocalErrorReporter`).
///
/// Every report is built here, so every sink gets the same scrubbed fields
/// ([ErrorReport]); a report that fails to send is dropped, never reported
/// again.
abstract class ErrorReporter {
  /// A reporter for the app described by [app].
  new({required this.app});

  /// The platform, version, build and flavor every report carries.
  final AppInfo app;

  String _screen = '';

  /// The route pattern on screen, as [setScreen] last set it.
  String get screen => _screen;

  /// Records the route pattern on screen (`/acta/:rondaId`, never a filled
  /// path), which uncaught errors and bloc errors carry.
  void setScreen(String screen) => _screen = _label(screen);

  /// Records who is signed in, as a hash ([uidHash]), or nobody. The web log
  /// takes the uid from the call's own auth instead, so only Crashlytics
  /// keeps it.
  Future<void> setUser(String? uid) async {}

  /// Reports [error], which nothing handled or a cubit added
  /// (`addError`): its code, its scrubbed first line and its scrubbed
  /// [stack], with the current screen and [step].
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String step = '',
  }) => _deliver(
    () => ErrorReport(
      app: app,
      screen: _screen,
      step: _label(step),
      code: errorCode(error),
      message: scrubMessage(error.toString()),
      stack: scrubStack(stack?.toString() ?? ''),
      fatal: fatal,
    ),
  );

  /// Reports a handled failure that matters (the voice upload failing):
  /// where ([screen], [step]) and a typed [code], with no message or stack.
  ///
  /// ```dart
  /// errorReporter.reportFailure(
  ///   screen: OnboardingPage.path,
  ///   step: 'voiceUpload',
  ///   code: 'voice/${failure.reason.name}',
  /// );
  /// ```
  Future<void> reportFailure({
    required String screen,
    required String step,
    required String code,
  }) => _deliver(
    () => ErrorReport(
      app: app,
      screen: _label(screen),
      step: _label(step),
      code: capText(scrub(code), maxCodeLength),
    ),
  );

  Future<void> _deliver(ErrorReport Function() build) async {
    try {
      await send(build());
    } on Object {
      // An error log that can't send drops the report: reporting the
      // reporter's own failure would loop.
    }
  }

  /// Sends one scrubbed [report].
  @protected
  Future<void> send(ErrorReport report);

  /// A Firebase error's `plugin/code` (`firebase_storage/unauthorized`),
  /// else the error's type. Release web builds minify type names, so there
  /// a typed [reportFailure] code reads better.
  static String errorCode(Object error) => capText(
    error is FirebaseException
        ? '${error.plugin}/${error.code}'
        : error.runtimeType.toString(),
    maxCodeLength,
  );

  static String _label(String text) => capText(scrub(text), maxLabelLength);
}
