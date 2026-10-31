import 'dart:math';

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:calendar_client/src/calendar_event.dart';
import 'package:calendar_client/src/download/download.dart';
import 'package:calendar_client/src/ics.dart';
import 'package:flutter/foundation.dart';

/// What [CalendarClient.add] did.
enum CalendarOutcome {
  /// The phone's calendar opened with the event filled in; the person saves
  /// it there, or doesn't. Nothing tells whether they did.
  opened,

  /// A browser downloaded the event as an `.ics` file.
  downloaded,
}

/// {@template calendar_unavailable_exception}
/// The phone's calendar couldn't be opened, or the file couldn't be saved.
/// {@endtemplate}
class const CalendarUnavailableException() implements Exception {
  /// {@macro calendar_unavailable_exception}
  this;

  @override
  String toString() => 'CalendarUnavailableException';
}

/// {@template calendar_client}
/// Puts one event in the person's own calendar, so the reminder is theirs
/// and Ronda sends nothing.
///
/// On Android and iOS it opens the phone's calendar app with the event
/// already filled in (add_2_calendar: no calendar permission on Android; on
/// iOS the system asks to use the calendar); on web it downloads an `.ics`
/// file that any calendar opens. It holds no domain logic and logs nothing:
/// the event's words never leave the phone through it.
/// {@endtemplate}
class CalendarClient {
  /// {@macro calendar_client}
  new({
    Future<bool> Function(Event event)? addEvent,
    Future<void> Function({
      required String fileName,
      required String contents,
      required String mimeType,
    })?
    download,
    DateTime Function()? now,
    String Function()? newUid,
    this._isWeb = kIsWeb,
  }) : _addEvent = addEvent ?? Add2Calendar.addEvent2Cal,
       _download = download ?? downloadTextFile,
       _now = now ?? DateTime.now,
       _newUid = newUid ?? _randomUid;

  final Future<bool> Function(Event event) _addEvent;
  final Future<void> Function({
    required String fileName,
    required String contents,
    required String mimeType,
  })
  _download;
  final DateTime Function() _now;
  final String Function() _newUid;
  final bool _isWeb;

  /// How long before a plan the phone's calendar alerts, where it can ask
  /// for an alert (iOS).
  static const reminder = Duration(hours: 1);

  /// The `.ics` file's name.
  static const fileName = 'ronda-algo-chico.ics';

  /// The `.ics` file's type.
  static const mimeType = 'text/calendar';

  static String _randomUid() {
    final random = Random.secure();
    final id = [
      for (var i = 0; i < 12; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    return '$id@ronda.uy';
  }

  /// Adds [event]: opens the calendar with it on a phone, downloads it as an
  /// `.ics` file in a browser.
  ///
  /// Throws a [CalendarUnavailableException] when neither could be done.
  Future<CalendarOutcome> add(CalendarEvent event) async {
    try {
      if (_isWeb) {
        await _download(
          fileName: fileName,
          contents: buildIcs(event, stamp: _now(), uid: _newUid()),
          mimeType: mimeType,
        );
        return CalendarOutcome.downloaded;
      }
      final opened = await _addEvent(
        Event(
          title: event.title,
          location: event.location,
          startDate: event.start,
          endDate: event.end,
          iosParams: const IOSParams(reminder: reminder),
        ),
      );
      if (!opened) throw const CalendarUnavailableException();
      return CalendarOutcome.opened;
    } on CalendarUnavailableException {
      rethrow;
    } on Object {
      throw const CalendarUnavailableException();
    }
  }
}
