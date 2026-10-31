import 'package:calendar_client/src/calendar_event.dart';

/// The `.ics` file (RFC 5545) for [event], one `VEVENT` with a floating start
/// and end (no time zone, so any calendar shows them as the wall-clock times
/// they were written with), stamped [stamp] and identified by [uid].
///
/// Lines end in CRLF and are folded at 75 characters; `\`, `;`, `,` and new
/// lines in the text are escaped.
String buildIcs(
  CalendarEvent event, {
  required DateTime stamp,
  required String uid,
}) {
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Ronda//Algo chico//ES',
    'CALSCALE:GREGORIAN',
    'BEGIN:VEVENT',
    'UID:$uid',
    'DTSTAMP:${_utc(stamp)}',
    'DTSTART:${_floating(event.start)}',
    'DTEND:${_floating(event.end)}',
    'SUMMARY:${_escape(event.title)}',
    if (event.location case final location? when location.isNotEmpty)
      'LOCATION:${_escape(location)}',
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  return '${lines.map(_fold).join('\r\n')}\r\n';
}

String _two(int value) => value.toString().padLeft(2, '0');

String _floating(DateTime time) =>
    '${time.year.toString().padLeft(4, '0')}${_two(time.month)}'
    '${_two(time.day)}T${_two(time.hour)}${_two(time.minute)}'
    '${_two(time.second)}';

String _utc(DateTime time) => '${_floating(time.toUtc())}Z';

String _escape(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\r\n', r'\n')
    .replaceAll('\n', r'\n');

const _foldAt = 75;

/// Folds a line longer than [_foldAt] characters: each continuation starts
/// with one space.
String _fold(String line) {
  if (line.length <= _foldAt) return line;
  final parts = [line.substring(0, _foldAt)];
  var start = _foldAt;
  while (start < line.length) {
    final end = start + _foldAt - 1 < line.length
        ? start + _foldAt - 1
        : line.length;
    parts.add(' ${line.substring(start, end)}');
    start = end;
  }
  return parts.join('\r\n');
}
